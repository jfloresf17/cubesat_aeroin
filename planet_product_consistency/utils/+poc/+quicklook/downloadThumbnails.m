function scenes = downloadThumbnails(scenes,apiKey,outputDir,opts)
%DOWNLOADTHUMBNAILS Save downsampled Planet previews for matched scenes.
% scenes=poc.quicklook.downloadThumbnails(scenes,key,outputDir,opts) adds
% ThumbnailLocalPath and ThumbnailStatus. Images are written under
% outputDir/thumbnails and paths are relative with forward slashes. Only a
% SceneID is needed per row; duplicates are downloaded once.
% Only an HTTPS tiles.planet.com URL constructed from a validated ID is used.
% No key is placed in a URL or written to disk; no redirects are followed.
if nargin<4||isempty(opts),opts=struct();end
opts=defaults(opts);
assert(istable(scenes)&&ismember('SceneID',scenes.Properties.VariableNames), ...
 'poc:quicklook:Thumbnails','A scene table with SceneID is required.');
apiKey=string(apiKey);
assert(isscalar(apiKey)&&~ismissing(apiKey)&&strlength(apiKey)>0&& ...
 ~contains(apiKey,newline)&&~contains(apiKey,char(13)), ...
 'poc:quicklook:MissingKey','A single-line Planet API key is required.');
outputDir=string(outputDir);
assert(isscalar(outputDir)&&~ismissing(outputDir)&&strlength(outputDir)>0, ...
 'poc:quicklook:Thumbnails','A thumbnail output directory is required.');
thumbnailDir=fullfile(outputDir,"thumbnails");
if ~isfolder(thumbnailDir)
 [ok,~]=mkdir(thumbnailDir);
 assert(ok,'poc:quicklook:Thumbnails','Could not create the thumbnail directory.');
end
scenes.ThumbnailLocalPath=repmat("",height(scenes),1);
scenes.ThumbnailStatus=repmat("NOT_REQUESTED",height(scenes),1);
if isempty(scenes),return;end

% Planet documents Basic authentication with the API key as username and
% empty password. No credentials are placed in URLs or exception messages.
token=matlab.net.base64encode(char(apiKey+":"));
auth=matlab.net.http.HeaderField('Authorization',"Basic "+token);
request=matlab.net.http.RequestMessage('GET',auth);
httpOpts=matlab.net.http.HTTPOptions('ConnectTimeout',opts.Timeout_s, ...
 'ResponseTimeout',opts.Timeout_s,'MaxRedirects',0, ...
 'ConvertResponse',false,'SavePayload',true);
done=containers.Map('KeyType','char','ValueType','any');
for k=1:height(scenes)
 id=string(scenes.SceneID(k));
 if ismissing(id)||strlength(id)==0||isempty(regexp(char(id),'^[A-Za-z0-9_-]+$','once'))
  scenes.ThumbnailStatus(k)="INVALID_SCENE_ID";continue
 end
 key=char(id);
 if isKey(done,key)
  outcome=done(key);scenes.ThumbnailStatus(k)=outcome.Status;
  scenes.ThumbnailLocalPath(k)=outcome.Path;continue
 end
 local=fullfile(thumbnailDir,id+".png");
 relative="thumbnails/"+id+".png";
 if isfile(local)
  if validExistingPNG(local),status="EXISTS";path=relative;
  else,status="EXISTING_INVALID";path="";end
 else
  % Construct the only allowed path; do not trust API-supplied arbitrary URLs.
  url="https://tiles.planet.com/data/v1/item-types/PSScene/items/"+id+"/thumb";
  [bytes,status]=getPNG(request,url,httpOpts,opts);
  path="";
  if status=="OK"
   fid=fopen(local,'w');
   if fid<0
    status="WRITE_FAILED";
   else
    try
     written=fwrite(fid,bytes,'uint8');closed=fclose(fid);
    catch
     written=0;closed=-1;
     try,fclose(fid);catch,end
    end
    if written==numel(bytes)&&closed==0&&validExistingPNG(local)
     path=relative;status="DOWNLOADED";
    else
     status="WRITE_FAILED";
     try
      if isfile(local),delete(local);end
     catch
     end
    end
   end
  end
  pause(opts.Pause_s);
 end
 scenes.ThumbnailStatus(k)=status;scenes.ThumbnailLocalPath(k)=path;
 done(key)=struct('Status',status,'Path',path);
end
end

function [bytes,status]=getPNG(request,url,httpOpts,opts)
bytes=uint8([]);status="NETWORK_ERROR";
for attempt=0:opts.MaxRetries
 try
  response=send(request,char(url),httpOpts);
 catch
  % Suppress transport exception text: headers may contain credentials.
  if attempt<opts.MaxRetries,pause(min(30,opts.RetryPause_s*2^attempt));continue;end
  return
 end
 code=str2double(string(response.StatusCode));
 if code==401||code==403,status="NOT_AUTHORIZED";return;end
 if code==404,status="NOT_FOUND";return;end
 if (code==429||ismember(code,[500,502,503,504]))&&attempt<opts.MaxRetries
  delay=min(30,opts.RetryPause_s*2^attempt);
  fields=response.getFields('Retry-After');
  if ~isempty(fields)
   requested=retryDelay(fields(1).Value);
   if ~isfinite(requested)||requested>60,status="RATE_LIMITED";return;end
   delay=max(delay,max(0,requested));
  end
  pause(delay);continue
 end
 if code==429,status="RATE_LIMITED";return;end
 if code<200||code>=300,status="HTTP_ERROR";return;end
 data=response.Body.Data;
 if ~isa(data,'uint8'),data=response.Body.Payload;end
 sig=uint8([137 80 78 71 13 10 26 10]);
 if ~isa(data,'uint8')||numel(data)<numel(sig)||numel(data)>10*1024*1024|| ...
   ~isequal(reshape(data(1:8),1,[]),sig)
  status="INVALID_PNG";return
 end
 bytes=data;status="OK";return
end
end

function ok=validExistingPNG(path)
ok=false;fid=fopen(path,'r');if fid<0,return;end
data=fread(fid,8,'*uint8');fclose(fid);
if ~isequal(reshape(data,1,[]),uint8([137 80 78 71 13 10 26 10])),return;end
try
 info=imfinfo(path);ok=~isempty(info)&&strcmpi(info(1).Format,'png');
catch
 ok=false;
end
end

function delay=retryDelay(value)
delay=str2double(string(value));if isfinite(delay),return;end
try
 at=datetime(char(string(value)),'InputFormat', ...
  "eee, dd MMM yyyy HH:mm:ss 'GMT'",'Locale','en_US','TimeZone','UTC');
 delay=seconds(at-datetime('now','TimeZone','UTC'));
catch
 delay=NaN;
end
end

function o=defaults(o)
assert(isstruct(o)&&isscalar(o),'poc:quicklook:Options','Options must be a scalar structure.');
names={'Timeout_s','Pause_s','RetryPause_s','MaxRetries'};values={30,0.25,1,2};
for k=1:numel(names),if ~isfield(o,names{k}),o.(names{k})=values{k};end,end
for name={'Timeout_s','Pause_s','RetryPause_s'}
 v=o.(name{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=0, ...
  'poc:quicklook:Options','Timeout and pause options must be finite nonnegative scalars.');
end
assert(o.Timeout_s>0&&isnumeric(o.MaxRetries)&&isscalar(o.MaxRetries)&& ...
 isfinite(o.MaxRetries)&&o.MaxRetries>=0&&fix(o.MaxRetries)==o.MaxRetries, ...
 'poc:quicklook:Options','Timeout_s must be positive; MaxRetries must be a nonnegative integer.');
end
