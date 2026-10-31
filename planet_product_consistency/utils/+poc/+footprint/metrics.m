function [stats,detail] = metrics(predicted,published,opts)
%METRICS Whole-polygon overlap and boundary discrepancies, not centre matching.
% Inputs are structures produced by reconstruct/fromGeoJSON with polygons:
% cell of polygon components, each a cell of [lat lon] rings (exterior,
% then holes). Components are unioned. Areas use a shared WGS84 ellipsoidal
% Lambert azimuthal equal-area projection; distances are in that local
% projection and must be interpreted as local metric approximations.
if nargin<3||isempty(opts),opts=struct();end
if ~isfield(opts,'boundaryStep_m'),opts.boundaryStep_m=250;end
if ~isfield(opts,'maxBoundaryPoints'),opts.maxBoundaryPoints=50000;end
assert(isnumeric(opts.boundaryStep_m)&&isscalar(opts.boundaryStep_m)&& ...
 isfinite(opts.boundaryStep_m)&&opts.boundaryStep_m>0, ...
 'poc:footprint:Options','boundaryStep_m must be positive.');
assert(isnumeric(opts.maxBoundaryPoints)&&isscalar(opts.maxBoundaryPoints)&& ...
 isfinite(opts.maxBoundaryPoints)&&opts.maxBoundaryPoints>=4&& ...
 fix(opts.maxBoundaryPoints)==opts.maxBoundaryPoints, ...
 'poc:footprint:Options','maxBoundaryPoints must be an integer at least four.');
fields={'PublishedArea_km2','PredictedArea_km2','Intersection_km2', ...
 'PublishedCoverage','PredictedCoverage','IoU','SymmetricDifference_km2','AreaRatio', ...
 'BoundaryPublishedToPredMedian_m','BoundaryPublishedToPredP95_m', ...
 'BoundaryPredToPublishedMedian_m','BoundaryPredToPublishedP95_m','BoundarySymmetricP95_m'};
stats=struct('Status',"INVALID_GEOMETRY");
for k=1:numel(fields),stats.(fields{k})=NaN;end
detail=struct('Message',"",'Projection',"WGS84 Lambert azimuthal equal-area", ...
 'OriginLat_deg',NaN,'OriginLon_deg',NaN,'BoundaryStep_m',opts.boundaryStep_m, ...
 'PredictedBoundaryLat_deg',[],'PredictedBoundaryLon_deg',[], ...
 'PublishedBoundaryLat_deg',[],'PublishedBoundaryLon_deg',[]);
try
 assert(isstruct(predicted)&&isfield(predicted,'polygons')&&~isempty(predicted.polygons)&& ...
  isstruct(published)&&isfield(published,'polygons')&&~isempty(published.polygons), ...
  'poc:footprint:Geometry','Both geometries must contain polygon components.');
 first=published.polygons{1}{1};lat0=first(1,1);lon0=first(1,2);
 assert(isfinite(lat0)&&isfinite(lon0)&&abs(lat0)<=90&&abs(lon0)<=180, ...
  'poc:footprint:Geometry','Invalid projection origin.');
 m=defaultm('eqaazim');m.origin=[lat0 lon0 0];m.geoid=wgs84Ellipsoid('meter');m=defaultm(m);
 detail.OriginLat_deg=lat0;detail.OriginLon_deg=lon0;
 P=projectGeometry(published,m);Q=projectGeometry(predicted,m);
 AP=area(P);AQ=area(Q);
 assert(isfinite(AP)&&isfinite(AQ)&&AP>0&&AQ>0,'poc:footprint:Geometry', ...
  'Polygon areas must be positive and finite.');
 I=area(intersect(P,Q));U=AP+AQ-I;
 stats.PublishedArea_km2=AP/1e6;stats.PredictedArea_km2=AQ/1e6;
 stats.Intersection_km2=I/1e6;stats.PublishedCoverage=I/AP;
 stats.PredictedCoverage=I/AQ;stats.IoU=I/U;
 stats.SymmetricDifference_km2=(AP+AQ-2*I)/1e6;stats.AreaRatio=AQ/AP;
 [xp,yp]=boundary(P);[xq,yq]=boundary(Q);
 [detail.PublishedBoundaryLat_deg,detail.PublishedBoundaryLon_deg]=projinv(m,xp,yp);
 [detail.PredictedBoundaryLat_deg,detail.PredictedBoundaryLon_deg]=projinv(m,xq,yq);
 [pSamples,pSeg]=sampleBoundary(xp,yp,opts);[qSamples,qSeg]=sampleBoundary(xq,yq,opts);
 pToQ=segmentDistance(pSamples,qSeg);qToP=segmentDistance(qSamples,pSeg);
 stats.BoundaryPublishedToPredMedian_m=percentile(pToQ,0.5);
 stats.BoundaryPublishedToPredP95_m=percentile(pToQ,0.95);
 stats.BoundaryPredToPublishedMedian_m=percentile(qToP,0.5);
 stats.BoundaryPredToPublishedP95_m=percentile(qToP,0.95);
 stats.BoundarySymmetricP95_m=max(stats.BoundaryPublishedToPredP95_m, ...
  stats.BoundaryPredToPublishedP95_m);
 stats.Status="OK";
catch ME
 detail.Message=string(ME.identifier)+": "+string(ME.message);
end
end

function poly=projectGeometry(geom,m)
poly=polyshape();
for j=1:numel(geom.polygons)
 rings=geom.polygons{j};assert(iscell(rings)&&~isempty(rings), ...
  'poc:footprint:Geometry','A polygon component needs an exterior ring.');
 outer=projectRing(rings{1},m);
 for k=2:numel(rings)
  hole=projectRing(rings{k},m);
  overlap=area(intersect(outer,hole));
  assert(abs(overlap-area(hole))<=max(1e-4,area(hole)*1e-8), ...
   'poc:footprint:Geometry','A hole is not inside its exterior ring.');
  outer=subtract(outer,hole);
 end
 poly=union(poly,outer);
end
assert(issimplified(poly)&&area(poly)>0,'poc:footprint:Geometry','Invalid polygon union.');
end

function p=projectRing(ring,m)
assert(isnumeric(ring)&&size(ring,2)==2&&size(ring,1)>=4&&all(isfinite(ring),'all')&& ...
 all(abs(ring(:,1))<=90)&&all(abs(ring(:,2))<=180), ...
 'poc:footprint:Geometry','Rings require finite WGS84 [latitude longitude] pairs.');
assert(all(abs(ring(1,:)-ring(end,:))<1e-9), ...
 'poc:footprint:Geometry','Rings must be closed.');
% Reject the azimuthal antipode, where a common local projection is singular.
lat=deg2rad(ring(:,1));lon=deg2rad(ring(:,2));lat0=deg2rad(m.origin(1));lon0=deg2rad(m.origin(2));
dot0=sin(lat0).*sin(lat)+cos(lat0).*cos(lat).*cos(lon-lon0);
assert(all(dot0>cosd(170)),'poc:footprint:Geometry','Geometry exceeds local projection domain.');
[x,y]=projfwd(m,ring(:,1),ring(:,2));
assert(all(isfinite(x))&&all(isfinite(y)),'poc:footprint:Geometry','Projection failed.');
% issimplified is origin-sensitive for some valid ray-traced rings. Check
% topology independently before letting polyshape normalize orientation and
% roundoff; do not let simplification repair a self-intersection.
assert(simpleRing(x,y),'poc:footprint:Geometry','Self-intersecting or degenerate ring.');
shoelace=abs(sum(x(1:end-1).*y(2:end)-x(2:end).*y(1:end-1)))/2;
p=polyshape(x,y,'Simplify',true,'KeepCollinearPoints',true);
assert(issimplified(p)&&p.NumRegions==1&&area(p)>0&& ...
 abs(area(p)-shoelace)<=max(1e-4,shoelace*1e-8), ...
 'poc:footprint:Geometry','Invalid or zero-area ring.');
end

function ok=simpleRing(x,y)
% A simple closed ring has no zero-length edge or nonadjacent crossing,
% touch, or overlap. Tolerance is 10 micrometres in the projected plane.
x=x(:);y=y(:);n=numel(x)-1;tol=1e-5;ok=false;
if n<3||any(hypot(diff(x),diff(y))<=tol),return;end
for a=1:n
 p=[x(a),y(a)];q=[x(a+1),y(a+1)];
 for b=a+1:n
  if b==a+1||(a==1&&b==n),continue;end
  r=[x(b),y(b)];s=[x(b+1),y(b+1)];
  if segmentsIntersect(p,q,r,s,tol),return;end
 end
end
ok=true;
end

function hit=segmentsIntersect(p,q,r,s,tol)
u=q-p;v=s-r;scale=max(norm(u),norm(v))*tol;
c1=cross2(u,r-p);c2=cross2(u,s-p);c3=cross2(v,p-r);c4=cross2(v,q-r);
if ((c1>scale&&c2< -scale)||(c1< -scale&&c2>scale))&& ...
   ((c3>scale&&c4< -scale)||(c3< -scale&&c4>scale))
 hit=true;return
end
hit=(abs(c1)<=scale&&onSegment(r,p,q,tol))|| ...
 (abs(c2)<=scale&&onSegment(s,p,q,tol))|| ...
 (abs(c3)<=scale&&onSegment(p,r,s,tol))|| ...
 (abs(c4)<=scale&&onSegment(q,r,s,tol));
end

function c=cross2(a,b)
c=a(1)*b(2)-a(2)*b(1);
end

function yes=onSegment(p,a,b,tol)
yes=all(p>=min(a,b)-tol)&&all(p<=max(a,b)+tol);
end

function [points,segments]=sampleBoundary(x,y,opts)
good=isfinite(x(1:end-1))&isfinite(y(1:end-1))&isfinite(x(2:end))&isfinite(y(2:end));
segments=[x(1:end-1) y(1:end-1) x(2:end) y(2:end)];segments=segments(good,:);
len=hypot(segments(:,3)-segments(:,1),segments(:,4)-segments(:,2));
segments=segments(len>0,:);len=len(len>0);
assert(~isempty(len)&&sum(len)>0,'poc:footprint:Geometry','Empty polygon boundary.');
count=max(4,ceil(sum(len)/opts.boundaryStep_m));
assert(count<=opts.maxBoundaryPoints,'poc:footprint:Sampling','Boundary sampling limit exceeded.');
target=(0:count-1)'*(sum(len)/count);cumulative=[0;cumsum(len)];
index=discretize(target,cumulative);frac=(target-cumulative(index))./len(index);
points=segments(index,1:2)+frac.*(segments(index,3:4)-segments(index,1:2));
end

function d=segmentDistance(points,seg)
d2=inf(size(points,1),1);
for k=1:size(seg,1)
 start=seg(k,1:2);delta=seg(k,3:4)-start;den=dot(delta,delta);
 u=max(0,min(1,((points-start)*delta')/den));
 diff=points-(start+u.*delta);d2=min(d2,sum(diff.^2,2));
end
d=sqrt(d2);
end

function q=percentile(values,p)
values=sort(values(:));at=1+(numel(values)-1)*p;lo=floor(at);hi=ceil(at);
q=values(lo)+(at-lo)*(values(hi)-values(lo));
end
