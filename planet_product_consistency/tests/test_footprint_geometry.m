function tests=test_footprint_geometry
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'utils'));
t.TestData.ell=wgs84Ellipsoid('meter');
end

function testWGS84RaysAndOffNadir(t)
ell=t.TestData.ell;S=[ell.SemimajorAxis+475000 0 0];v=[0 7500 0];
o=options();[n,ni]=poc.footprint.reconstruct(S,v,o);
verifyTrue(t,ni.Valid);verifyEqual(t,ni.Status,"OK");
verifyEqual(t,ni.Incidence_deg,0,'AbsTol',1e-8);
verifyLessThan(t,min(n.lat_deg),0);verifyGreaterThan(t,max(n.lat_deg),0);
o.cross_deg=5;[q,qi]=poc.footprint.reconstruct(S,v,o);
verifyTrue(t,qi.Valid);verifyGreaterThan(t,qi.Incidence_deg,5);
verifyLessThan(t,mean(q.lat_deg,'omitnan'),mean(n.lat_deg,'omitnan'));
verifyEqual(t,q.polygons{1}{1}(1,:),q.polygons{1}{1}(end,:),'AbsTol',1e-10);
end

function testNoIntersectionIsNotZeroArea(t)
ell=t.TestData.ell;S=[ell.SemimajorAxis+475000 0 0];v=[0 7500 0];
o=options();o.fovCross_deg=170;
[p,info]=poc.footprint.reconstruct(S,v,o);
verifyFalse(t,info.Valid);verifyEqual(t,info.Status,"NO_INTERSECTION");
verifyEmpty(t,p.polygons);verifyGreaterThan(t,info.MissingBoundaryRays,0);
end

function testGeoJSONIdenticalAndDisjoint(t)
p=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}');
verifyEqual(t,p.lat_deg(1:4),[0;0;1;1]);verifyEqual(t,p.lon_deg(1:4),[0;1;1;0]);
[m,d]=poc.footprint.metrics(p,p,struct('boundaryStep_m',1000));
verifyEqual(t,m.Status,"OK",d.Message);verifyEqual(t,m.IoU,1,'AbsTol',1e-10);
verifyEqual(t,m.BoundarySymmetricP95_m,0,'AbsTol',1e-6);
% Independent ellipsoidal quadrangle area; the mapped polygon uses straight
% chords, so a small finite-vertex approximation difference is expected.
quad=areaquad(0,0,1,1,t.TestData.ell)/1e6;
verifyEqual(t,m.PublishedArea_km2,quad,'RelTol',5e-5);
q=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[3,0],[4,0],[4,1],[3,1],[3,0]]]}');
[m,d]=poc.footprint.metrics(q,p,struct('boundaryStep_m',1000));
verifyEqual(t,m.Status,"OK",d.Message);verifyEqual(t,m.IoU,0,'AbsTol',1e-12);
verifyGreaterThan(t,m.BoundarySymmetricP95_m,100000);
end

function testGeoJSONHolesAndAntimeridian(t)
hole=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[179,10],[-179,10],[-179,12],[179,12],[179,10]],[[179.5,10.5],[179.5,11.5],[-179.5,11.5],[-179.5,10.5],[179.5,10.5]]]}');
solid=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[179,10],[-179,10],[-179,12],[179,12],[179,10]]]}');
[m,d]=poc.footprint.metrics(hole,solid,struct('boundaryStep_m',5000));
verifyEqual(t,m.Status,"OK",d.Message);verifyGreaterThan(t,m.IoU,0.7);
verifyLessThan(t,m.IoU,0.8);verifyGreaterThan(t,m.BoundarySymmetricP95_m,10000);
end

function testMultiPolygon(t)
g=poc.footprint.fromGeoJSON('{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,1],[0,0]]],[[[3,0],[4,0],[4,1],[3,1],[3,0]]]]}');
verifyEqual(t,numel(g.polygons),2);
[m,d]=poc.footprint.metrics(g,g,struct('boundaryStep_m',1000));
verifyEqual(t,m.Status,"OK",d.Message);verifyEqual(t,m.IoU,1,'AbsTol',1e-10);
end

function testIrregularGeoJSONAndSelfIntersection(t)
g=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[0,0],[4,0],[4,4],[0,4],[0,0]],[[1,1],[2,1],[2,2],[1,1]]]}');
verifyEqual(t,numel(g.polygons{1}),2);
[m,d]=poc.footprint.metrics(g,g,struct('boundaryStep_m',5000));
verifyEqual(t,m.Status,"OK",d.Message);verifyEqual(t,m.IoU,1,'AbsTol',1e-10);
g=poc.footprint.fromGeoJSON('{"type":"MultiPolygon","coordinates":[[[[0,0],[2,0],[2,2],[0,2],[0,0]]],[[[4,4],[5,4],[5,5],[4,4]]]]}');
verifyEqual(t,numel(g.polygons),2);
[m,d]=poc.footprint.metrics(g,g,struct('boundaryStep_m',5000));
verifyEqual(t,m.Status,"OK",d.Message);
bad=poc.footprint.fromGeoJSON('{"type":"Polygon","coordinates":[[[0,0],[1,1],[0,1],[1,0],[0,0]]]}');
[m,~]=poc.footprint.metrics(bad,g,struct('boundaryStep_m',5000));
verifyEqual(t,m.Status,"INVALID_GEOMETRY");
end

function testSweptRequiresInstantaneousAndRetainsUnion(t)
ell=t.TestData.ell;R=ell.SemimajorAxis+475000;angle=7500/R;
r=[R 0 0;R*cos(angle) R*sin(angle) 0];v=[0 7500 0;-7500*sin(angle) 7500*cos(angle) 0];
o=options();o.mode="swept";o.timeUTC=datetime(2026,1,1,'TimeZone','UTC')+seconds([0 1]);
verifyError(t,@()poc.footprint.reconstruct(r,v,o),'poc:footprint:Options');
o.fovKind="instantaneous";[sw,info]=poc.footprint.reconstruct(r,v,o);
verifyTrue(t,info.Valid);verifyEqual(t,info.TemporalSampling,"DISCRETE_UNION");
snap=options();[p,~]=poc.footprint.reconstruct(r(1,:),v(1,:),snap);
[m,d]=poc.footprint.metrics(sw,p,struct('boundaryStep_m',500));
verifyEqual(t,m.Status,"OK",d.Message);verifyGreaterThan(t,m.AreaRatio,1);
verifyLessThanOrEqual(t,m.IoU,1);
end

function o=options()
o=struct('mode',"snapshot",'fovKind',"scene_proxy",'along_deg',0,'cross_deg',0, ...
 'roll_deg',0,'fovAlong_deg',2.363869,'fovCross_deg',3.918709,'edgeSamples',8);
end
