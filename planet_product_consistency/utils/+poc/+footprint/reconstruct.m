function [geom,info] = reconstruct(rEcef_m,vEcef_mps,opts)
%RECONSTRUCT Conditional WGS84 snapshot or sampled instantaneous swath.
% [geom,info]=...reconstruct(r,v,opts), with N-by-3 ECEF positions in m
% and velocities in m/s. opts fields:
%   mode                "snapshot" or "swept"
%   fovKind             "scene_proxy" for snapshot; "instantaneous" for swept
%   along_deg,cross_deg,roll_deg  scalar or N-vector pointing assumptions
%   fovAlong_deg,fovCross_deg    scalar effective angular widths
%   edgeSamples         integer boundary intervals per edge (default 16)
%   timeUTC             strictly increasing N-vector (required for swept)
% Ground surface is the WGS84 reference ellipsoid; no observed polygon or
% ground centre is used. A sweep is a sampled union, not a guarantee of
% continuous coverage. Record/refine temporal and edge sampling separately.
assert(isnumeric(rEcef_m)&&isnumeric(vEcef_mps)&&size(rEcef_m,2)==3&& ...
 isequal(size(rEcef_m),size(vEcef_mps))&&~isempty(rEcef_m)&& ...
 all(isfinite(rEcef_m),'all')&&all(isfinite(vEcef_mps),'all'), ...
 'poc:footprint:States','Position and velocity must be finite N-by-3 arrays.');
assert(isstruct(opts)&&isscalar(opts),'poc:footprint:Options','Options must be a scalar struct.');
required={'mode','fovKind','along_deg','cross_deg','roll_deg','fovAlong_deg','fovCross_deg'};
for k=1:numel(required),assert(isfield(opts,required{k}),'poc:footprint:Options', ...
 'Missing option %s.',required{k});end
if ~isfield(opts,'edgeSamples'),opts.edgeSamples=16;end
mode=string(opts.mode);kind=string(opts.fovKind);n=size(rEcef_m,1);
assert(isscalar(mode)&&any(mode==["snapshot","swept"]), ...
 'poc:footprint:Options','Mode must be snapshot or swept.');
if mode=="snapshot"
 assert(n==1 && kind=="scene_proxy",'poc:footprint:Options', ...
  'Snapshot requires one state and fovKind="scene_proxy".');
else
 assert(n>=2 && kind=="instantaneous",'poc:footprint:Options', ...
  'Swept mode requires multiple states and independently specified instantaneous FOV.');
 assert(isfield(opts,'timeUTC') && isdatetime(opts.timeUTC) && ...
  numel(opts.timeUTC)==n && ~isempty(opts.timeUTC.TimeZone) && ...
  all(~isnat(opts.timeUTC)) && all(seconds(diff(opts.timeUTC(:)))>0), ...
  'poc:footprint:Options','Swept mode requires strictly increasing timezone-aware timeUTC.');
end
angles=cell(1,3);fields={'along_deg','cross_deg','roll_deg'};
for k=1:3
 a=opts.(fields{k});assert(isnumeric(a)&&isvector(a)&& ...
  (isscalar(a)||numel(a)==n)&&all(isfinite(a)), ...
  'poc:footprint:Options','Pointing angles must be finite scalars or N-vectors.');
 if isscalar(a),a=repmat(a,n,1);end
 angles{k}=double(a(:));
end
assert(all(abs(angles{1})<89)&&all(abs(angles{2})<89), ...
 'poc:footprint:Options','Along/cross angles must be inside (-89,89) degrees.');
for name={'fovAlong_deg','fovCross_deg'}
 f=opts.(name{1});assert(isnumeric(f)&&isscalar(f)&&isfinite(f)&&f>0&&f<178, ...
  'poc:footprint:Options','FOVs must be finite scalars in (0,178) degrees.');
end
m=opts.edgeSamples;assert(isnumeric(m)&&isscalar(m)&&isfinite(m)&&m>=1&&m<=10000&&fix(m)==m, ...
 'poc:footprint:Options','edgeSamples must be a positive integer.');
ell=wgs84Ellipsoid('meter');a=ell.SemimajorAxis;b=ell.SemiminorAxis;
polygons=cell(n,1);latAll=[];lonAll=[];statuses=strings(n,1);
incidence=nan(n,1);azimuth=nan(n,1);missing=nan(n,1);
s=linspace(-1,1,m+1)';
uv=[s(1:end-1),-ones(m,1);ones(m,1),s(1:end-1); ...
 flipud(s(2:end)),ones(m,1);-ones(m,1),flipud(s(2:end))];
for k=1:n
 S=double(rEcef_m(k,:))';v=double(vEcef_mps(k,:))';
 [lat,lon,h]=ecef2geodetic(ell,S(1),S(2),S(3));
 if ~isfinite(h)||h<=0,statuses(k)="NOT_ABOVE_ELLIPSOID";continue;end
 up=[cosd(lat)*cosd(lon);cosd(lat)*sind(lon);sind(lat)];
 z=-up;along=v-dot(v,up)*up;
 if norm(along)<1e-8,statuses(k)="DEGENERATE_VELOCITY";continue;end
 x=along/norm(along);y=cross(z,x);y=y/norm(y);
 boresight=z+tand(angles{1}(k))*x+tand(angles{2}(k))*y;
 boresight=boresight/norm(boresight);
 e1=x-dot(x,boresight)*boresight;
 if norm(e1)<1e-10,statuses(k)="DEGENERATE_POINTING";continue;end
 e1=e1/norm(e1);e2=cross(boresight,e1);psi=angles{3}(k);
 p=cosd(psi)*e1+sind(psi)*e2;q=-sind(psi)*e1+cosd(psi)*e2;
 rays=boresight+ p*(uv(:,1)'*tand(opts.fovAlong_deg/2))+ ...
  q*(uv(:,2)'*tand(opts.fovCross_deg/2));
 rays=rays./vecnorm(rays);
 [XYZ,ok]=intersectEllipsoid(S,rays,a,b);
 missing(k)=sum(~ok);
 if ~all(ok),statuses(k)="NO_INTERSECTION";continue;end
 [latV,lonV]=ecef2geodetic(ell,XYZ(1,:)',XYZ(2,:)',XYZ(3,:)');
 ring=[latV lonV];ring(end+1,:)=ring(1,:);
 polygons{k}={ring};latAll=[latAll;ring(:,1);NaN];lonAll=[lonAll;ring(:,2);NaN]; %#ok<AGROW>
 [G,centerOK]=intersectEllipsoid(S,boresight,a,b);
 if centerOK
  [gLat,gLon]=ecef2geodetic(ell,G(1),G(2),G(3));
  e=[-sind(gLon);cosd(gLon);0];
  nn=[-sind(gLat)*cosd(gLon);-sind(gLat)*sind(gLon);cosd(gLat)];
  u=[cosd(gLat)*cosd(gLon);cosd(gLat)*sind(gLon);sind(gLat)];
  los=S-G;ee=dot(los,e);nnorth=dot(los,nn);uu=dot(los,u);
  incidence(k)=atan2d(hypot(ee,nnorth),uu);
  if hypot(ee,nnorth)>1e-6,azimuth(k)=mod(atan2d(ee,nnorth),360);end
 end
 statuses(k)="OK";
end
valid=all(statuses=="OK");
if ~valid
 % Do not silently publish a partial polygon or partial swept union.
 polygons={};latAll=[];lonAll=[];
end
geom=struct('polygons',{polygons},'lat_deg',latAll,'lon_deg',lonAll);
info=struct('Valid',valid,'Status',statuses,'MissingBoundaryRays',missing, ...
 'Incidence_deg',incidence,'GroundToSatelliteAzimuth_deg',azimuth, ...
 'Mode',mode,'FOVKind',kind,'SampleCount',n,'TemporalSampling',"NOT_APPLICABLE");
if mode=="swept"
 dt=seconds(diff(opts.timeUTC(:)));info.TemporalSampling="DISCRETE_UNION";
 info.Duration_s=seconds(opts.timeUTC(end)-opts.timeUTC(1));info.MaxStep_s=max(dt);
else
 info.Duration_s=0;info.MaxStep_s=0;
end
end

function [P,ok]=intersectEllipsoid(S,D,a,b)
A=(D(1,:).^2+D(2,:).^2)/a^2+D(3,:).^2/b^2;
B=2*((S(1)*D(1,:)+S(2)*D(2,:))/a^2+S(3)*D(3,:)/b^2);
C=(S(1)^2+S(2)^2)/a^2+S(3)^2/b^2-1;
disc=B.^2-4*A*C;ok=disc>=0 & isfinite(disc);tau=nan(size(disc));
ix=find(ok);
if ~isempty(ix)
 root=sqrt(disc(ix));near=(-B(ix)-root)./(2*A(ix));far=(-B(ix)+root)./(2*A(ix));
 pick=near;choose=near<=0;pick(choose)=far(choose);tau(ix)=pick;
end
ok=ok & isfinite(tau) & tau>0;
P=S+D.*tau;
end
