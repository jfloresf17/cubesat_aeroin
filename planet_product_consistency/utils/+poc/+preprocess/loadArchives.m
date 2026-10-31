function [S,T,log,occurrences] = loadArchives(M,cfg,L)
%LOADARCHIVES Parse source files and preserve all exclusions and occurrences.
S=poc.schema("state",true);T=poc.schema("tle",true);log=poc.schema("log",true);
for k=1:height(M)
 if ~ismember(M.Status(k),["CACHED","DOWNLOADED"]),continue;end
 switch M.Kind(k)
  case "state"
   [s,l]=poc.preprocess.readStates(M.LocalPath(k),M.ArchiveDateUTC(k),M.SHA256(k),L);
   S=[S;s]; %#ok<AGROW>
  case "tle"
   [t,l]=poc.preprocess.readTLE(M.LocalPath(k),M.ArchiveDateUTC(k),M.SHA256(k),L);
   T=[T;t]; %#ok<AGROW>
  otherwise
   continue;
 end
 log=[log;l]; %#ok<AGROW>
end
[S,os]=poc.preprocess.cleanRecords(S,'HWID');
[T,ot]=poc.preprocess.cleanRecords(T,'CatalogID');
os.Kind=repmat("state",height(os),1);ot.Kind=repmat("tle",height(ot),1);
occurrences=[os;ot];
if ~cfg.pairing.excludeConflictingRevisions
 error('poc:config:RevisionPolicy', ...
  'A revision-resolution policy must be implemented explicitly; automatic acceptance is prohibited.');
end
end
