function M=acquire(cfg)
%ACQUIRE Enumerate dated products and recognize flat or YYYY/MM cache paths.
rows=repmat(poc.schema("manifest"),0,1);
dates=(cfg.study.startUTC-caldays(cfg.download.guardDays)):caldays(1): ...
 (cfg.study.endUTC+caldays(cfg.download.guardDays));
for k=1:numel(dates)
 ds=string(dates(k),'yyyyMMdd');
 names=["planet_"+ds+".states","planet_mc_"+ds+".tle"];
 kinds=["state","tle"];
 for j=1:2
  flat=fullfile(cfg.paths.raw,names(j));
  nested=fullfile(cfg.paths.raw,string(dates(k),'yyyy'), ...
   string(dates(k),'MM'),names(j));
  % Existing flat payloads win; a missing file downloads to the flat target.
  p=flat;
  if ~isfile(flat)&&isfile(nested),p=nested;end
  row=poc.io.fetchCached(cfg.download.baseURL+names(j),p,kinds(j),dates(k),cfg);
  if ismember(row.Status,["CACHED","DOWNLOADED","CACHE_HASH_MISMATCH"])
   % Receipts provide provenance about bytes, not an authority for local paths.
   row=checkReceipt(row,p,row.SHA256,true);
   if isfile(flat)&&isfile(nested)
    try
     nestedHash=poc.io.hashFile(nested);
     if ~strcmpi(row.SHA256,nestedHash)
      row=flagMismatch(row,"Flat and YYYY/MM copies have different SHA-256 hashes.");
     end
     row=checkReceipt(row,nested,nestedHash,false);
    catch ME
     row=flagMismatch(row,"Cannot verify YYYY/MM copy: "+string(ME.message));
    end
   end
  end
  rows(end+1,1)=row; %#ok<AGROW>
 end
 if mod(k,14)==0,fprintf('Archive dates checked: %d/%d\n',k,numel(dates));end
end
if cfg.download.snapshotIdentity
 p=fullfile(cfg.paths.raw,'identity','18SPCS_matches_v1_snapshot.txt');
 rows(end+1,1)=poc.io.fetchCached(cfg.download.baseURL+"18SPCS_matches_v1.txt", ...
  p,"identity",NaT(1,1,'TimeZone','UTC'),cfg);
end
if cfg.download.fetchEOP
 rows(end+1,1)=poc.io.fetchCached(cfg.download.eopURL,cfg.paths.eop, ...
  "eop",NaT(1,1,'TimeZone','UTC'),cfg);
end
M=struct2table(rows);
end
function row=checkReceipt(row,path,actualHash,recordRetrieved)
% Existing historical receipts are immutable; their LocalFile is never trusted.
receiptPath=string(path)+".receipt.json";
if ~isfile(receiptPath),return;end
try
 receipt=jsondecode(fileread(receiptPath));
 if ~isstruct(receipt)||~isscalar(receipt)||~isfield(receipt,'SHA256')
  row=flagMismatch(row,"Receipt lacks SHA-256: "+receiptPath);return;
 end
 expected=string(receipt.SHA256);
 if ~isscalar(expected)||ismissing(expected)|| ...
   isempty(regexp(char(expected),'^[0-9a-fA-F]{64}$','once'))
  row=flagMismatch(row,"Receipt has invalid SHA-256: "+receiptPath);return;
 end
 if recordRetrieved&&isfield(receipt,'RetrievedUTC')
  retrieved=string(receipt.RetrievedUTC);
  if isscalar(retrieved)&&~ismissing(retrieved),row.RetrievedUTC=retrieved;end
 end
 if ~strcmpi(expected,actualHash)
  row=flagMismatch(row,"Receipt SHA-256 differs from cached payload: "+receiptPath);
 end
catch ME
 row=flagMismatch(row,"Cannot read or validate receipt "+receiptPath+": "+string(ME.message));
end
end
function row=flagMismatch(row,message)
row.Status="CACHE_HASH_MISMATCH";
if strlength(row.Message)>0,row.Message=row.Message+"; "+message;else,row.Message=message;end
end
