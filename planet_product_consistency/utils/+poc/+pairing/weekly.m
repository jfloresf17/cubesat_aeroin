function W=weekly(R)
%WEEKLY First accepted comparison per satellite/ISO week, partial weeks included.
if isempty(R),W=R;return;end
R=sortrows(R,{'DateUTC','Satellite','PairID'});
d=R.DateUTC;
% MATLAB weekday: Sunday=1. ISO week starts Monday; key by that Monday date.
monday=d-caldays(mod(weekday(d)+5,7));
key=R.Satellite+"|"+string(monday,'yyyy-MM-dd');
[~,ix]=unique(key,'stable');W=R(ix,:);
end
