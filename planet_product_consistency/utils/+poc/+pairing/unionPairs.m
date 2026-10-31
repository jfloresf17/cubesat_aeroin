function P=unionPairs(A,B)
%UNIONPAIRS Evaluate shared primary/wide pairs once; retain sample flags later.
P=[A;B];if isempty(P),return;end
[~,u]=unique(P.PairID,'stable');P=P(u,:);
P=sortrows(P,{'StateEpochTTns','Satellite'});
end
