function [ns,utc] = tleEpoch(token,L)
%TLEEPOCH Exact YYDDD.dddddddd interpretation, with the NORAD 57-year pivot.
t=regexp(char(token),'^(\d{2})(\d{3})\.(\d{8})$','tokens','once');
assert(~isempty(t),'poc:time:TLEEpoch','Expected YYDDD.dddddddd, got %s.',token);
y=str2double(t{1});if y<57,y=y+2000;else,y=y+1900;end
doy=str2double(t{2});
jan=datetime(y,1,1,'TimeZone','UTC');
last=days(datetime(y+1,1,1,'TimeZone','UTC')-jan);
assert(doy>=1&&doy<=last,'poc:time:TLEDOY','Invalid TLE day-of-year.');
% Eight fractional-day digits have exactly 864000 ns per stored unit.
fractionNs=int64(str2double(t{3}))*int64(864000);
ns=poc.time.utcToTTns(jan+caldays(doy-1),L)+fractionNs;
utc=poc.time.ttToUTC(ns,L);
end
