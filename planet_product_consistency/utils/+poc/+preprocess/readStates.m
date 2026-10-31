function [S,log] = readStates(path,archiveDate,sha,L)
%READSTATES Preserve native text and exactly decode Planet TT epochs.
lines=splitlines(string(fileread(path)));
rows=repmat(poc.schema("state"),0,1);logs=repmat(poc.schema("log"),0,1);
for k=1:numel(lines)
 line=strtrim(lines(k));if strlength(line)==0||startsWith(line,"#"),continue;end
 try
  p=split(line);p=p(p~="");
  assert(numel(p)==10,'poc:parse:Columns','Expected ten .states fields.');
  assert(~isempty(regexp(char(p(1)),'^[0-9A-Fa-f]{4}$','once')), ...
   'poc:parse:HWID','Non-four-hex HWID; not a target Dove record.');
  row=poc.schema("state");row.RawLine=line;
  row.HWID=lower(p(1));row.EpochToken=p(2);
  row.EpochTTns=poc.time.decimalNs(p(2));
  row.EpochSerializationStep_ns=poc.time.serializationStep(p(2));
  row.EpochUTC=poc.time.ttToUTC(row.EpochTTns,L);
  x=str2double(p(3:10));
  assert(all(isfinite(x(1:6))),'poc:parse:Finite','Nonfinite position/velocity.');
  assert(norm(x(1:3))>0&&norm(cross(x(1:3),x(4:6)))>0, ...
   'poc:parse:State','Degenerate orbital state.');
  row.Rx_m=x(1);row.Ry_m=x(2);row.Rz_m=x(3);
  row.Vx_mps=x(4);row.Vy_mps=x(5);row.Vz_mps=x(6);
  row.BD_kg_m2=x(7);row.BSRP_kg_m2=x(8); % Inf metadata is allowed.
  row.ArchiveDateUTC=archiveDate;row.SourcePath=string(path);
  row.SourceSHA256=sha;row.Line=k;
  row.RecordID=poc.io.hashText(strjoin(p," "));
  rows(end+1,1)=row; %#ok<AGROW>
 catch ME
  z=poc.schema("log");z.SourcePath=string(path);z.Line=k;
  z.Code=string(ME.identifier);z.Message=string(ME.message);z.Raw=line;
  logs(end+1,1)=z; %#ok<AGROW>
 end
end
S=poc.toTable(rows,"state");log=poc.toTable(logs,"log");
end
