function [lat,lon,h]=ecefToGeodetic(r)
%ECEFTOGEODETIC WGS84 geodetic latitude/longitude (degrees), ellipsoid-normal h.
a=6378137;f=1/298.257223563;e2=f*(2-f);b=a*(1-f);
r=r(:);assert(numel(r)==3&&all(isfinite(r))&&norm(r)>0, ...
 'poc:metric:ECEF','Invalid Earth-fixed position.');
p=hypot(r(1),r(2));lon=atan2(r(2),r(1));
if p<1e-9
 lat=sign(r(3))*pi/2;h=abs(r(3))-b;
else
 lat=atan2(r(3),p*(1-e2));converged=false;
 for k=1:30
  N=a/sqrt(1-e2*sin(lat)^2);
  newlat=atan2(r(3)+e2*N*sin(lat),p);
  if abs(newlat-lat)<1e-14,lat=newlat;converged=true;break;end
  lat=newlat;
 end
 assert(converged,'poc:metric:GeodeticConvergence','Geodetic conversion did not converge.');
 N=a/sqrt(1-e2*sin(lat)^2);
 if abs(cos(lat))>1e-8,h=p/cos(lat)-N;else,h=r(3)/sin(lat)-N*(1-e2);end
end
lat=lat*180/pi;lon=lon*180/pi;
end
