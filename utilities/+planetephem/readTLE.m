function records = readTLE(text)
%READTLE Parse 2/3-line TLE records without changing their original elements.
% Checks both 69-column checksums, catalog-number agreement, epoch and orbit
% fields. A 2-line TLE has no HWID until the caller resolves its identity.
% SPDX-License-Identifier: MIT
    names = {'HWID','Flock','Name','CatalogID','EpochUTC','EpochYYDDD', ...
        'BStar_raw','BStar','Inclination_deg','RAAN_deg','Eccentricity', ...
        'ArgumentPerigee_deg','MeanAnomaly_deg','MeanMotion_rev_day', ...
        'Line1','Line2','ChecksumValid','SourceLine','IdentitySource'};
    types = [repmat({'string'},1,4), {'datetime','string','string'}, ...
        repmat({'double'},1,7), {'string','string','logical','double','string'}];
    records = table('Size',[0 numel(names)],'VariableTypes',types, ...
        'VariableNames',names);
    records.EpochUTC.TimeZone = 'UTCLeapSeconds';
    records.EpochUTC.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSSSS''Z''';
    lines = splitlines(string(text));
    name = "";
    k = 1;
    while k <= numel(lines)
        line = char(lines(k));
        if isempty(strtrim(line)) || startsWith(strtrim(line), '#')
            k = k + 1;
            continue
        end
        if ~startsWith(line, '1 ')
            if startsWith(line, '2 ') || strlength(name) > 0 || ...
                    ~isempty(regexpi(line, '<(?:!doctype|html)', 'once'))
                error('planetephem:TLEFormat', 'Unexpected TLE line %d.', k);
            end
            name = string(regexprep(line, '^0\s+', ''));
            k = k + 1;
            continue
        end
        if k == numel(lines)
            error('planetephem:TLEFormat', 'Truncated TLE at line %d.', k);
        end
        line2 = char(lines(k+1));
        if ~startsWith(line2, '2 ') || numel(line) ~= 69 || numel(line2) ~= 69
            error('planetephem:TLEFormat', 'Invalid 69-column pair at line %d.', k);
        end
        if ~checksum(line) || ~checksum(line2)
            error('planetephem:TLEChecksum', 'Bad TLE checksum at line %d.', k);
        end
        catalogID = string(strtrim(line(3:7)));
        if catalogID ~= string(strtrim(line2(3:7)))
            error('planetephem:TLEFormat', 'TLE catalog mismatch at line %d.', k);
        end
        epochRaw = string(line(19:32));
        epoch = readEpoch(char(epochRaw));
        bstarRaw = string(line(54:61));
        bstar = readImpliedExponent(char(bstarRaw));
        values = [str2double(line2(9:16)), str2double(line2(18:25)), ...
            str2double(['0.' line2(27:33)]), str2double(line2(35:42)), ...
            str2double(line2(44:51)), str2double(line2(53:63))];
        if any(~isfinite(values)) || values(1) < 0 || values(1) > 180 || ...
                values(3) < 0 || values(3) >= 1 || values(6) <= 0
            error('planetephem:TLEFormat', 'Invalid orbit fields at line %d.', k);
        end
        hwid = "";
        identity = "unresolved";
        token = regexpi(char(name), '(?:^|\s)([0-9A-F]{4}|S[0-9]+)$', ...
            'tokens','once');
        if ~isempty(token)
            hwid = lower(string(token{1}));
            identity = "tle-name";
        end
        records(end+1,:) = [{hwid, planetephem.flockFromName(name), ...
            name, catalogID, epoch, epochRaw, bstarRaw, bstar}, ...
            num2cell(values), {string(line), string(line2), true, k, identity}];
        name = "";
        k = k + 2;
    end
    if strlength(name) > 0
        error('planetephem:TLEFormat', 'Name without a following TLE pair.');
    end
    if isempty(records) && strlength(strtrim(string(text)))>0
        error('planetephem:TLEFormat','Nonempty source has no TLE records.');
    end
end

function valid = checksum(line)
    digits = line(1:68) >= '0' & line(1:68) <= '9';
    total = sum(double(line(digits)) - double('0')) + sum(line(1:68) == '-');
    valid = line(69) >= '0' && line(69) <= '9' && ...
        mod(total,10) == str2double(line(69));
end

function epoch = readEpoch(raw)
    if isempty(regexp(raw, '^\d{5}\.\d{8}$', 'once'))
        error('planetephem:TLEEpoch', 'Invalid TLE epoch %s.', raw);
    end
    yy = str2double(raw(1:2));
    y = 1900 + yy;
    if yy < 57
        y = 2000 + yy;
    end
    dayOfYear = str2double(raw(3:end));
    lastDay = days(datetime(y+1,1,1) - datetime(y,1,1));
    if dayOfYear < 1 || dayOfYear >= lastDay+1
        error('planetephem:TLEEpoch', 'Out-of-range TLE day %s.', raw);
    end
    % TLE fractions use nominal 86400-second UTC calendar days. Construct the
    % clock fields first, then use the leap-aware zone for elapsed-time maths.
    calendarTime = datetime(y,1,1) + days(dayOfYear-1);
    epoch = datetime(year(calendarTime),month(calendarTime),day(calendarTime), ...
        hour(calendarTime),minute(calendarTime),second(calendarTime), ...
        'TimeZone','UTCLeapSeconds');
end

function value = readImpliedExponent(raw)
    if isempty(regexp(raw, '^[ +\-]\d{5}[+\-]\d$', 'once'))
        error('planetephem:TLEFormat', 'Invalid B* field %s.', raw);
    end
    signValue = 1;
    if raw(1) == '-'
        signValue = -1;
    end
    value = signValue * str2double(['0.' raw(2:6)]) * 10^str2double(raw(7:8));
end
