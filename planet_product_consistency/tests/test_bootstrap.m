function tests=test_bootstrap
 tests=functiontests(localfunctions);
end
function setupOnce(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 t.TestData.cfg=study_config("demo");
end
function testBlocks(t)
 a=RandStream('mt19937ar','Seed',10);b=RandStream('mt19937ar','Seed',10);
 [x,s]=poc.stats.drawDateBlocks(31,7,a);y=poc.stats.drawDateBlocks(31,7,b);
 verifyEqual(t,x,y);verifyEqual(t,numel(x),31);
 verifyTrue(t,all(s>=1&s<=25));verifyTrue(t,all(x>=1&x<=31));
 verifyEqual(t,x(1:7),(s(1):s(1)+6)');
end
function testDeterministicIntervals(t)
 c=t.TestData.cfg;rows=repmat(poc.schema("metric"),0,1);
 for k=1:31
  if k==8,continue;end % Empty date retained in the bootstrap window.
  for j=1:2
   z=poc.schema("metric");z.DateUTC=c.study.startUTC+caldays(k-1);
   z.Satellite="S"+j;z.Position_m=5;z.Velocity_mps=.1;
   z.Radial_m=3;z.Transverse_m=4;z.Normal_m=0;z.Ground_m=4;
   z.GroundEast_m=0;z.GroundNorth_m=4;
   rows(end+1,1)=z; %#ok<AGROW>
  end
 end
 R=struct2table(rows);s=c.bootstrap;s.replicates=50;s.minValidReplicates=45;
 A=poc.stats.bootstrap(R,c.study.startUTC,c.study.endUTC,7,s,12);
 B=poc.stats.bootstrap(R,c.study.startUTC,c.study.endUTC,7,s,12);
 verifyEqual(t,A,B);i=A.Metric=="RMS_Position_m";
 verifyEqual(t,A.Lower95(i),5,'AbsTol',1e-12);verifyEqual(t,A.Upper95(i),5,'AbsTol',1e-12);
 i=A.Metric=="Mean_GroundNorth_m";
 verifyEqual(t,A.Lower95(i),4,'AbsTol',1e-12);verifyEqual(t,A.Upper95(i),4,'AbsTol',1e-12);
end
function testGroundComponentStatisticsUseSameWeightedPairs(t)
 X=[5,.1,3,4,0,5,3,4;13,.3,3,4,12,5,-3,4];
 s=poc.stats.point(X,[2;1]);
 verifyEqual(t,s.N,3);
 verifyEqual(t,s.Mean_GroundEast_m,1,'AbsTol',1e-12);
 verifyEqual(t,s.Mean_GroundNorth_m,4,'AbsTol',1e-12);
 verifyEqual(t,s.SD_GroundEast_m,sqrt(12),'AbsTol',1e-12);
 verifyEqual(t,s.RMS_GroundEast_m,3,'AbsTol',1e-12);
 verifyEqual(t,s.RMS_GroundNorth_m,4,'AbsTol',1e-12);
 verifyEqual(t,s.RMS_Ground_m,5,'AbsTol',1e-12);
 verifyError(t,@()poc.stats.point([X(1,1:6),2,4]),'poc:stats:GroundIdentity');
 legacy=poc.stats.point(X(:,1:6));
 verifyTrue(t,isnan(legacy.Mean_GroundEast_m));
 verifyTrue(t,isnan(legacy.RMS_GroundNorth_m));
end
