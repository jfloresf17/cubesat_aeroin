function [d,ll,east,north,az]=groundDistance(rT,rC,C,backend)
%GROUNDDISTANCE Simultaneous ellipsoid-normal footpoint separation.
% The Cartesian footpoint is the local origin; az is the initial forward
% geodesic bearing C -> T, measured clockwise from north. East/north are
% distance-and-bearing components, not ECEF chord ENU projections.
% For coincident points az is undefined (NaN), while both components are zero.
[laT,loT]=poc.metrics.ecefToGeodetic(C*rT(:));
[laC,loC]=poc.metrics.ecefToGeodetic(C*rC(:));
ll=[laT,loT,laC,loC];
switch backend
 case "matlab"
  assert(exist('wgs84Ellipsoid','file')==2&&exist('distance','file')==2, ...
   'poc:environment:Mapping','Mapping Toolbox required for the selected geodesic backend.');
  [d,az]=distance(laC,loC,laT,loT,wgs84Ellipsoid('m'),'degrees');
 case "vincenty"
  [d,az]=poc.metrics.vincenty(laC,loC,laT,loT);
 otherwise
  error('poc:metric:GeodesicBackend','Unknown geodesic backend.');
end
assert(isscalar(d)&&isfinite(d)&&d>=0,'poc:metric:Ground','Invalid ground distance.');
if d==0
 east=0;north=0;az=NaN;
else
 assert(isscalar(az)&&isfinite(az),'poc:metric:GroundAzimuth','Invalid ground bearing.');
 az=mod(az,360);
 east=d*sind(az);north=d*cosd(az);
 assert(abs(hypot(east,north)-d)<=1e-12*max(1,d), ...
  'poc:metric:GroundComponents','Ground components do not preserve geodesic distance.');
end
end
