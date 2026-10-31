function tests=test_footprint_orbits
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
t.TestData.root=root;
end

function testTwoBodyCircularAndBackward(t)
mu=3.986004418e14;radius=7000000;speed=sqrt(mu/radius);dt=60;
r0=[radius;0;0];v0=[0;speed;0];n=sqrt(mu/radius^3);
[r,v]=poc.footprint.propagateCartesian(r0,v0,dt);
expectedR=radius*[cos(n*dt);sin(n*dt);0];
expectedV=speed*[-sin(n*dt);cos(n*dt);0];
verifyLessThan(t,norm(r-expectedR),1e-3);
verifyLessThan(t,norm(v-expectedV),1e-6);
[rb,vb]=poc.footprint.propagateCartesian(r,v,-dt);
verifyLessThan(t,norm(rb-r0),2e-3);
verifyLessThan(t,norm(vb-v0),2e-6);
[rz,vz]=poc.footprint.propagateCartesian(r0,v0,0);
verifyEqual(t,rz,r0);verifyEqual(t,vz,v0);
verifyError(t,@()poc.footprint.propagateCartesian(r0,v0,NaN), ...
 'poc:footprint:Duration');
end

function testSignedRTNAndWGS84Metrics(t)
cfg=study_config('demo');cfg.metrics.geodesic="vincenty";
pair=struct('rC_I',[7000000;0;0],'vC_I',[0;7500;0], ...
 'rT_I',[7000010;20;30],'vT_I',[0;7500;0], ...
 'rC_E',[7000000;0;0],'rT_E',[7000010;20;30]);
m=poc.footprint.orbitMetrics(pair,cfg);
verifyEqual(t,[m.Radial_m;m.Transverse_m;m.Normal_m],[10;20;30], ...
 'AbsTol',1e-12);
verifyEqual(t,m.Position3D_m,sqrt(1400),'AbsTol',1e-10);
verifyGreaterThan(t,m.SurfaceGeodesic_m,0);
verifyEqual(t,hypot(m.SurfaceEast_m,m.SurfaceNorth_m),m.SurfaceGeodesic_m, ...
 'RelTol',1e-12);
verifyGreaterThan(t,m.DeltaHeight_m,9.99);
end

function testCommonEpochSGP4AndFrameGate(t)
assumeTrue(t,ismember(exist('propagateOrbit','file'),[2 3 6])&& ...
 ismember(exist('tleread','file'),[2 3 6]),'Aerospace Toolbox required.');
path=[tempname,'.tle'];cleanup=onCleanup(@()delete(path)); %#ok<NASGU>
name="FLOCK 4BE 7 2409";
line1="1 60481U 24149P   26221.03108796  .00000000  00000+0  34456-3 0    03";
line2="2 60481 097.3739 304.6256 0003992 089.3974 100.3268 15.42428719    01";
poc.io.writeText(path,"0 "+name+newline+line1+newline+line2+newline);
g=tleread(path);if isempty(g.Epoch.TimeZone),g.Epoch.TimeZone='UTC';end
[r,v]=propagateOrbit(g.Epoch,g,PropModel="sgp4");r=r(:,1);v=v(:,1);
cfg=study_config('demo');cfg.sgp4.backend="matlab";
L=poc.time.readLeaps(cfg.paths.leaps,cfg.time.validThroughUTC);
s=struct('StateEpochUTC',g.Epoch,'StateRx_m',r(1),'StateRy_m',r(2), ...
 'StateRz_m',r(3),'StateVx_mps',v(1),'StateVy_mps',v(2),'StateVz_mps',v(3), ...
 'TLEEpochUTC',g.Epoch,'TLEEpochTTns',poc.time.utcToTTns(g.Epoch,L), ...
 'TLECatalogID',string(g.SatelliteCatalogNumber),'TLEName',name, ...
 'TLELine1',line1,'TLELine2',line2);
row=struct2table(s);
cfg.frames.cartesianMode="unresolved";
verifyError(t,@()poc.footprint.propagatePair(row,g.Epoch,cfg,L,table()), ...
 'poc:frame:Unresolved');
cfg.frames.cartesianMode="identity_assumption";
z=poc.footprint.propagatePair(row,g.Epoch,cfg,L,table());
verifyEqual(t,z.rC_I,r,'AbsTol',1e-8);
verifyEqual(t,z.rT_I,r,'AbsTol',1e-8);
verifyEqual(t,z.rC_E,z.rC_I,'AbsTol',1e-8);
verifyEqual(t,z.vC_E,z.vC_I,'AbsTol',1e-8);
verifyEqual(t,z.EOPStatus,"SYNTHETIC_IDENTITY");
z2=poc.footprint.propagatePair(row,g.Epoch+seconds(.25),cfg,L,table());
verifyEqual(t,z2.SceneMinusState_s,.25,'AbsTol',1e-6);
verifyLessThan(t,norm(z2.rC_I-(r+.25*v)),1);
verifyTrue(t,all(isfinite([z2.rC_E;z2.vC_E;z2.rT_E;z2.vT_E])));
% The Earth-fixed velocity must include the time derivative of rotation.
% Zero-EOP is explicitly a pilot-only fixture, never the research result.
cfg.profile="pilot";cfg.frames.earthMode="zero_eop_pilot";
mid=poc.footprint.propagatePair(row,g.Epoch,cfg,L,table());
before=poc.footprint.propagatePair(row,g.Epoch-seconds(.25),cfg,L,table());
after=poc.footprint.propagatePair(row,g.Epoch+seconds(.25),cfg,L,table());
finiteDifference=(after.rC_E-before.rC_E)/.5;
verifyLessThan(t,norm(mid.vC_E-finiteDifference),.01);
verifyEqual(t,mid.EOPStatus,"ZERO_EOP_PILOT");
end
