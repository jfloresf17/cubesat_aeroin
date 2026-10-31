function [T,log] = readTLE(path,archiveDate,sha,L)
%READTLE Read ALL historical records; do not let tleread discard older epochs.
lines=splitlines(string(fileread(path)));
rows=repmat(poc.schema("tle"),0,1);logs=repmat(poc.schema("log"),0,1);
name="";k=1;
while k<=numel(lines)
 raw=lines(k);line=strip(raw,'right');
 if strlength(line)==0||startsWith(strtrim(line),"#"),k=k+1;continue;end
 if ~startsWith(line,"1 ")
  if ~startsWith(line,"2 "),name=regexprep(strtrim(line),'^0\s+','');end
  k=k+1;continue;
 end
 try
  assert(k<numel(lines),'poc:parse:TruncatedTLE','Missing TLE line 2.');
  a=char(line);b=char(strip(lines(k+1),'right'));
  assert(numel(a)==69&&numel(b)==69&&startsWith(string(b),"2 "), ...
   'poc:parse:TLELength','Expected two 69-character TLE lines.');
  assert(poc.preprocess.checksumTLE(a)&&poc.preprocess.checksumTLE(b), ...
   'poc:parse:Checksum','TLE checksum failed.');
  c1=poc.preprocess.catalogNumber(a(3:7));c2=poc.preprocess.catalogNumber(b(3:7));
  assert(c1==c2,'poc:parse:CatalogMismatch','TLE line identifiers disagree.');
  row=poc.schema("tle");row.CatalogID=c1;row.Name=name;
  m=regexp(char(name),'(?:^|\s)([0-9a-fA-F]{4})$','tokens','once');
  if ~isempty(m),row.HeaderHWID=lower(string(m{1}));end
  row.EpochToken=string(a(19:32));
  [row.EpochTTns,row.EpochUTC]=poc.time.tleEpoch(row.EpochToken,L);
  row.BStar=poc.preprocess.tleExponent(a(54:61));
  row.MeanMotion_revday=str2double(b(53:63));
  assert(isfinite(row.MeanMotion_revday)&&row.MeanMotion_revday>0, ...
   'poc:parse:MeanMotion','Invalid mean motion.');
  row.Line1=string(a);row.Line2=string(b);row.Line=k;
  row.ArchiveDateUTC=archiveDate;row.SourcePath=string(path);row.SourceSHA256=sha;
  row.RecordID=poc.io.hashText(row.Name+newline+row.Line1+newline+row.Line2);
  rows(end+1,1)=row; %#ok<AGROW>
 catch ME
  z=poc.schema("log");z.SourcePath=string(path);z.Line=k;
  z.Code=string(ME.identifier);z.Message=string(ME.message);z.Raw=line;
  logs(end+1,1)=z; %#ok<AGROW>
 end
 name="";k=k+2;
end
T=poc.toTable(rows,"tle");log=poc.toTable(logs,"log");
end
