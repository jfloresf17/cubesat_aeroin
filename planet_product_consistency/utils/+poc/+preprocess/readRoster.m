function R=readRoster(path)
%READROSTER Read a versioned identity roster with historical-approval flags.
opts=detectImportOptions(path,'TextType','string');
strvars={'Satellite','HWID','CatalogID','Flock','ValidFromUTC','ValidToUTC', ...
 'Evidence','HistoricallyVerified'};
opts=setvartype(opts,strvars,'string');R=readtable(path,opts);
R.HWID=lower(strtrim(R.HWID));R.CatalogID=strtrim(R.CatalogID);
R.HistoricallyVerified=ismember(lower(R.HistoricallyVerified),["true","1","yes"]);
R.ValidFromUTC=datetime(R.ValidFromUTC,'InputFormat','yyyy-MM-dd','TimeZone','UTC');
R.ValidToUTC=datetime(R.ValidToUTC,'InputFormat','yyyy-MM-dd','TimeZone','UTC')+caldays(1);
assert(all(R.ValidToUTC>R.ValidFromUTC),'poc:identity:Validity','Invalid roster date span.');
assert(all(strlength(R.HWID)==4),'poc:identity:HWID','HWIDs must retain leading zeros.');
% Allow time-dependent mappings, but never overlapping intervals for either ID.
for k=1:height(R)
 overlap=(R.HWID==R.HWID(k)|R.CatalogID==R.CatalogID(k)) ...
  & R.ValidFromUTC<R.ValidToUTC(k) & R.ValidToUTC>R.ValidFromUTC(k);
 assert(sum(overlap)==1,'poc:identity:AmbiguousRoster', ...
  'Overlapping identity intervals for %s.',R.HWID(k));
end
end
