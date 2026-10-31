function tests=test_weekly
 tests=functiontests(localfunctions);
end
function testFirstAcceptedISOWeek(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'utils'));
 z=poc.schema("pair");z.Satellite="A";z.PairID="a";
 z.DateUTC=datetime(2026,3,1,'TimeZone','UTC'); % Sunday in partial boundary week.
 rows=z;
 z.DateUTC=datetime(2026,3,2,'TimeZone','UTC');z.PairID="b";rows(end+1)=z;
 z.DateUTC=datetime(2026,3,4,'TimeZone','UTC');z.PairID="c";rows(end+1)=z;
 z.Satellite="B";z.PairID="d";rows(end+1)=z;
 W=poc.pairing.weekly(struct2table(rows));
 verifyEqual(t,sort(W.PairID),["a";"b";"d"]);
end
