function tests=test_metrics
 tests=functiontests(localfunctions);
end
function setupOnce(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 t.TestData.cfg=study_config("demo");
end
function testKnownRTN(t)
 c=t.TestData.cfg;r=[7000000;0;0];v=[0;7500;0];
 m=poc.metrics.stateResidual(r+[3;4;12],v+[0.1;0.2;0.2],r,v,c.metrics);
 verifyEqual(t,m.RTN,[3;4;12],'AbsTol',1e-12);
 verifyEqual(t,m.position,13,'AbsTol',1e-12);
 verifyEqual(t,m.velocity,0.3,'AbsTol',1e-10);
end
function testRmsBiasSD(t)
 X=[5,0.1,3,4,0,4;13,0.3,3,4,12,10];s=poc.stats.point(X);
 verifyEqual(t,s.RMS_Position_m,sqrt(97),'AbsTol',1e-12);
 verifyEqual(t,s.Mean_N_m,6);verifyEqual(t,s.SD_N_m,sqrt(72),'AbsTol',1e-12);
 s1=poc.stats.point(X(1,:));verifyTrue(t,isnan(s1.SD_R_m));
end
function testExactWeights(t)
 x=[1;5;9];w=[2;0;3];
 verifyEqual(t,poc.stats.quantile(x,0.5,w),9);
 verifyEqual(t,poc.stats.quantile(x,0.25,w),1);
end
function testGeodesic(t)
 s=poc.metrics.vincenty(0,0,0,1);
 verifyEqual(t,s,111319.49079327357,'AbsTol',1e-5);
 verifyEqual(t,poc.metrics.vincenty(40,-4,40,-4),0);
 [a,b,h]=poc.metrics.ecefToGeodetic([6378137+400000;0;0]);
 verifyEqual(t,[a,b,h],[0,0,400000],'AbsTol',1e-7);
end
function testGroundCardinalComponents(t)
 % Cartesian is the local origin. Each target is one degree in a cardinal direction.
 c=surfaceECEF(0,0);
 lat=[0,0,1,-1];lon=[1,-1,0,0];expectedAz=[90,270,0,180];
 for k=1:4
  [d,ll,e,n,az]=poc.metrics.groundDistance(surfaceECEF(lat(k),lon(k)),c,eye(3),"vincenty");
  verifyEqual(t,ll,[lat(k),lon(k),0,0],'AbsTol',1e-10);
  verifyEqual(t,az,expectedAz(k),'AbsTol',1e-9);
  verifyEqual(t,hypot(e,n),d,'AbsTol',1e-7);
  if k==1,verifyGreaterThan(t,e,0);verifyEqual(t,n,0,'AbsTol',1e-7);end
  if k==2,verifyLessThan(t,e,0);verifyEqual(t,n,0,'AbsTol',1e-7);end
  if k==3,verifyGreaterThan(t,n,0);verifyEqual(t,e,0,'AbsTol',1e-7);end
  if k==4,verifyLessThan(t,n,0);verifyEqual(t,e,0,'AbsTol',1e-7);end
 end
 [d,~,e,n]=poc.metrics.groundDistance(surfaceECEF(0,1),c,eye(3),"vincenty");
 verifyEqual(t,d,111319.49079327357,'AbsTol',1e-4);
 verifyEqual(t,e,d,'AbsTol',1e-7);verifyEqual(t,n,0,'AbsTol',1e-7);
end
function testGroundCoincidentAndPole(t)
 c=surfaceECEF(40,-4);
 [d,~,e,n,az]=poc.metrics.groundDistance(c,c,eye(3),"vincenty");
 verifyEqual(t,[d,e,n],[0,0,0]);verifyTrue(t,isnan(az));
 % Different altitudes above the same ellipsoid footpoint have zero ground separation.
 [d,~,e,n,az]=poc.metrics.groundDistance([6878137;0;0],[6778137;0;0],eye(3),"vincenty");
 verifyEqual(t,[d,e,n],[0,0,0]);verifyTrue(t,isnan(az));
 % Longitude does not distinguish surface points at the same pole.
 [d,az]=poc.metrics.vincenty(90,0,90,180);
 verifyEqual(t,d,0);verifyTrue(t,isnan(az));
 verifyError(t,@()poc.metrics.vincenty(0,0,0,180),'poc:metric:GeodesicAntipodal');
end
function testGroundDatelineAndHighLatitude(t)
 c=surfaceECEF(0,179.999);target=surfaceECEF(0,-179.999);
 [d,~,e,n,az]=poc.metrics.groundDistance(target,c,eye(3),"vincenty");
 verifyEqual(t,d,222.638981586547,'AbsTol',1e-4);
 verifyGreaterThan(t,e,0);verifyEqual(t,n,0,'AbsTol',1e-7);
 verifyEqual(t,az,90,'AbsTol',1e-9);
 [~,~,e2,~,az2]=poc.metrics.groundDistance(c,target,eye(3),"vincenty");
 verifyLessThan(t,e2,0);verifyEqual(t,az2,270,'AbsTol',1e-9);
 [d,~,e,n,az]=poc.metrics.groundDistance(surfaceECEF(89,-179.999), ...
  surfaceECEF(89,179.999),eye(3),"vincenty");
 verifyTrue(t,all(isfinite([d,e,n,az])));verifyGreaterThan(t,e,0);
 verifyEqual(t,hypot(e,n),d,'AbsTol',1e-8);
end
function testGroundBackendAgreement(t)
 assumeTrue(t,exist('wgs84Ellipsoid','file')==2&&exist('distance','file')==2, ...
  'Mapping Toolbox unavailable.');
 examples=[0,0,0,1;40,-4,40.005,-4.01;89,179.999,89,-179.999];
 for k=1:size(examples,1)
  c=surfaceECEF(examples(k,1),examples(k,2));
  target=surfaceECEF(examples(k,3),examples(k,4));
  [dv,~,ev,nv,av]=poc.metrics.groundDistance(target,c,eye(3),"vincenty");
  [dm,~,em,nm,am]=poc.metrics.groundDistance(target,c,eye(3),"matlab");
  verifyEqual(t,[dv,ev,nv],[dm,em,nm],'AbsTol',0.01);
  verifyEqual(t,mod(av-am+180,360)-180,0,'AbsTol',1e-4);
 end
end
function testFiniteGuard(t)
 verifyError(t,@()poc.metrics.stateResidual([1;0;0],[1;0;0],[1;0;0],[1;0;0],t.TestData.cfg.metrics), ...
  'poc:metric:Degenerate');
end
function r=surfaceECEF(lat,lon)
% Independent geodetic-to-ECEF WGS84 construction for surface test points.
 a=6378137;f=1/298.257223563;e2=f*(2-f);
 s=sind(lat);c=cosd(lat);N=a/sqrt(1-e2*s*s);
 r=[N*c*cosd(lon);N*c*sind(lon);N*(1-e2)*s];
end
