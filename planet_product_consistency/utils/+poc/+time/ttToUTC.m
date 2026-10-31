function utc = ttToUTC(ns,L)
%TTTOUTC Convert integer TT offsets to UTC without subtracting Julian dates.
% Leap-second instants themselves are rejected, not collapsed onto midnight.
assert(isa(ns,'int64'),'poc:time:IntegerInput','TT offset must be int64 nanoseconds.');
utc=NaT(size(ns),'TimeZone','UTC');
b=datetime(2000,1,1,12,0,0,'TimeZone','UTC');
D=int64(86400)*int64(1000000000);
for k=1:numel(ns)
 for j=2:numel(L.deltaAT)
  gap=int64(L.deltaAT(j)-L.deltaAT(j-1))*int64(1000000000);
  if ns(k)>=L.thresholdTTns(j)-gap && ns(k)<L.thresholdTTns(j)
   error('poc:time:LeapSecondInstant', ...
    'Instant lies inside a leap second; use a leap-aware adapter for that case.');
  end
 end
 j=find(L.thresholdTTns<=ns(k),1,'last');
 assert(~isempty(j),'poc:time:LeapValidity','Epoch before leap-table coverage.');
 civil=ns(k)-int64(L.deltaAT(j))*int64(1000000000)-int64(32184000000);
 day=idivide(civil,D,'floor');rem=civil-day*D;
 utc(k)=b+caldays(double(day))+seconds(double(rem)/1e9);
end
poc.time.taiMinusUTC(utc,L); % Enforce reviewed validity.
utc.Format='yyyy-MM-dd HH:mm:ss.SSSSSSSSS';
end
