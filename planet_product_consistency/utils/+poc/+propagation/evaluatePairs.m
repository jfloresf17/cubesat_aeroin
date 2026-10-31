function V=evaluatePairs(ctx)
%EVALUATEPAIRS Evaluate unchanged native TLEs; log every failed pair.
cfg=ctx.cfg;P=poc.pairing.unionPairs(ctx.primary,ctx.wide);
rows=repmat(poc.schema("evaluation"),0,1);
selectedDir=fullfile(ctx.runDir,'selected_tles');mkdir(selectedDir);
cache=containers.Map('KeyType','char','ValueType','any');
if cfg.sgp4.backend=="synthetic_fixture"
 fixture=load(fullfile(cfg.paths.raw,'fixture_predictions.mat'),'predictions');
end
for i=1:height(P)
 row=poc.schema("evaluation");row.PairID=P.PairID(i);row.Backend=cfg.sgp4.backend;
 row.FramePolicy=cfg.frames.cartesianMode;clock=tic;
 try
  s=ctx.states(ctx.states.RecordID==P.StateID(i),:);
  t=ctx.tles(ctx.tles.RecordID==P.TLEID(i),:);
  assert(height(s)==1&&height(t)==1,'poc:eval:Record','Nonunique source record.');
  assert(1440/t.MeanMotion_revday<225,'poc:sgp4:Regime', ...
   'Selected record is outside the manuscript near-Earth SGP4 regime.');
  utc=poc.time.ttToUTC(s.EpochTTns,ctx.leaps);
  row.UTCroundTrip_ns=double(poc.time.utcToTTns(utc,ctx.leaps)-s.EpochTTns);
  assert(abs(row.UTCroundTrip_ns)<=double(cfg.time.maxDatetimeRoundTrip_ns), ...
   'poc:time:RoundTrip','UTC round-trip exceeds processing gate.');
  if cfg.sgp4.backend=="synthetic_fixture"
   F=fixture.predictions;
   j=find(F.HWID==s.HWID & F.EpochTTns==s.EpochTTns);
   assert(numel(j)==1,'poc:test:Fixture','No unique synthetic prediction.');
   rT=F{j,{'Rx_m','Ry_m','Rz_m'}}';vT=F{j,{'Vx_mps','Vy_mps','Vz_mps'}}';
   row.ParsedEpochDifference_ns=0;
  else
   key=char(t.RecordID);
   if isKey(cache,key)
    g=cache(key);
   else
    path=fullfile(selectedDir,t.RecordID+".tle");
    poc.io.writeText(path,"0 "+t.Name+newline+t.Line1+newline+t.Line2+newline);
    g=tleread(path);
    assert(isscalar(g),'poc:sgp4:TLECount','Selected file must yield exactly one TLE.');
    if isempty(g.Epoch.TimeZone),g.Epoch.TimeZone='UTC';end
    assert(string(g.SatelliteCatalogNumber)==t.CatalogID, ...
      'poc:sgp4:Identity','tleread changed catalogue identity.');
    assert(abs(g.BStar-t.BStar)<=max(1e-15,abs(t.BStar)*1e-12), ...
      'poc:sgp4:BStar','tleread BStar differs from the native record.');
    cache(key)=g;
   end
   row.ParsedEpochDifference_ns=double(poc.time.utcToTTns(g.Epoch,ctx.leaps)-t.EpochTTns);
   assert(abs(row.ParsedEpochDifference_ns)<=double(cfg.time.maxTlereadEpochDifference_ns), ...
     'poc:sgp4:EpochPrecision','tleread epoch precision exceeds the processing gate.');
   % MathWorks documents the default output as ICRF. R2026b Update 1
   % rejects the documented explicit "icrf" option, so use that default.
   [rT,vT]=propagateOrbit(utc,g,PropModel="sgp4");
   rT=rT(:,1);vT=vT(:,1);
  end
  r=s{1,{'Rx_m','Ry_m','Rz_m'}}';v=s{1,{'Vx_mps','Vy_mps','Vz_mps'}}';
  [rC,vC,row.FramePolicy]=poc.frames.planetToICRF(utc,r,v,cfg);
  assert(all(isfinite([rT;vT;rC;vC])),'poc:eval:Finite','Nonfinite evaluated state.');
  row.RxT_m=rT(1);row.RyT_m=rT(2);row.RzT_m=rT(3);
  row.VxT_mps=vT(1);row.VyT_mps=vT(2);row.VzT_mps=vT(3);
  row.RxC_m=rC(1);row.RyC_m=rC(2);row.RzC_m=rC(3);
  row.VxC_mps=vC(1);row.VyC_mps=vC(2);row.VzC_mps=vC(3);
  row.Status="OK";
 catch ME
  row.Status="FAILED";row.Message=string(ME.identifier)+": "+string(ME.message);
 end
 row.Runtime_s=toc(clock);rows(end+1,1)=row; %#ok<AGROW>
 if mod(i,100)==0,fprintf('States evaluated: %d/%d\n',i,height(P));end
end
V=poc.toTable(rows,"evaluation");
end
