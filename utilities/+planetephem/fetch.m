function [bytes, receipt] = fetch(url, path, options)
%FETCH Retrieve a public file, or reuse a hash-verified local cache entry.
% Failures are returned in receipt.Status; unsuccessful bodies never enter
% the cache. Transport is an internal injection point for deterministic tests.
% SPDX-License-Identifier: MIT
    bytes = uint8([]);
    receipt = struct('URL',string(url),'LocalFile',string(path), ...
        'Status',"pending",'HTTPStatus',NaN,'FromCache',false, ...
        'RetrievedUTC',"",'UsedUTC',planetephem.utcNow(),'Bytes',0, ...
        'SHA256',"",'Attempts',0,'Message',"");
    sidecar = string(path) + ".receipt.json";
    if isfile(path) && (options.UseCache || options.CacheOnly)
        bytes = planetephem.readBytes(path);
        receipt.SHA256 = planetephem.sha256(bytes);
        receipt.Bytes = numel(bytes);
        receipt.FromCache = true;
        receipt.Status = "cached";
        if isfile(sidecar)
            try
                previous = jsondecode(fileread(sidecar));
                if string(previous.SHA256) ~= receipt.SHA256 || ...
                        string(previous.URL) ~= string(url)
                    error('planetephem:CacheIntegrity','Cache hash or URL differs.');
                end
                receipt.RetrievedUTC = string(previous.RetrievedUTC);
                receipt.HTTPStatus = previous.HTTPStatus;
            catch err
                receipt.Status = "cache-invalid";
                receipt.Message = string(err.message);
                bytes = uint8([]);
            end
        else
            receipt.Message = "No receipt: origin time unknown; SHA256 computed now.";
        end
        return
    end
    if options.CacheOnly
        receipt.Status = "cache-miss";
        receipt.Message = "CacheOnly=true; no HTTP request was made.";
        return
    end
    for attempt = 1:options.MaxAttempts
        receipt.Attempts = attempt;
        retryAfter = "";
        try
            if isfield(options,'Transport') && ~isempty(options.Transport)
                [status, payload, retryAfter] = options.Transport(url, options.Timeout);
            else
                [status, payload, retryAfter] = request(url, options.Timeout);
            end
            receipt.HTTPStatus = status;
            if status == 200
                if isempty(payload)
                    receipt.Status = "empty-response";
                    receipt.Message = "HTTP 200 had an empty body.";
                    return
                end
                bytes = uint8(payload(:));
                if isfield(options,'Validator') && ~isempty(options.Validator)
                    try
                        options.Validator(string(native2unicode(bytes(:).','UTF-8')));
                    catch err
                        receipt.Status = "invalid-content";
                        receipt.Message = string(err.message);
                        bytes = uint8([]);
                        return
                    end
                end
                receipt.Bytes = numel(bytes);
                receipt.SHA256 = planetephem.sha256(bytes);
                receipt.RetrievedUTC = planetephem.utcNow();
                receipt.Status = "downloaded";
                % A forced refresh preserves the preceding bytes and receipt.
                if isfile(path)
                    old = planetephem.readBytes(path);
                    if planetephem.sha256(old) ~= receipt.SHA256
                        previousPath = fullfile(fileparts(path), '.versions', ...
                            char(planetephem.sha256(old)), fileName(path));
                        planetephem.writeBytes(previousPath, old);
                        if isfile(sidecar)
                            planetephem.writeBytes(string(previousPath)+".receipt.json", ...
                                planetephem.readBytes(sidecar));
                        end
                    end
                end
                planetephem.writeBytes(path, bytes);
                planetephem.writeBytes(sidecar, unicode2native(jsonencode(receipt), 'UTF-8'));
                return
            end
            receipt.Status = "http-error";
            receipt.Message = "HTTP " + string(status);
            if ismember(status,[404 410])
                receipt.Status = "missing";
                return
            end
            if ~ismember(status,[408 425 429 500 502 503 504])
                return
            end
        catch err
            % Local write failures must not be disguised as network retries.
            if startsWith(string(err.identifier),"planetephem:File")
                rethrow(err)
            end
            receipt.Status = "network-error";
            receipt.Message = string(err.message);
        end
        if attempt < options.MaxAttempts
            waitSeconds = min(30, options.RetryPause * 2^(attempt-1));
            requested = str2double(string(retryAfter));
            if ~isfinite(requested) && strlength(string(retryAfter)) > 0
                try
                    retryTime = datetime(retryAfter,'InputFormat', ...
                        'eee, dd MMM yyyy HH:mm:ss ''GMT''', ...
                        'Locale','en_US','TimeZone','UTC');
                    requested = seconds(retryTime-datetime('now','TimeZone','UTC'));
                catch
                    requested = NaN;
                end
            end
            if isfinite(requested) && requested > 60
                receipt.Status = "deferred";
                receipt.Message = "Server Retry-After exceeds 60 s; rerun later.";
                return
            elseif isfinite(requested)
                waitSeconds = max(waitSeconds, max(0, requested));
            end
            pause(waitSeconds);
        end
    end
end

function [status, bytes, retryAfter] = request(url, timeout)
    import matlab.net.http.*
    header = HeaderField('Accept-Encoding','identity');
    message = RequestMessage('GET',header);
    opts = HTTPOptions('ConnectTimeout',timeout,'ResponseTimeout',timeout, ...
        'DataTimeout',timeout,'SavePayload',true,'ConvertResponse',false, ...
        'Authenticate',false,'MaxRedirects',5);
    response = message.send(char(url), opts);
    status = double(response.StatusCode);
    bytes = response.Body.Payload;
    retryAfter = "";
    fields = response.getFields('Retry-After');
    if ~isempty(fields)
        retryAfter = string(fields(1).Value);
    end
end

function name = fileName(path)
    [~, base, ext] = fileparts(path);
    name = string(base) + string(ext);
end
