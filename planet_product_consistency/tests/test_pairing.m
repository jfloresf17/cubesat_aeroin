function tests=test_pairing
 tests=functiontests(localfunctions);
end
function setupOnce(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=study_config("demo");L=poc.time.readLeaps(c.paths.leaps,c.time.validThroughUTC);
 t.TestData.cfg=c;t.TestData.L=L;
end
function [S,T,R,c]=fixture(t)
 c=t.TestData.cfg;L=t.TestData.L;u=datetime(2026,3,1,12,0,0,'TimeZone','UTC');n=poc.time.utcToTTns(u,L);
 s=poc.schema("state");s.RecordID="s";s.HWID="00a1";s.EpochUTC=u;s.EpochTTns=n;s.ArchiveDateUTC=dateshift(u,'start','day');
 s.Rx_m=7e6;s.Ry_m=0;s.Rz_m=0;s.Vx_mps=0;s.Vy_mps=7500;s.Vz_mps=0;
 a=poc.schema("tle");a.RecordID="early";a.CatalogID="99001";a.HeaderHWID="00a1";
 a.EpochTTns=n-int64(500000);a.EpochUTC=poc.time.ttToUTC(a.EpochTTns,L);a.ArchiveDateUTC=s.ArchiveDateUTC;
 b=a;b.RecordID="late";b.EpochTTns=n+int64(500000);b.EpochUTC=poc.time.ttToUTC(b.EpochTTns,L);
 S=struct2table(s);T=struct2table([a;b]);
 R=table("Synthetic A","00a1","99001","SYNTHETIC",c.study.startUTC,c.study.endUTC+caldays(1),true,"unit test", ...
  'VariableNames',{'Satellite','HWID','CatalogID','Flock','ValidFromUTC','ValidToUTC','HistoricallyVerified','Evidence'});
end
function testTieEarlier(t)
 [S,T,R,c]=fixture(t);[~,P]=poc.pairing.build(S,T,R,c,int64(1000000),"primary");
 verifyEqual(t,height(P),1);verifyEqual(t,P.TLEID,"early");verifyEqual(t,P.DeltaTime_ns,int64(500000));
end
function testThreshold(t)
 [S,T,R,c]=fixture(t);[D,P]=poc.pairing.build(S,T,R,c,int64(499999),"primary");
 verifyEmpty(t,P);verifyEqual(t,D.Status,"NO_TLE_WITHIN_WINDOW");
end
function testIdentityGate(t)
 [S,T,R,c]=fixture(t);R.HistoricallyVerified=false;c.identity.requireHistoricalApproval=true;
 [D,P]=poc.pairing.build(S,T,R,c,int64(1000000),"primary");
 verifyEmpty(t,P);verifyEqual(t,D.Status,"IDENTITY_NOT_HISTORICALLY_APPROVED");
end
function testRevisionExclusion(t)
 [S,T,R,c]=fixture(t);T.Status(:)="CONFLICTING_REVISION";
 [D,P]=poc.pairing.build(S,T,R,c,int64(1000000),"primary");
 verifyEmpty(t,P);verifyEqual(t,D.Status,"NO_VALID_TLE_FOR_IDENTITY");
end
function testLatestEligible(t)
 [S,T,R,c]=fixture(t);S2=S;S2.RecordID="later_state";
 S2.EpochTTns=S2.EpochTTns+int64(10)*int64(1000000000);
 S2.EpochUTC=poc.time.ttToUTC(S2.EpochTTns,t.TestData.L);
 [~,P]=poc.pairing.build([S;S2],T,R,c,int64(1000000),"primary");
 verifyEqual(t,P.StateID,"s"); % The later state has no eligible partner.
end
