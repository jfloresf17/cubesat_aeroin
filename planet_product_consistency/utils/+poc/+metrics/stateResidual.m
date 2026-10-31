function m=stateResidual(rT,vT,rC,vC,opts)
%STATERESIDUAL TLE-minus-Cartesian differences, with RTN from Cartesian state.
rT=rT(:);vT=vT(:);rC=rC(:);vC=vC(:);
assert(all(isfinite([rT;vT;rC;vC]))&&all([numel(rT),numel(vT),numel(rC),numel(vC)]==3), ...
 'poc:metric:State','Expected finite 3-vectors.');
h=cross(rC,vC);
assert(norm(rC)>0 && norm(h)>1e-12*norm(rC)*norm(vC), ...
 'poc:metric:Degenerate','RTN basis is degenerate.');
R=rC/norm(rC);N=h/norm(h);T=cross(N,R);Q=[R';T';N'];
assert(norm(Q*Q'-eye(3),'fro')<=opts.rtnOrthogonalityTolerance, ...
 'poc:metric:RTNOrthogonality','RTN basis is not orthonormal.');
m.dr=rT-rC;m.dv=vT-vC;m.RTN=Q*m.dr;
m.position=norm(m.dr);m.velocity=norm(m.dv);m.Q=Q;
assert(abs(norm(m.RTN)-m.position)<=opts.normRelativeTolerance*max(1,m.position), ...
 'poc:metric:RTNNorm','RTN projection did not preserve vector length.');
end
