function archive = downloadPlanetEphemerides(startDate, endDate, varargin)
%DOWNLOADPLANETEPHEMERIDES Archive Planet orbital products by flock and HWID.
% A = downloadPlanetEphemerides("2026-09-01","2026-09-03", ...
%     "Flock","4q","ID",["24bd","24d1"])
%
% Dates are inclusive UTC ARCHIVE dates (YYYY-MM-DD or midnight datetimes),
% not orbital-epoch bounds. The original orbital epochs remain in every row.
% Flock and ID are AND filters; multiple values within one filter are ORed.
%
% Name-value options:
%   Flock             "all" (default), "4q", or ["4q","4be"].
%   ID                HWID string(s); default [] selects all IDs.
%   IDType            "hwid" (default) or "catid". CATIDs use the same-day
%                     TLE first, then a flagged catalog-snapshot fallback.
%   OutputDirectory   default: <repository>/data/planet_ephemerides.
%   MetadataDirectory optional frozen index.html + 18SPCS_matches_v1.txt.
%   UseCache          true; verify existing receipts instead of re-downloading.
%   CacheOnly         false; true prohibits all HTTP requests.
%   Strict            false; true throws AFTER saving if any source failed.
%   Timeout           30 seconds per connection/response/data interval.
%   MaxAttempts       3; retry transient HTTP failures and network errors.
%   RetryPause        1 second, exponential backoff (bounded; Retry-After aware).
%   RequestPause      0.1 seconds between noncached daily requests.
%   Verbose           true.
%
% Outputs: TLE, States, Catalog, Groups, Availability, Manifest, Config,
% Summary, RunDirectory. Each run saves archive.mat, CSV tables, a JSON
% configuration, source metadata, and per-flock/per-HWID TLE/state subsets.
% Raw daily products are downloaded ONCE per day, not once per satellite.
%
% Requires MATLAB R2022b or newer with the JVM. No Aerospace Toolbox needed.
% This is ingestion only: it does not propagate, fit, or transform a state.
% Code: MIT. Planet data: CC BY-NC 4.0; see data/LICENSE-Planet.txt.
% SPDX-License-Identifier: MIT
    if verLessThan('matlab','9.13')
        error('planetephem:MATLABVersion','This utility requires MATLAB R2022b or newer.');
    end
    if ~usejava('jvm')
        error('planetephem:JVMRequired','Run MATLAB with its JVM enabled.');
    end
    repository = fileparts(fileparts(mfilename('fullpath')));
    parser = inputParser;
    parser.FunctionName = mfilename;
    addParameter(parser,'Flock',"all");
    addParameter(parser,'ID',strings(0,1));
    addParameter(parser,'IDType',"hwid");
    addParameter(parser,'OutputDirectory',fullfile(repository,'data','planet_ephemerides'));
    addParameter(parser,'MetadataDirectory',"");
    addParameter(parser,'UseCache',true,@logicalScalar);
    addParameter(parser,'CacheOnly',false,@logicalScalar);
    addParameter(parser,'Strict',false,@logicalScalar);
    addParameter(parser,'Timeout',30,@positiveScalar);
    addParameter(parser,'MaxAttempts',3,@(x) positiveScalar(x) && fix(x)==x);
    addParameter(parser,'RetryPause',1,@nonnegativeScalar);
    addParameter(parser,'RequestPause',0.1,@nonnegativeScalar);
    addParameter(parser,'Verbose',true,@logicalScalar);
    parse(parser,varargin{:});
    cfg = parser.Results;
    firstDay = archiveDay(startDate);
    lastDay = archiveDay(endDate);
    if lastDay < firstDay
        error('planetephem:DateOrder','endDate must be on or after startDate.');
    end
    if lastDay > dateshift(datetime('now','TimeZone','UTC'),'start','day')
        error('planetephem:FutureArchive','Future archive dates are unavailable.');
    end
    cfg.Flock = string(cfg.Flock);
    cfg.Flock = lower(strip(cfg.Flock(:)));
    cfg.Flock = regexprep(cfg.Flock,'^flock\s+','');
    if isempty(cfg.Flock) || any(ismissing(cfg.Flock) | strlength(cfg.Flock)==0)
        error('planetephem:InvalidSelector','Flock cannot be empty.');
    end
    if any(cfg.Flock=="all") && numel(cfg.Flock)>1
        error('planetephem:InvalidSelector','Use all alone, or name individual flocks.');
    end
    for k = 1:numel(cfg.Flock)
        if isempty(regexp(char(cfg.Flock(k)), '^[a-z0-9'']+$','once'))
            error('planetephem:InvalidSelector','Invalid flock %s.', cfg.Flock(k));
        end
    end
    cfg.IDType = string(validatestring(cfg.IDType,{'hwid','catid'}));
    cfg.ID = string(cfg.ID);
    cfg.ID = lower(strip(cfg.ID(:)));
    if cfg.IDType=="hwid"
        pattern = '^(?:[0-9a-f]{4}|s[0-9]+)$';
    else
        pattern = '^(?:[a-hj-np-z][0-9]{4}|[0-9]{1,9})$';
        cfg.ID = upper(regexprep(cfg.ID,'^0+(?=\d)',''));
    end
    for k = 1:numel(cfg.ID)
        if ismissing(cfg.ID(k)) || isempty(regexpi(char(cfg.ID(k)),pattern,'once'))
            error('planetephem:InvalidSelector','Invalid %s ID %s.',cfg.IDType,cfg.ID(k));
        end
    end
    cfg.OutputDirectory = absoluteDirectory(cfg.OutputDirectory);
    cfg.MetadataDirectory = string(cfg.MetadataDirectory);
    if ~isscalar(cfg.MetadataDirectory) || ismissing(cfg.MetadataDirectory)
        error('planetephem:InvalidPath','MetadataDirectory must be one path.');
    end
    if strlength(cfg.MetadataDirectory)>0 && ~isfolder(cfg.MetadataDirectory)
        error('planetephem:InvalidPath','MetadataDirectory does not exist.');
    end
    cfg.StartDate = dayString(firstDay);
    cfg.EndDate = dayString(lastDay);
    cfg.BaseURL = "https://ephemerides.planet-labs.com/";
    cfg.Version = "1.0.0";
    cfg.CreatedUTC = planetephem.utcNow();
    cfg.MATLABVersion = string(version);
    stamp = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    tag = stamp + "_" + extractBefore(string(java.util.UUID.randomUUID()),9);
    runDirectory = fullfile(cfg.OutputDirectory,'runs',tag);
    mkdir(runDirectory);
    metadata = metadataDirectory(cfg,stamp);
    cfg.ResolvedMetadataDirectory = string(metadata);
    receipts = struct([]);
    catalog = table;
    progressClock = tic;
    if cfg.Verbose
        fprintf('Planet ephemerides: preparing source metadata...\n');
    end
    for name = ["index.html","18SPCS_matches_v1.txt"]
        url = cfg.BaseURL + name;
        if name=="index.html"
            url = cfg.BaseURL;
        end
        local = fullfile(metadata,name);
        fetchOptions = cfg;
        % Explicit/frozen metadata is reused; new snapshots fetch once.
        fetchOptions.UseCache = true;
        if name=="18SPCS_matches_v1.txt"
            fetchOptions.Validator = @planetephem.readCatalog;
        end
        [bytes, receipt] = planetephem.fetch(url,local,fetchOptions);
        receipt.Product = "metadata";
        receipt.ArchiveDate = "";
        if successful(receipt)
            if name=="18SPCS_matches_v1.txt"
                try
                    catalog = planetephem.readCatalog(decode(bytes));
                catch err
                    receipt.Status = "invalid-content";
                    receipt.Message = string(err.message);
                end
            end
            planetephem.writeBytes(fullfile(runDirectory,'sources',name),bytes);
        end
        receipts = appendReceipt(receipts,receipt,cfg.OutputDirectory);
    end
    if isempty(catalog)
        % Typed empty catalog, allowing name-based historical TLE discovery.
        catalog = table('Size',[0 4],'VariableTypes',repmat({'string'},1,4), ...
            'VariableNames',{'HWID','Flock','PlanetName','CatalogID'});
    end
    allTLE = addProvenance(resolveTLE(planetephem.readTLE(""),catalog),"",struct);
    allStates = addProvenance(resolveStates(planetephem.readStates(""),allTLE,catalog), ...
        "",struct);
    archiveDates = firstDay:caldays(1):lastDay;
    for n = 1:numel(archiveDates)
        dayText = dayString(archiveDates(n));
        compact = erase(dayText,'-');
        names = ["planet_mc_"+compact+".tle", "planet_"+compact+".states"];
        daily = cell(1,2);
        dailyReceipts = cell(1,2);
        for p = 1:2
            local = fullfile(cfg.OutputDirectory,'raw','daily', ...
                extractBetween(compact,1,4),extractBetween(compact,5,6),names(p));
            fetchOptions = cfg;
            if p==1
                fetchOptions.Validator = @planetephem.readTLE;
            else
                fetchOptions.Validator = @planetephem.readStates;
            end
            [bytes, receipt] = planetephem.fetch(cfg.BaseURL+names(p),local,fetchOptions);
            if cfg.Verbose
                fprintf('  %s: %s\n',names(p),receipt.Status);
            end
            receipt.Product = ["tle","states"];
            receipt.Product = receipt.Product(p);
            receipt.ArchiveDate = dayText;
            if successful(receipt)
                try
                    if p==1
                        daily{p} = planetephem.readTLE(decode(bytes));
                    else
                        daily{p} = planetephem.readStates(decode(bytes));
                    end
                    if isempty(daily{p})
                        error('planetephem:EmptyProduct','No orbital records in %s.',names(p));
                    end
                catch err
                    receipt.Status = "invalid-content";
                    receipt.Message = string(err.message);
                    daily{p} = [];
                end
            end
            receipts = appendReceipt(receipts,receipt,cfg.OutputDirectory);
            dailyReceipts{p} = receipts(end);
            if ~receipt.FromCache && ~cfg.CacheOnly
                pause(cfg.RequestPause);
            end
        end
        t = resolveTLE(planetephem.readTLE(""),catalog);
        if ~isempty(daily{1})
            t = resolveTLE(daily{1},catalog);
            allTLE = [allTLE; addProvenance(t,dayText,dailyReceipts{1})];
        end
        if ~isempty(daily{2})
            s = resolveStates(daily{2},t,catalog);
            allStates = [allStates; addProvenance(s,dayText,dailyReceipts{2})];
        end
        if cfg.Verbose
            filled = floor(30*n/numel(archiveDates));
            fprintf('[%s%s] %5.1f%% (%d/%d days), elapsed %.0f s\n', ...
                repmat('=',1,filled),repmat(' ',1,30-filled), ...
                100*n/numel(archiveDates),n,numel(archiveDates),toc(progressClock));
        end
    end
    if cfg.Verbose
        fprintf('Filtering records and saving run outputs...\n');
    end
    tle = allTLE(selectRows(allTLE,cfg),:);
    states = allStates(selectRows(allStates,cfg),:);
    selectedCatalog = catalog(selectRows(catalog,cfg),:);
    ids = unique([tle.HWID;states.HWID;selectedCatalog.HWID]);
    if cfg.IDType=="hwid" && any(cfg.Flock=="all")
        ids = unique([ids;cfg.ID]);
    end
    ids(ids=="") = [];
    availability = makeAvailability(tle,states,selectedCatalog,ids,archiveDates);
    groups = writeGroups(runDirectory,tle,states,selectedCatalog,ids);
    manifest = struct2table(receipts);
    good = ismember(manifest.Status,["downloaded","cached"]);
    if cfg.IDType=="hwid"
        matchedIDs = unique([tle.HWID;states.HWID]);
    else
        matchedIDs = unique([tle.CatalogID;states.CatalogID]);
    end
    unmatchedIDs = setdiff(cfg.ID,matchedIDs);
    unmatchedFlocks = strings(0,1);
    if ~any(cfg.Flock=="all")
        unmatchedFlocks = setdiff(cfg.Flock,unique([tle.Flock;states.Flock]));
    end
    summary = struct('ArchiveDays',numel(archiveDates),'SatelliteGroups',numel(ids), ...
        'TLERows',height(tle),'StateRows',height(states),'FailedSources',sum(~good), ...
        'UnmatchedIDs',unmatchedIDs,'UnmatchedFlocks',unmatchedFlocks, ...
        'PairedSatelliteDays',sum(availability.HasBoth), ...
        'SatelliteDaysWithoutBoth',sum(~availability.HasBoth), ...
        'UnresolvedTLERows',sum(tle.HWID==""), ...
        'Complete',all(good) && ~isempty(tle) && ~isempty(states) && ...
            isempty(unmatchedIDs) && isempty(unmatchedFlocks));
    archive = struct('TLE',tle,'States',states,'Catalog',catalog,'Groups',groups, ...
        'Availability',availability,'Manifest',manifest,'Config',cfg, ...
        'Summary',summary,'RunDirectory',string(runDirectory));
    writetable(tle,fullfile(runDirectory,'tle.csv'));
    writetable(states,fullfile(runDirectory,'states.csv'));
    writetable(catalog,fullfile(runDirectory,'catalog.csv'));
    writetable(groups,fullfile(runDirectory,'groups.csv'));
    writetable(availability,fullfile(runDirectory,'availability.csv'));
    writetable(manifest,fullfile(runDirectory,'manifest.csv'));
    planetephem.writeBytes(fullfile(runDirectory,'config.json'), ...
        unicode2native(jsonencode(cfg),'UTF-8'));
    save(fullfile(runDirectory,'archive.mat'),'archive','-v7');
    if cfg.Verbose
        fprintf('Saved run: %s\n',runDirectory);
    end
    if ~summary.Complete
        message = sprintf(['Saved %d TLE and %d state rows; %d failed sources. ' ...
            'Inspect Manifest, Summary (including unmatched filters), and Availability in %s.'], ...
            height(tle),height(states),sum(~good),runDirectory);
        if cfg.Strict
            error('planetephem:IncompleteArchive','%s',message);
        else
            warning('planetephem:IncompleteArchive','%s',message);
        end
    end
end

function dayValue = archiveDay(value)
    if isdatetime(value)
        if ~isscalar(value) || isnat(value)
            error('planetephem:InvalidDate','Dates must be non-NaT scalars.');
        end
        if isempty(value.TimeZone)
            value.TimeZone = 'UTC';
        elseif strcmp(value.TimeZone,'UTCLeapSeconds')
            value = datetime(year(value),month(value),day(value), ...
                hour(value),minute(value),second(value),'TimeZone','UTC');
        else
            value.TimeZone = 'UTC';
        end
        dayValue = dateshift(value,'start','day');
        if value ~= dayValue
            error('planetephem:InvalidDate','Use midnight UTC dates, not time windows.');
        end
    else
        text = string(value);
        if ~isscalar(text) || ismissing(text) || ...
                isempty(regexp(char(text),'^\d{4}-\d{2}-\d{2}$','once'))
            error('planetephem:InvalidDate','Use an ISO date such as 2026-09-01.');
        end
        try
            dayValue = datetime(text,'InputFormat','yyyy-MM-dd','TimeZone','UTC');
            if dayString(dayValue)~=text
                error('planetephem:InvalidDate','Invalid calendar date.');
            end
        catch
            error('planetephem:InvalidDate','Invalid calendar date %s.',text);
        end
    end
end

function value = dayString(date)
    date.Format = 'yyyy-MM-dd';
    value = string(date);
end

function value = absoluteDirectory(value)
    value = string(value);
    if ~isscalar(value) || ismissing(value) || strlength(value)==0
        error('planetephem:InvalidPath','OutputDirectory must be one nonempty path.');
    end
    javaFile = java.io.File(char(value));
    value = string(javaFile.getCanonicalPath());
    if ~isfolder(value)
        mkdir(value);
    end
end

function directory = metadataDirectory(cfg,stamp)
    directory = cfg.MetadataDirectory;
    if strlength(directory)>0
        javaFile = java.io.File(char(directory));
        directory = string(javaFile.getCanonicalPath());
        return
    end
    root = fullfile(cfg.OutputDirectory,'raw','metadata');
    if cfg.CacheOnly && isfolder(root)
        entries = dir(root);
        entries = entries([entries.isdir] & ~startsWith(string({entries.name}),'.'));
        if ~isempty(entries)
            [~,order] = sort(string({entries.name}),'descend');
            directory = fullfile(root,entries(order(1)).name);
            return
        end
    end
    directory = fullfile(root,stamp);
end

function value = decode(bytes)
    value = string(native2unicode(bytes(:).','UTF-8'));
    value = erase(value,char(65279));
end

function good = successful(receipt)
    good = ismember(receipt.Status,["downloaded","cached"]);
end

function receipts = appendReceipt(receipts,receipt,root)
    receipt.LocalFile = relativePath(receipt.LocalFile,root);
    if isempty(receipts)
        receipts = receipt;
    else
        receipts(end+1) = receipt;
    end
end

function relative = relativePath(path,root)
    path = replace(string(path),'\','/');
    root = replace(string(root),'\','/') + "/";
    relative = path;
    if startsWith(path,root)
        relative = extractAfter(path,strlength(root));
    end
end

function t = addProvenance(t,date,receipt)
    n = height(t);
    t.ArchiveDate = repmat(string(date),n,1);
    t.SourceURL = strings(n,1);
    t.SourceFile = strings(n,1);
    t.SourceSHA256 = strings(n,1);
    if n>0
        t.SourceURL(:) = receipt.URL;
        t.SourceFile(:) = receipt.LocalFile;
        t.SourceSHA256(:) = receipt.SHA256;
    end
end

function t = resolveTLE(t,catalog)
    t.FlockSource = repmat("tle-name",height(t),1);
    t.CatalogSnapshotConflict = false(height(t),1);
    for k = 1:height(t)
        if t.HWID(k)==""
            match = find(catalog.CatalogID==t.CatalogID(k));
            if numel(match)==1
                t.HWID(k) = catalog.HWID(match);
                t.IdentitySource(k) = "catalog-snapshot";
            end
        end
        match = find(catalog.HWID==t.HWID(k));
        if numel(match)==1
            if t.Flock(k)=="unassigned"
                t.Flock(k) = catalog.Flock(match);
                t.FlockSource(k) = "catalog-snapshot";
            end
            t.CatalogSnapshotConflict(k) = catalog.CatalogID(match)~="-" && ...
                catalog.CatalogID(match)~=t.CatalogID(k);
        end
    end
end

function s = resolveStates(s,t,catalog)
    s.CatalogID = strings(height(s),1);
    s.CatalogIDSource = repmat("unresolved",height(s),1);
    for k = 1:height(s)
        sameDay = find(t.HWID==s.HWID(k));
        if ~isempty(sameDay)
            flocks = unique(t.Flock(sameDay));
            catids = unique(t.CatalogID(sameDay));
            if numel(flocks)==1 && flocks~="unassigned"
                s.Flock(k) = flocks;
                s.FlockSource(k) = "tle-archive";
            end
            if numel(catids)==1
                s.CatalogID(k) = catids;
                s.CatalogIDSource(k) = "tle-archive";
            end
        end
        match = find(catalog.HWID==s.HWID(k));
        if numel(match)==1
            if s.Flock(k)=="unassigned"
                s.Flock(k) = catalog.Flock(match);
                s.FlockSource(k) = "catalog-snapshot";
            end
            if s.CatalogID(k)=="" && catalog.CatalogID(match)~="-"
                s.CatalogID(k) = catalog.CatalogID(match);
                s.CatalogIDSource(k) = "catalog-snapshot";
            end
        end
    end
end

function keep = selectRows(t,cfg)
    keep = true(height(t),1);
    if ~any(cfg.Flock=="all")
        keep = keep & ismember(t.Flock,cfg.Flock);
    end
    if ~isempty(cfg.ID)
        if cfg.IDType=="hwid"
            keep = keep & ismember(t.HWID,cfg.ID);
        else
            keep = keep & ismember(t.CatalogID,cfg.ID);
        end
    end
end

function availability = makeAvailability(t,s,catalog,ids,dates)
    names = {'Flock','HWID','ArchiveDate','TLECount','StateCount','HasBoth', ...
        'NativeEpochSeparation_s','TLERow','StateRow','Status'};
    types = {'string','string','string','double','double','logical', ...
        'double','double','double','string'};
    availability = table('Size',[numel(ids)*numel(dates),numel(names)], ...
        'VariableTypes',types,'VariableNames',names);
    row = 0;
    for id = ids.'
        flock = groupFlock(t,s,catalog,id);
        for date = dates
            row = row + 1;
            label = dayString(date);
            ti = find(t.HWID==id & t.ArchiveDate==label);
            si = find(s.HWID==id & s.ArchiveDate==label);
            separation = NaN;
            tr = NaN;
            sr = NaN;
            if numel(ti)==1
                tr = ti;
            end
            if numel(si)==1
                sr = si;
            end
            if numel(ti)==1 && numel(si)==1
                separation = seconds(t.EpochUTC(ti)-s.EpochUTC(si));
            end
            status = "no-records";
            if ~isempty(ti) && ~isempty(si)
                status = "both";
            elseif ~isempty(ti)
                status = "tle-only";
            elseif ~isempty(si)
                status = "states-only";
            end
            availability(row,:) = {flock,id,label,numel(ti),numel(si), ...
                ~isempty(ti) && ~isempty(si),separation,tr,sr,status};
        end
    end
end

function flock = groupFlock(t,s,catalog,id)
    options = unique([t.Flock(t.HWID==id);s.Flock(s.HWID==id)]);
    options(options=="unassigned") = [];
    if isempty(options)
        options = unique(catalog.Flock(catalog.HWID==id));
    end
    flock = "unassigned";
    if numel(options)==1
        flock = options;
    elseif numel(options)>1
        flock = "mixed";
    end
end

function groups = writeGroups(root,t,s,catalog,ids)
    groups = table('Size',[0 5],'VariableTypes', ...
        {'string','string','double','double','string'},'VariableNames', ...
        {'Flock','HWID','TLECount','StateCount','Directory'});
    for id = ids.'
        a = t(t.HWID==id,:);
        b = s(s.HWID==id,:);
        flock = groupFlock(t,s,catalog,id);
        relative = "";
        if ~isempty(a) || ~isempty(b)
            relative = "by_flock/"+flock+"/"+id;
            folder = fullfile(root,relative);
            mkdir(folder);
            writetable(a,fullfile(folder,'tle.csv'));
            writetable(b,fullfile(folder,'states.csv'));
            lines = strings(height(a)*3,1);
            for k = 1:height(a)
                name = a.Name(k);
                if name==""
                    name = id;
                end
                lines(3*k-2:3*k) = ["0 "+name;a.Line1(k);a.Line2(k)];
            end
            writeLines(fullfile(folder,'records.tle'),lines);
            writeLines(fullfile(folder,'records.states'),b.RawLine);
        end
        groups(end+1,:) = {flock,id,height(a),height(b),relative};
    end
end

function writeLines(path,lines)
    text = "";
    if ~isempty(lines)
        text = join(lines,newline) + newline;
    end
    planetephem.writeBytes(path,unicode2native(char(text),'UTF-8'));
end

function valid = logicalScalar(value)
    valid = islogical(value) && isscalar(value);
end

function valid = positiveScalar(value)
    valid = isnumeric(value) && isscalar(value) && isfinite(value) && value>0;
end

function valid = nonnegativeScalar(value)
    valid = isnumeric(value) && isscalar(value) && isfinite(value) && value>=0;
end
