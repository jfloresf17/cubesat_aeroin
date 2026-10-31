function result=quicklook_inspector(opts)
%QUICKLOOK_INSPECTOR Search real PlanetScope scenes near native states.
%   result=quicklook_inspector() searches UTC year 2026 with a 60 s
%   scene-to-state tolerance and a same-UTC-day native TLE epoch filter.
%   opts=quicklook_config() returns editable defaults.
%
% All matching combinations are retained. This exploratory screening does
% not calculate orbital residuals, geolocation error or historical identity.
% Set PLANET_API_KEY in the process environment or in the project .env file;
% no key is stored in options, output files, logs or results.
if nargin<1||isempty(opts),opts=quicklook_config();end
projectRoot=startup_consistency();
opts=validateOptions(opts);
apiKey=poc.quicklook.loadPlanetKey(projectRoot);
assert(isscalar(apiKey)&&strlength(strtrim(apiKey))>0, ...
 'poc:quicklook:MissingKey', ...
 'Set PLANET_API_KEY in the MATLAB environment or project .env; see docs/QUICKLOOK.md.');
cfg=study_config("audit");
fprintf('Loading cached native states and TLEs; source archives are not modified.\n');
[states,tles,roster,inventory]=poc.quicklook.loadSources(cfg,opts);
windows=poc.quicklook.searchWindows(states,opts);
ids=unique(lower(states.HWID(states.Status=="OK" & ~isnat(states.EpochUTC))));
start=dateshift(opts.StartUTC,'start','day');
finish=dateshift(opts.EndUTC,'start','day')+caldays(1);
fprintf('Usable state search windows: %d; native satellite IDs: %d.\n', ...
 size(windows,1),numel(ids));
if isempty(windows)||isempty(ids)
 scenes=poc.quicklook.normalizeScenes([]);
 stats=struct('Pages',0,'Features',0,'Searches',0,'DuplicatesRemoved',0, ...
  'StartUTC',start,'EndUTC',finish);
 fprintf('No usable state windows; Planet catalogue search was not performed.\n');
else
 searchOpts=struct('PageSize',opts.PageSize,'Timeout_s',opts.TimeoutSeconds, ...
  'WindowsUTC',windows,'WindowsPerRequest',opts.WindowsPerRequest, ...
  'Pause_s',opts.PauseSeconds);
 searchOpts.WindowSatelliteIDs=poc.quicklook.searchWindowIDs(windows,states,opts);
 fprintf('Searching Planet PSScene metadata for the configured year and state windows.\n');
 [scenes,stats]=poc.quicklook.searchScenes(apiKey,ids,start,finish,searchOpts);
end
[matches,sceneStatus]=poc.quicklook.matchScenes(scenes,states,tles,roster,opts);
if ~isfolder(opts.ResultsPath)
 [ok,msg]=mkdir(opts.ResultsPath);assert(ok,'poc:quicklook:Output','%s',msg);
end
stamp=string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
runDir=fullfile(string(opts.ResultsPath),"quicklook_"+stamp);
suffix=0;candidate=runDir;
while isfolder(candidate)||isfile(candidate)
 suffix=suffix+1;candidate=runDir+"_"+suffix;
end
runDir=candidate;
[ok,msg]=mkdir(runDir);assert(ok,'poc:quicklook:Output','%s',msg);
matchedIDs=unique(matches.SceneID);
previewScenes=scenes(ismember(scenes.SceneID,matchedIDs),:);
previewScenes.ThumbnailLocalPath=strings(height(previewScenes),1);
if opts.DownloadThumbnails && ~isempty(previewScenes)
 previewScenes.ThumbnailStatus=repmat("PENDING",height(previewScenes),1);
else
 previewScenes.ThumbnailStatus=repmat("NOT_REQUESTED",height(previewScenes),1);
end
% Persist the completed search and match before making any preview requests.
% A long download or a failure cannot discard the catalogue and matches.
result=struct('RunDir',runDir,'Options',opts,'SearchStats',stats, ...
 'Matches',matches,'Scenes',scenes,'SceneStatus',sceneStatus, ...
 'Previews',previewScenes,'ArchiveInventory',inventory);
poc.quicklook.writeResults(result,windows,true);
fprintf('Search and match results saved: %s\n',runDir);
if opts.DownloadThumbnails && ~isempty(previewScenes)
 fprintf('Downloading previews for %d matched scenes.\n',height(previewScenes));
 previewOpts=struct('Timeout_s',opts.TimeoutSeconds,'Pause_s',opts.PauseSeconds);
 previewScenes=poc.quicklook.downloadThumbnails(previewScenes,apiKey,runDir,previewOpts);
 result.Previews=previewScenes;
 poc.quicklook.writeResults(result,windows,false);
end
clear apiKey
fprintf('Quick-look output: %s\n',runDir);
fprintf('Matching combinations: %d; matched scenes: %d\n',height(matches),numel(matchedIDs));
fprintf('Open: %s\n',fullfile(runDir,'index.html'));
end

function opts=validateOptions(opts)
assert(isstruct(opts)&&isscalar(opts),'poc:quicklook:Options', ...
 'Use an options structure returned by quicklook_config().');
required={'StartUTC','EndUTC','TimeToleranceSeconds','RawPath','RosterPath', ...
 'ResultsPath','DownloadThumbnails','TimeoutSeconds','PageSize', ...
 'WindowsPerRequest','PauseSeconds'};
for k=1:numel(required)
 assert(isfield(opts,required{k}),'poc:quicklook:Options', ...
  'Missing option: %s.',required{k});
end
% Reject arbitrary fields so that secrets cannot accidentally enter saved options.
assert(isempty(setdiff(fieldnames(opts),required)),'poc:quicklook:Options', ...
 'Unexpected option field; start from quicklook_config(). Never put the key in opts.');
for f={'StartUTC','EndUTC'}
 value=opts.(f{1});
 assert(isdatetime(value)&&isscalar(value)&&~isnat(value)&&~isempty(value.TimeZone), ...
  'poc:quicklook:Dates','StartUTC and EndUTC must be timezone-aware scalar datetime values.');
 value.TimeZone='UTC';opts.(f{1})=dateshift(value,'start','day');
end
assert(opts.EndUTC>=opts.StartUTC,'poc:quicklook:Dates','EndUTC must not precede StartUTC.');
assert(isnumeric(opts.TimeToleranceSeconds)&&isscalar(opts.TimeToleranceSeconds) ...
 &&isfinite(opts.TimeToleranceSeconds)&&opts.TimeToleranceSeconds>=0, ...
 'poc:quicklook:Tolerance','TimeToleranceSeconds must be finite and nonnegative.');
for f={'RawPath','RosterPath','ResultsPath'}
 v=string(opts.(f{1}));
 assert(isscalar(v)&&~ismissing(v)&&strlength(v)>0, ...
  'poc:quicklook:Options','%s must be a nonempty scalar path.',f{1});
 opts.(f{1})=v;
end
assert(isscalar(opts.DownloadThumbnails)&&islogical(opts.DownloadThumbnails), ...
 'poc:quicklook:Options','DownloadThumbnails must be true or false.');
assert(isnumeric(opts.TimeoutSeconds)&&isscalar(opts.TimeoutSeconds)&& ...
 isfinite(opts.TimeoutSeconds)&&opts.TimeoutSeconds>0, ...
 'poc:quicklook:Options','TimeoutSeconds must be positive.');
assert(isnumeric(opts.PageSize)&&isscalar(opts.PageSize)&&isfinite(opts.PageSize) ...
 &&opts.PageSize>=1&&opts.PageSize<=250&&fix(opts.PageSize)==opts.PageSize, ...
 'poc:quicklook:Options','PageSize must be an integer from 1 to 250.');
assert(isnumeric(opts.WindowsPerRequest)&&isscalar(opts.WindowsPerRequest)&& ...
 isfinite(opts.WindowsPerRequest)&&opts.WindowsPerRequest>=1&& ...
 fix(opts.WindowsPerRequest)==opts.WindowsPerRequest, ...
 'poc:quicklook:Options','WindowsPerRequest must be a positive integer.');
assert(isnumeric(opts.PauseSeconds)&&isscalar(opts.PauseSeconds)&& ...
 isfinite(opts.PauseSeconds)&&opts.PauseSeconds>=0, ...
 'poc:quicklook:Options','PauseSeconds must be finite and nonnegative.');
end
