function a = taiMinusUTC(utc,L)
%TAIMINUSUTC Offset at a physical UTC instant; no extrapolation beyond approval.
assert(~isempty(utc.TimeZone),'poc:time:Zone','UTC datetime must be timezone-aware.');
utc.TimeZone='UTC';
assert(all(utc>=L.effectiveUTC(1)&utc<=L.validThroughUTC), ...
 'poc:time:LeapValidity','Epoch is outside the reviewed leap-table validity.');
a=zeros(size(utc));
for k=1:numel(utc)
 j=find(L.effectiveUTC<=utc(k),1,'last');a(k)=L.deltaAT(j);
end
end
