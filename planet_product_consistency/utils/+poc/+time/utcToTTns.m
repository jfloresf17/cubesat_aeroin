function ns = utcToTTns(utc,L)
%UTCTOTTNS TT nanoseconds relative to 2000-01-01 12:00:00 TT.
% UTC civil days are converted in integer pieces; leap offsets enter explicitly.
utc.TimeZone='UTC';
a=poc.time.taiMinusUTC(utc,L);
b=datetime(2000,1,1,12,0,0,'TimeZone','UTC');
d=dateshift(utc,'start','day');
whole=int64(seconds(d-b));
small=int64(round(seconds(utc-d)*1e9));
ns=whole*int64(1000000000)+small+int64(a)*int64(1000000000)+int64(32184000000);
end
