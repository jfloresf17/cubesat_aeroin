function tests=test_parsing
 tests=functiontests(localfunctions);
end
function setupOnce(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=study_config("demo");c.paths.raw=tempname;mkdir(c.paths.raw);c.paths.roster=fullfile(c.paths.raw,'roster.csv');
 poc.testing.makeDemo(c);t.TestData.cfg=c;
 t.TestData.L=poc.time.readLeaps(c.paths.leaps,c.time.validThroughUTC);
end
function teardownOnce(t)
 if isfolder(t.TestData.cfg.paths.raw),rmdir(t.TestData.cfg.paths.raw,'s');end
end
function testParseBoth(t)
 c=t.TestData.cfg;d=c.study.startUTC;
 [S,l]=poc.preprocess.readStates(fullfile(c.paths.raw,'planet_20260301.states'),d,"test",t.TestData.L);
 [T,m]=poc.preprocess.readTLE(fullfile(c.paths.raw,'planet_mc_20260301.tle'),d,"test",t.TestData.L);
 verifyEmpty(t,l);verifyEmpty(t,m);verifyEqual(t,height(S),2);verifyEqual(t,height(T),2);
 verifyEqual(t,S.EpochTTns-T.EpochTTns,int64([224000;224000]));
 verifyTrue(t,all(isinf(S.BSRP_kg_m2)));
end
function testDuplicateAndRevision(t)
 c=t.TestData.cfg;[S,~]=poc.preprocess.readStates(fullfile(c.paths.raw,'planet_20260301.states'),c.study.startUTC,"test",t.TestData.L);
 A=S(1,:);B=A;B.RecordID="revision";B.Rx_m=B.Rx_m+1;
 [T,O]=poc.preprocess.cleanRecords([A;A;B],'HWID');
 verifyEqual(t,height(T),2);verifyEqual(t,height(O),3);
 verifyTrue(t,all(T.Revision));verifyEqual(t,sum(T.DuplicateOccurrences),1);
end
function testChecksum(t)
 a='1 60481U 24149P   26221.03108796  .00000000  00000+0  34456-3 0    03';
 verifyTrue(t,poc.preprocess.checksumTLE(a));a(20)='1';verifyFalse(t,poc.preprocess.checksumTLE(a));
end
