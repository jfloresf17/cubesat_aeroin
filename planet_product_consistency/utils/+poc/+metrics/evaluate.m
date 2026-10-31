function R=evaluate(ctx)
%EVALUATE Metrics for each independently evaluated pair; failures never become zero.
P=poc.pairing.unionPairs(ctx.primary,ctx.wide);V=ctx.evaluations;c=ctx.cfg;
rows=repmat(poc.schema("metric"),0,1);E=table();
if c.frames.earthMode=="iers_file"
 E=poc.frames.readFinals(c.paths.eop);
 poc.io.writeTable(fullfile(ctx.runDir,'eop_decoded.csv'),E);
 poc.io.writeText(fullfile(ctx.runDir,'eop_sha256.txt'),poc.io.hashFile(c.paths.eop));
end
for i=1:height(P)
 z=poc.schema("metric");z.PairID=P.PairID(i);z.Satellite=P.Satellite(i);
 z.HWID=P.HWID(i);z.DateUTC=P.DateUTC(i);z.DeltaTime_s=P.DeltaTime_s(i);
 z.IsPrimary=ismember(z.PairID,ctx.primary.PairID);
 z.IsWide=ismember(z.PairID,ctx.wide.PairID);
 z.IsAsyncOnly=z.IsWide&&abs(P.DeltaTime_ns(i))>c.pairing.primaryTolerance_ns;
 z.IdentityVerified=P.IdentityVerified(i);z.FramePolicy=c.frames.cartesianMode;
 z.Geodesic=c.metrics.geodesic;z.Backend=c.sgp4.backend;
 try
  v=V(V.PairID==z.PairID,:);
  assert(height(v)==1&&v.Status=="OK",'poc:metric:Evaluation', ...
   'No successful evaluated state. Check evaluated_states.csv.');
  rT=v{1,{'RxT_m','RyT_m','RzT_m'}}';vT=v{1,{'VxT_mps','VyT_mps','VzT_mps'}}';
  rC=v{1,{'RxC_m','RyC_m','RzC_m'}}';vC=v{1,{'VxC_mps','VyC_mps','VzC_mps'}}';
  m=poc.metrics.stateResidual(rT,vT,rC,vC,c.metrics);
  z.dRx_m=m.dr(1);z.dRy_m=m.dr(2);z.dRz_m=m.dr(3);
  z.dVx_mps=m.dv(1);z.dVy_mps=m.dv(2);z.dVz_mps=m.dv(3);
  z.Position_m=m.position;z.Velocity_mps=m.velocity;
  z.Radial_m=m.RTN(1);z.Transverse_m=m.RTN(2);z.Normal_m=m.RTN(3);
  [C,z.EOPStatus]=poc.frames.earthRotation(P.StateEpochUTC(i),c,ctx.leaps,E);
  [z.Ground_m,ll,z.GroundEast_m,z.GroundNorth_m,z.GroundAzimuth_deg]= ...
   poc.metrics.groundDistance(rT,rC,C,c.metrics.geodesic);
  z.LatT_deg=ll(1);z.LonT_deg=ll(2);z.LatC_deg=ll(3);z.LonC_deg=ll(4);
  z.Status="OK";
 catch ME
  z.Status="FAILED";z.Message=string(ME.identifier)+": "+string(ME.message);
 end
 rows(end+1,1)=z; %#ok<AGROW>
end
R=poc.toTable(rows,"metric");
end
