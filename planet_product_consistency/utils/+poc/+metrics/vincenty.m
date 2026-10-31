function [s,az]=vincenty(lat1,lon1,lat2,lon2)
%VINCENTY WGS84 inverse geodesic, degrees -> metres. No spherical fallback.
% az is initial forward bearing from point 1 to point 2, clockwise from north
% in degrees. Bearing is undefined (NaN) for coincident surface points.
% Explicit optional backend; near-antipodal nonconvergence raises an error.
assert(all(isfinite([lat1,lon1,lat2,lon2]))&&abs(lat1)<=90&&abs(lat2)<=90, ...
 'poc:metric:GeodesicInput','Invalid geodetic coordinates.');
a=6378137;f=1/298.257223563;b=a*(1-f);
p1=lat1*pi/180;p2=lat2*pi/180;
L=mod((lon2-lon1)*pi/180+pi,2*pi)-pi;
if abs(p1-p2)<eps&&(abs(L)<eps||abs(abs(p1)-pi/2)<eps)
 s=0;az=NaN;return;
end
U1=atan((1-f)*tan(p1));U2=atan((1-f)*tan(p2));
sU1=sin(U1);cU1=cos(U1);sU2=sin(U2);cU2=cos(U2);
lambda=L;converged=false;
for k=1:200
 sl=sin(lambda);cl=cos(lambda);
 ss=hypot(cU2*sl,cU1*sU2-sU1*cU2*cl);
 cs=sU1*sU2+cU1*cU2*cl;
 if ss<eps
  if cs>0,s=0;az=NaN;return;else,error('poc:metric:GeodesicAntipodal','Antipodal case.');end
 end
 sigma=atan2(ss,cs);sa=cU1*cU2*sl/ss;ca2=max(0,1-sa^2);
 if ca2>1e-15,c2sm=cs-2*sU1*sU2/ca2;else,c2sm=0;end
 C=f/16*ca2*(4+f*(4-3*ca2));
 next=L+(1-C)*f*sa*(sigma+C*ss*(c2sm+C*cs*(-1+2*c2sm^2)));
 if abs(next-lambda)<1e-13,lambda=next;converged=true;break;end
 lambda=next;
end
assert(converged,'poc:metric:GeodesicConvergence','Vincenty failed; no alternate metric substituted.');
u2=ca2*(a*a-b*b)/(b*b);
A=1+u2/16384*(4096+u2*(-768+u2*(320-175*u2)));
B=u2/1024*(256+u2*(-128+u2*(74-47*u2)));
d=B*ss*(c2sm+B/4*(cs*(-1+2*c2sm^2)- ...
 B/6*c2sm*(-3+4*ss^2)*(-3+4*c2sm^2)));
s=b*A*(sigma-d);
% Use the converged longitude, not the previous iteration's sin/cos values.
az=mod(atan2(cU2*sin(lambda),cU1*sU2-sU1*cU2*cos(lambda))*180/pi,360);
end
