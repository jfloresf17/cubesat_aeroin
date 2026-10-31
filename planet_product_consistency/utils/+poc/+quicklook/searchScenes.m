function [scenes,stats] = searchScenes(apiKey,satelliteIDs,startUTC,endUTC,opts)
%SEARCHSCENES Search Planet PSScene metadata, following every result page.
% [scenes,stats]=poc.quicklook.searchScenes(key,ids,startUTC,endUTC,opts)
% searches [startUTC,endUTC), with RFC3339 UTC timestamps and the native
% Planet satellite_id values (including leading zeros). No scene asset is
% activated or downloaded. The key is used only in the Authorization header.
%
% opts fields: PageSize (1..250, default 250), Timeout_s (60),
% MaxRetries (4), RetryPause_s (1), Pause_s (0.25), WindowsUTC (N-by-2
% datetime intervals, each [start,end)), WindowsPerRequest (25), and
% optional WindowSatelliteIDs, one cell of native IDs per window. A batch
% searches the union of its window IDs; omit to search all IDs for every batch.
% If WindowsUTC is omitted or empty, search the whole [startUTC,endUTC).
% Network/pagination failures throw; partial output is never reported complete.
% Planet API: https://docs.planet.com/develop/apis/data/item-search/
if nargin<5||isempty(opts),opts=struct();end
opts=defaults(opts);
apiKey=string(apiKey);satelliteIDs=string(satelliteIDs(:));
assert(isscalar(apiKey)&&~ismissing(apiKey)&&strlength(apiKey)>0, ...
 'poc:quicklook:MissingKey','A Planet API key is required.');
assert(~contains(apiKey,newline)&&~contains(apiKey,char(13)), ...
 'poc:quicklook:InvalidKey','The Planet API key is not a single line.');
assert(~isempty(satelliteIDs)&&all(~ismissing(satelliteIDs))&& ...
 all(strlength(satelliteIDs)>0),'poc:quicklook:SatelliteIDs', ...
 'At least one nonempty native satellite ID is required.');
satelliteIDs=unique(satelliteIDs,'stable');
assert(isdatetime(startUTC)&&isscalar(startUTC)&&~isnat(startUTC)&& ...
 isdatetime(endUTC)&&isscalar(endUTC)&&~isnat(endUTC), ...
 'poc:quicklook:Dates','Search bounds must be scalar datetime values.');
assert(~isempty(startUTC.TimeZone)&&~isempty(endUTC.TimeZone), ...
 'poc:quicklook:Dates','Search bounds must specify a timezone.');
startUTC.TimeZone='UTC';endUTC.TimeZone='UTC';
assert(endUTC>startUTC,'poc:quicklook:Dates', ...
 'The exclusive search end must be later than the start.');

% Planet's date filter is >= start and < end; StringInFilter is OR across IDs.
if isempty(opts.WindowsUTC)
 windows=[startUTC,endUTC];
else
 windows=opts.WindowsUTC;
 assert(isdatetime(windows)&&ismatrix(windows)&&size(windows,2)==2&& ...
  ~isempty(windows.TimeZone)&&~any(isnat(windows),'all'), ...
  'poc:quicklook:Windows','WindowsUTC must be an N-by-2 timezone-aware datetime array.');
 windows.TimeZone='UTC';
 assert(all(windows(:,1)>=startUTC & windows(:,2)<=endUTC & ...
  windows(:,2)>windows(:,1)), 'poc:quicklook:Windows', ...
  'Each [start,end) interval must lie within the search bounds.');
end
if ~isempty(opts.WindowSatelliteIDs)
 assert(iscell(opts.WindowSatelliteIDs)&&numel(opts.WindowSatelliteIDs)==size(windows,1), ...
  'poc:quicklook:Windows','WindowSatelliteIDs must have one cell per search window.');
 for j=1:numel(opts.WindowSatelliteIDs)
  ids=string(opts.WindowSatelliteIDs{j}(:));
  assert(~isempty(ids)&&all(ismember(ids,satelliteIDs)), ...
   'poc:quicklook:SatelliteIDs','Each window must have known, nonempty satellite IDs.');
  opts.WindowSatelliteIDs{j}=ids;
 end
end

auth=matlab.net.http.HeaderField('Authorization','api-key '+apiKey);
contentType=matlab.net.http.field.ContentTypeField('application/json');
httpOpts=matlab.net.http.HTTPOptions('ConnectTimeout',opts.Timeout_s, ...
 'ResponseTimeout',opts.Timeout_s,'MaxRedirects',0);
scenes=poc.quicklook.normalizeScenes([]);
stats=struct('Pages',0,'Features',0,'Searches',0,'DuplicatesRemoved',0, ...
 'StartUTC',startUTC,'EndUTC',endUTC);
for first=1:opts.WindowsPerRequest:size(windows,1)
 last=min(first+opts.WindowsPerRequest-1,size(windows,1));
 batchIDs=satelliteIDs;
 if ~isempty(opts.WindowSatelliteIDs)
  batchIDs=unique(vertcat(opts.WindowSatelliteIDs{first:last}),'stable');
 end
 idFilter=struct();idFilter.type='StringInFilter';
 idFilter.field_name='satellite_id';idFilter.config=cellstr(batchIDs);
 dateFilters=cell(last-first+1,1);
 for j=first:last
  dateFilters{j-first+1}=struct('type','DateRangeFilter','field_name','acquired', ...
   'config',struct('gte',rfc3339(windows(j,1)),'lt',rfc3339(windows(j,2))));
 end
 if numel(dateFilters)==1,dateFilter=dateFilters{1};
 else,dateFilter=struct('type','OrFilter','config',{dateFilters});end
 payload=struct();payload.item_types={'PSScene'};
 payload.filter=struct('type','AndFilter','config',{{dateFilter,idFilter}});
 request=matlab.net.http.RequestMessage('POST',[auth,contentType], ...
  matlab.net.http.MessageBody(payload));
 url="https://api.planet.com/data/v1/quick-search?_sort=acquired%20asc&_page_size="+string(opts.PageSize);
 seen=containers.Map('KeyType','char','ValueType','logical');
 stats.Searches=stats.Searches+1;
 if first>1,pause(opts.Pause_s);end
 while strlength(url)>0
  assertTrustedURL(url);
  assert(~contains(url,apiKey),'poc:quicklook:SensitiveResponse', ...
   'Planet returned credential material in a pagination URL; search was stopped.');
  current=char(url);
  assert(~isKey(seen,current),'poc:quicklook:PaginationLoop', ...
   'Planet returned a repeated pagination URL; search is incomplete.');
  seen(current)=true;
  response=sendWithRetry(request,url,httpOpts,opts);
  body=response.Body.Data;
  if ischar(body)||(isstring(body)&&isscalar(body))
   try,body=jsondecode(body);catch
    error('poc:quicklook:Response','Planet returned invalid JSON.');
   end
  end
  assert(isstruct(body)&&isscalar(body)&&isfield(body,'features'), ...
   'poc:quicklook:Response','Planet returned an unexpected search response.');
  links=readObject(body,{'x_links','_links','links'});
  assert(isstruct(links)&&~isempty(fieldnames(links))&& ...
   (isfield(links,'x_self')||isfield(links,'_self')||isfield(links,'self')), ...
   'poc:quicklook:Response', ...
   'Planet search response has no self link; completeness cannot be verified.');
  page=poc.quicklook.normalizeScenes(body.features);
  % Refuse to persist any server-provided string containing the credential.
  for column=1:width(page)
   v=page{:,column};
   if isstring(v)
    assert(~any(contains(v,apiKey)),'poc:quicklook:SensitiveResponse', ...
     'Planet response included credential material; search was stopped.');
   end
  end
  scenes=[scenes;page]; %#ok<AGROW>
  stats.Pages=stats.Pages+1;stats.Features=stats.Features+height(page);
  url=readNext(links);
  if strlength(url)>0
   % Never follow redirects or send the key anywhere other than Planet's API.
   assertTrustedURL(url);
   request=matlab.net.http.RequestMessage('GET',auth);
   pause(opts.Pause_s);
  end
 end
 if mod(stats.Searches,10)==0 || last==size(windows,1)
  fprintf('Planet search: %d/%d window batches, %d pages, %d scenes.\n', ...
   stats.Searches,ceil(size(windows,1)/opts.WindowsPerRequest), ...
   stats.Pages,stats.Features);
 end
end
% Overlapping search windows may return the same catalogue scene repeatedly.
% Keep the first version in acquired-time search order; retain malformed IDs.
if ~isempty(scenes)
 ids=scenes.SceneID;valid=strlength(ids)>0;
 ix=find(valid);[~,first]=unique(ids(valid),'stable');
 keep=true(height(scenes),1);keep(ix)=false;keep(ix(first))=true;
 stats.DuplicatesRemoved=sum(~keep);scenes=scenes(keep,:);
end
end

function response=sendWithRetry(request,url,httpOpts,opts)
for attempt=0:opts.MaxRetries
 try
  response=send(request,char(url),httpOpts);
 catch
  % Do not display exception text: it can contain request headers or URLs.
  if attempt==opts.MaxRetries
   error('poc:quicklook:Network', ...
    'Planet API request failed after retries. Check connectivity and MATLAB network settings.');
  end
  pause(min(30,opts.RetryPause_s*2^attempt));continue
 end
 code=str2double(string(response.StatusCode));
 if code>=200&&code<300,return;end
 if (code==429||code==500||code==502||code==503||code==504) && attempt<opts.MaxRetries
  delay=min(30,opts.RetryPause_s*2^attempt);
  fields=response.getFields('Retry-After');
  if ~isempty(fields)
   requested=retryDelay(fields(1).Value);
   if ~isfinite(requested)||requested>60
    error('poc:quicklook:RateLimit', ...
     'Planet requested a retry delay that cannot be handled automatically; retry later.');
   end
   delay=max(delay,max(0,requested));
  end
  pause(delay);continue
 end
 if code==401||code==403
  error('poc:quicklook:Authentication', ...
   'Planet rejected the request. Check the API key and catalogue permissions.');
 end
 error('poc:quicklook:HTTP','Planet API returned HTTP status %g; search is incomplete.',code);
end
end

function delay=retryDelay(value)
% Retry-After can contain either seconds or an HTTP date.
delay=str2double(string(value));
if isfinite(delay),return;end
try
 at=datetime(char(string(value)),'InputFormat', ...
  "eee, dd MMM yyyy HH:mm:ss 'GMT'",'Locale','en_US','TimeZone','UTC');
 delay=seconds(at-datetime('now','TimeZone','UTC'));
catch
 delay=NaN;
end
end

function assertTrustedURL(url)
% Reject userinfo, redirects, non-HTTPS and attacker-controlled hosts.
pattern='^https://api\.planet\.com(?::443)?/data/v1/[^\s#]*$';
assert(isscalar(url)&&~ismissing(url)&&~isempty(regexpi(char(url),pattern,'once')), ...
 'poc:quicklook:PaginationURL', ...
 'Planet returned an untrusted pagination URL; search is incomplete.');
end

function result=readObject(parent,names)
result=[];
for k=1:numel(names)
 if isfield(parent,names{k})&&isstruct(parent.(names{k}))&&isscalar(parent.(names{k}))
  result=parent.(names{k});return
 end
end
end

function next=readNext(links)
next="";
for name={'x_next','_next','next'}
 if isfield(links,name{1})
  value=links.(name{1});
  if isempty(value),return;end
  assert((isstring(value)&&isscalar(value))||(ischar(value)&&isrow(value)), ...
   'poc:quicklook:Response','Planet returned an invalid next-page link.');
  next=string(value);return
 end
end
end

function out=rfc3339(t)
% Preserve fractional time when callers search short windows.
t.TimeZone='UTC';t.Format="yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'";
out=char(t);
end

function o=defaults(o)
assert(isstruct(o)&&isscalar(o),'poc:quicklook:Options','Options must be a scalar structure.');
fields={'PageSize','Timeout_s','MaxRetries','RetryPause_s','Pause_s','WindowsUTC','WindowsPerRequest','WindowSatelliteIDs'};
values={250,60,4,1,0.25,[],25,[]};
for k=1:numel(fields),if ~isfield(o,fields{k}),o.(fields{k})=values{k};end,end
assert(isnumeric(o.PageSize)&&isscalar(o.PageSize)&&isfinite(o.PageSize)&& ...
 o.PageSize>=1&&o.PageSize<=250&&fix(o.PageSize)==o.PageSize, ...
 'poc:quicklook:Options','PageSize must be an integer from 1 to 250.');
assert(isnumeric(o.MaxRetries)&&isscalar(o.MaxRetries)&&isfinite(o.MaxRetries)&& ...
 o.MaxRetries>=0&&fix(o.MaxRetries)==o.MaxRetries, ...
 'poc:quicklook:Options','MaxRetries must be a nonnegative integer.');
assert(isnumeric(o.WindowsPerRequest)&&isscalar(o.WindowsPerRequest)&& ...
 isfinite(o.WindowsPerRequest)&&o.WindowsPerRequest>=1&& ...
 fix(o.WindowsPerRequest)==o.WindowsPerRequest, ...
 'poc:quicklook:Options','WindowsPerRequest must be a positive integer.');
for name={'Timeout_s','RetryPause_s','Pause_s'}
 value=o.(name{1});
 assert(isnumeric(value)&&isscalar(value)&&isfinite(value)&&value>=0, ...
  'poc:quicklook:Options','Timeout and pause options must be nonnegative finite scalars.');
end
assert(o.Timeout_s>0,'poc:quicklook:Options','Timeout_s must be positive.');
end
