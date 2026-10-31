function row=fetchCached(url,path,kind,date,cfg)
%FETCHCACHED Never overwrite a cached payload; errors stay in the manifest.
row=poc.schema("manifest");row.Kind=kind;row.ArchiveDateUTC=date;
row.SourceURL=url;row.LocalPath=string(path);
if isfile(path)
 row.Status="CACHED";
else
 if ~cfg.download.enabled
  row.Status="MISSING_OFFLINE";return;
 end
 parent=fileparts(path);if ~isfolder(parent),mkdir(parent);end
 tmp=string(tempname(parent))+".part";
 for attempt=1:cfg.download.retries
  try
   websave(tmp,url,weboptions('Timeout',cfg.download.timeout_s));
   f=dir(tmp);
   assert(~isempty(f)&&f.bytes>0,'poc:io:Empty','Empty response.');
   [fid,msg]=fopen(tmp,'r');assert(fid>=0,'poc:io:Open','%s',msg);
   h=char(fread(fid,256,'*char').');fclose(fid);
   assert(~contains(lower(string(h)),["<html","<!doctype"]), ...
       'poc:io:HTML','HTML returned instead of data.');
   movefile(tmp,path);
   row.Status="DOWNLOADED";
   row.RetrievedUTC=string(datetime('now','TimeZone','UTC', ...
       'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
   break;
  catch ME
   row.Message=string(ME.identifier)+": "+string(ME.message);
   if isfile(tmp),delete(tmp);end
   if contains(lower(row.Message),["404","not found"]),break;end
   if attempt<cfg.download.retries,pause(attempt);end
  end
 end
 if row.Status=="",row.Status="DOWNLOAD_FAILED";return;end
 pause(cfg.download.pause_s);
end
f=dir(path);row.Bytes=f.bytes;row.SHA256=poc.io.hashFile(path);
sidecar=string(path)+".provenance.json";
if ~isfile(sidecar)
 poc.io.writeText(sidecar,jsonencode(row,'PrettyPrint',true));
else
 original=jsondecode(fileread(sidecar));
 if isfield(original,'SHA256') && string(original.SHA256)~=row.SHA256
  row.Status="CACHE_HASH_MISMATCH";
  row.Message="Cached payload differs from its archived provenance hash.";
 elseif isfield(original,'RetrievedUTC')
  row.RetrievedUTC=string(original.RetrievedUTC);
 end
end
end
