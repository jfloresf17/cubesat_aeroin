function [states,tles,roster,inventory]=loadSources(cfg,opts)
%LOADSOURCES Read cached native archives without modifying the source cache.
% opts.StartUTC/EndUTC are inclusive UTC dates; opts.RawPath and RosterPath
% identify existing input paths. All available dated archives are scanned:
% archive date is provenance, not the native state or TLE epoch.
root=string(opts.RawPath);
assert(isfolder(root),'poc:quicklook:RawPath','Raw archive directory does not exist: %s',root);
roster=poc.preprocess.readRoster(opts.RosterPath);
leaps=poc.time.readLeaps(cfg.paths.leaps,cfg.time.validThroughUTC);
requestedEnd=dateshift(opts.EndUTC,'start','day')+caldays(1)+seconds(opts.TimeToleranceSeconds);
assert(requestedEnd<=leaps.validThroughUTC && ...
 dateshift(opts.StartUTC,'start','day')-seconds(opts.TimeToleranceSeconds)>=leaps.effectiveUTC(1), ...
 'poc:quicklook:LeapCoverage', ...
 'Requested dates exceed the reviewed leap-second table; update it from an authoritative source before searching.');
states=poc.schema("state",true);tles=poc.schema("tle",true);
parseLog=poc.schema("log",true);
found=[dir(fullfile(root,'planet_*.states'));dir(fullfile(root,'**','planet_*.states')); ...
       dir(fullfile(root,'planet_mc_*.tle'));dir(fullfile(root,'**','planet_mc_*.tle'))];
paths=string(fullfile({found.folder},{found.name})).';
paths=unique(paths,'stable');
n=numel(paths);kind=strings(n,1);archiveDate=NaT(n,1,'TimeZone','UTC');
hash=strings(n,1);status=repmat("PENDING",n,1);message=strings(n,1);
for k=1:n
 if mod(k,50)==1 || k==n
  fprintf('Checking source archive %d/%d.\n',k,n);
 end
 [~,name,ext]=fileparts(paths(k));filename=string(name)+string(ext);
 token=regexp(char(filename),'^planet_(\d{8})\.states$','tokens','once');
 if ~isempty(token)
  kind(k)="state";
 else
  token=regexp(char(filename),'^planet_mc_(\d{8})\.tle$','tokens','once');
  if ~isempty(token),kind(k)="tle";end
 end
 if isempty(token)
  status(k)="IGNORED_NAME";continue;
 end
 try
  archiveDate(k)=datetime(token{1},'InputFormat','yyyyMMdd','TimeZone','UTC');
  hash(k)=poc.io.hashFile(paths(k));
  receiptPath=paths(k)+".receipt.json";
  if isfile(receiptPath)
   receipt=jsondecode(fileread(receiptPath));
   assert(isfield(receipt,'SHA256') && isscalar(string(receipt.SHA256)) && ...
    ~isempty(regexp(char(string(receipt.SHA256)),'^[0-9a-fA-F]{64}$','once')), ...
    'poc:quicklook:Receipt','Missing or invalid receipt SHA-256.');
   assert(strcmpi(string(receipt.SHA256),hash(k)), ...
    'poc:quicklook:Receipt','Cached archive differs from its receipt.');
  end
 catch ME
  status(k)="INPUT_INVALID";message(k)=string(ME.identifier)+": "+string(ME.message);
 end
end
% Different flat/dated copies of the same archive are an unresolved conflict.
for k=1:n
 if kind(k)=="" || isnat(archiveDate(k)),continue;end
 group=find(kind==kind(k) & archiveDate==archiveDate(k));
 validHashes=unique(hash(group(hash(group)~="")));
 if numel(validHashes)>1
  status(group)="ARCHIVE_CONFLICT";
  message(group)="Copies of this dated archive have different SHA-256 hashes.";
 end
end
for k=1:n
 if mod(k,50)==1 || k==n
  fprintf('Parsing source archive %d/%d.\n',k,n);
 end
 if status(k)~="PENDING",continue;end
 earlier=find(kind==kind(k) & archiveDate==archiveDate(k) & ...
  hash==hash(k) & (1:n)'<k & ismember(status,["LOADED","DUPLICATE_COPY"]),1);
 if ~isempty(earlier)
  status(k)="DUPLICATE_COPY";continue;
 end
 try
  if kind(k)=="state"
   [rows,log]=poc.preprocess.readStates(paths(k),archiveDate(k),hash(k),leaps);
   states=[states;rows]; %#ok<AGROW>
  else
   [rows,log]=poc.preprocess.readTLE(paths(k),archiveDate(k),hash(k),leaps);
   tles=[tles;rows]; %#ok<AGROW>
  end
  parseLog=[parseLog;log]; %#ok<AGROW>
  status(k)="LOADED";
 catch ME
  status(k)="PARSE_FAILED";message(k)=string(ME.identifier)+": "+string(ME.message);
 end
 if mod(k,20)==0,fprintf('Quicklook source archives checked: %d/%d\n',k,n);end
end
[states,~]=poc.preprocess.cleanRecords(states,'HWID');
[tles,~]=poc.preprocess.cleanRecords(tles,'CatalogID');
% Scene times can lie just inside the year while a matching state lies just
% outside it. Keep the tolerance margin; TLE epoch must be on the scene day.
start=dateshift(opts.StartUTC,'start','day');
finish=dateshift(opts.EndUTC,'start','day')+caldays(1);
margin=seconds(opts.TimeToleranceSeconds);
states=states(states.EpochUTC>=start-margin & states.EpochUTC<finish+margin,:);
tles=tles(tles.EpochUTC>=start & tles.EpochUTC<finish,:);
inventory=struct;
inventory.Files=table(kind,archiveDate,paths,hash,status,message, ...
 'VariableNames',{'Kind','ArchiveDateUTC','LocalPath','SHA256','Status','Message'});
inventory.ParseLog=parseLog;
dates=(start:caldays(1):finish-caldays(1)).';
stateAvailable=false(numel(dates),1);tleAvailable=false(numel(dates),1);
for k=1:numel(dates)
 stateAvailable(k)=any(kind=="state" & archiveDate==dates(k) & status=="LOADED");
 tleAvailable(k)=any(kind=="tle" & archiveDate==dates(k) & status=="LOADED");
end
inventory.Daily=table(dates,stateAvailable,tleAvailable, ...
 'VariableNames',{'ArchiveDateUTC','StateArchiveAvailable','TLEArchiveAvailable'});
inventory.StateCount=height(states);inventory.TLECount=height(tles);
end
