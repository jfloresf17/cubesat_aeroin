function [rI,vI,policy]=planetToICRF(utc,r,v,cfg)
%PLANETTOICRF Apply a declared, not inferred, interpretation of the J2000 label.
r=r(:);v=v(:);policy=cfg.frames.cartesianMode;
switch policy
 case "identity_assumption"
  rI=r;vI=v;
 case "fixed_rotation"
  C=cfg.frames.rotationToICRF;
  assert(isequal(size(C),[3 3])&&norm(C*C'-eye(3),'fro')<1e-12&&det(C)>0, ...
   'poc:frame:Rotation','Invalid fixed proper rotation.');
  rI=C*r;vI=C*v; % Cdot is zero only because this option is a fixed rotation.
 case "custom"
  assert(strlength(cfg.frames.customFunction)>0,'poc:frame:Custom','Supply a function name.');
  [rI,vI]=feval(char(cfg.frames.customFunction),utc,r,v);
  rI=rI(:);vI=vI(:);
 otherwise
  error('poc:frame:Unresolved','Unrecognized/unresolved frame interpretation.');
end
assert(numel(rI)==3&&numel(vI)==3&&all(isfinite([rI;vI])), ...
 'poc:frame:Finite','Frame transformation returned invalid states.');
end
