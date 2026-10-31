function m=orbitMetrics(pair,cfg)
%ORBITMETRICS Signed TLE-minus-Cartesian RTN and WGS84 differences.
% This is a product-consistency comparison, not an independent accuracy test.
% GroundEast/North are geodesic distance/bearing components, not the ECEF
% chord's ENU components; Position3D_m is the exact Earth-fixed chord.
r=poc.metrics.stateResidual(pair.rT_I,pair.vT_I,pair.rC_I,pair.vC_I,cfg.metrics);
[latC,lonC,hC]=poc.metrics.ecefToGeodetic(pair.rC_E);
[latT,lonT,hT]=poc.metrics.ecefToGeodetic(pair.rT_E);
switch string(cfg.metrics.geodesic)
 case "matlab"
  assert(ismember(exist('wgs84Ellipsoid','file'),[2 3 6])&& ...
   ismember(exist('distance','file'),[2 3 6]),'poc:environment:Mapping', ...
   'Mapping Toolbox is required for MATLAB geodesic distances.');
  [surface,azimuth]=distance(latC,lonC,latT,lonT,wgs84Ellipsoid('m'),'degrees');
 case "vincenty"
  [surface,azimuth]=poc.metrics.vincenty(latC,lonC,latT,lonT);
 otherwise
  error('poc:footprint:Geodesic','Unknown geodesic backend.');
end
assert(isscalar(surface)&&isfinite(surface)&&surface>=0, ...
 'poc:footprint:Geodesic','The WGS84 surface distance failed.');
if surface==0
 east=0;north=0;azimuth=NaN;
else
 assert(isscalar(azimuth)&&isfinite(azimuth),'poc:footprint:Geodesic', ...
  'The WGS84 geodesic bearing failed.');
 east=surface*sind(azimuth);north=surface*cosd(azimuth);
end
chord=norm(pair.rT_E-pair.rC_E);
% Subtracting two Earth-radius vectors also incurs absolute floating-point
% cancellation; a relative tolerance on a short baseline alone is too strict.
frameTol = cfg.metrics.normRelativeTolerance*max(1,r.position) + ...
    10*eps(max(norm(pair.rT_E),norm(pair.rC_E)));
assert(abs(chord-r.position)<=frameTol, ...
 'poc:footprint:FrameNorm','Inertial and Earth-fixed separations disagree.');
m=struct('Radial_m',r.RTN(1),'Transverse_m',r.RTN(2),'Normal_m',r.RTN(3), ...
 'Position3D_m',chord,'Velocity3D_mps',r.velocity, ...
 'LatC_deg',latC,'LonC_deg',lonC,'HeightC_m',hC, ...
 'LatT_deg',latT,'LonT_deg',lonT,'HeightT_m',hT, ...
 'DeltaLat_deg',latT-latC,'DeltaLon_deg',mod(lonT-lonC+180,360)-180, ...
 'DeltaHeight_m',hT-hC,'SurfaceGeodesic_m',surface, ...
 'SurfaceEast_m',east,'SurfaceNorth_m',north,'SurfaceAzimuth_deg',azimuth);
end
