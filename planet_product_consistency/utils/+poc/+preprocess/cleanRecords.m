function [T,O] = cleanRecords(T,identityField)
%CLEANRECORDS Deduplicate identical payloads; exclude unresolved epoch revisions.
% Canonical provenance is the earliest archive occurrence of a payload.
O=T(:,{'RecordID','SourcePath','SourceSHA256','ArchiveDateUTC','Line'});
if isempty(T),return;end
T=sortrows(T,{'ArchiveDateUTC','SourcePath','Line'});
[~,keep,g]=unique(T.RecordID,'stable');
counts=accumarray(g,1);T=T(keep,:);T.DuplicateOccurrences=counts-1;
key=T.(identityField)+"|"+string(T.EpochTTns);
[G,~]=findgroups(key);n=accumarray(G,1);
T.Revision=n(G)>1;
T.Status(T.Revision)="CONFLICTING_REVISION";
T=sortrows(T,{identityField,'EpochTTns','RecordID'});
end
