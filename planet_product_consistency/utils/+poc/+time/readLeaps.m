function L = readLeaps(path,validThroughUTC)
%READLEAPS Read explicit effective UTC dates and TAI-UTC offsets.
T=readtable(path,'TextType','string');
if ~isdatetime(T.EffectiveUTC)
 T.EffectiveUTC=datetime(T.EffectiveUTC,'InputFormat','yyyy-MM-dd','TimeZone','UTC');
else
 T.EffectiveUTC.TimeZone='UTC';
end
T=sortrows(T,'EffectiveUTC');
assert(all(diff(T.EffectiveUTC)>seconds(0)),'poc:time:LeapOrder','Duplicate leap dates.');
assert(all(diff(T.TAIminusUTC_s)==1),'poc:time:LeapStep', ...
 'This implementation expects the historic positive-leap table.');
L.effectiveUTC=T.EffectiveUTC;
L.deltaAT=T.TAIminusUTC_s;
L.validThroughUTC=validThroughUTC;
base=datetime(2000,1,1,12,0,0,'TimeZone','UTC');
L.thresholdTTns=int64(seconds(L.effectiveUTC-base))*int64(1000000000)+ ...
 int64(L.deltaAT)*int64(1000000000)+int64(32184000000);
L.source="NAIF naif0012.tls DELTET/DELTA_AT; dated review in docs/SOURCES.md";
end
