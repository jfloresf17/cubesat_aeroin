function [r,v]=propagateCartesian(r0,v0,dt)
%PROPAGATECARTESIAN Numerically propagate a state under two-body gravity.
%   r and v are in the same declared inertial frame as r0,v0, in m and
%   m/s. dt is the signed elapsed SI time in seconds. This deliberately
%   simple baseline is not a reconstruction of Planet's OD/force model.
%   No atmospheric drag, J2 or maneuvers are modelled.
r0=r0(:);v0=v0(:);
assert(numel(r0)==3&&numel(v0)==3&&all(isfinite([r0;v0]))&&norm(r0)>0, ...
 'poc:footprint:CartesianState','Position and velocity must be finite 3-vectors.');
assert(isnumeric(dt)&&isscalar(dt)&&isfinite(dt),'poc:footprint:Duration', ...
 'The signed propagation duration must be finite.');
if dt==0,r=r0;v=v0;return;end
mu=3.986004418e14; % WGS84 Earth gravitational parameter, m^3/s^2.
opts=odeset('RelTol',1e-11,'AbsTol',[1e-3 1e-3 1e-3 1e-6 1e-6 1e-6]);
[~,Y]=ode113(@twoBody,[0 double(dt)],[r0;v0],opts);
r=Y(end,1:3)';v=Y(end,4:6)';
assert(all(isfinite([r;v])),'poc:footprint:Propagation','Nonfinite propagated state.');
 function dy=twoBody(~,y)
  radius=norm(y(1:3));
  assert(isfinite(radius)&&radius>0,'poc:footprint:Propagation','Invalid orbit radius.');
  dy=[y(4:6);-mu*y(1:3)/(radius^3)];
 end
end
