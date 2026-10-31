function result=run_footprint_study(opts)
%RUN_FOOTPRINT_STUDY Match real Planet scenes and evaluate conditional footprints.
% opts=footprint_study_config(2026); result=run_footprint_study(opts).
% The output is an exploratory consistency analysis, not an accuracy claim.
if nargin<1||isempty(opts),opts=footprint_study_config();end
startup_consistency();validateConfig(opts);
cfg=study_config("pilot");cfg.frames.allowPredictedEOP=opts.AllowPredictedEOP;
start=datetime(opts.Year,1,1,'TimeZone','UTC');finish=datetime(opts.Year+1,1,1,'TimeZone','UTC');
assert(finish+seconds(opts.TimeToleranceSeconds+1)<=cfg.time.validThroughUTC, ...
 'poc:footprint:LeapCoverage','Update the reviewed leap-second table before analysing this year.');
[quick,quickPath]=getQuicklook(opts,start,finish);
m=quick.Matches;
needed={'AcquiredUTC','StateEpochUTC','TLEEpochUTC','SceneID','SatelliteID', ...
 'MatchStatus','GroundControl','QualityCategory','PublishingStage','ViewAngle_deg','GeometryJSON','Instrument'};
assert(all(ismember(needed,m.Properties.VariableNames)),'poc:footprint:Input','Quicklook MAT lacks necessary fields.');
within=m.AcquiredUTC>=start & m.AcquiredUTC<finish & ...
 abs(seconds(m.AcquiredUTC-m.StateEpochUTC))<=opts.TimeToleranceSeconds & ...
 dateshift(m.AcquiredUTC,'start','day')==dateshift(m.TLEEpochUTC,'start','day');
m=m(within,:);
status=repmat("SELECTED",height(m),1);
status(m.MatchStatus~="MATCHED")="IDENTITY_CONFLICT";
quality=m.GroundControl==1 & lower(m.QualityCategory)=="standard" & lower(m.PublishingStage)=="finalized";
if opts.RequireResearchQuality,status(status=="SELECTED" & ~quality)="QUALITY_FILTER";end
status(status=="SELECTED" & upper(m.Instrument)~="PSB.SD")="UNSUPPORTED_INSTRUMENT";
status(status=="SELECTED" & (~isfinite(m.ViewAngle_deg)|strlength(m.GeometryJSON)==0))="MISSING_IMAGING_METADATA";
selected=find(status=="SELECTED");
if isfinite(opts.MaxMatches)&&numel(selected)>opts.MaxMatches
 status(selected(opts.MaxMatches+1:end))="EXPLORATORY_LIMIT";selected=selected(1:opts.MaxMatches);
end
if ~isfolder(opts.ResultsPath),mkdir(opts.ResultsPath);end
runDir=fullfile(opts.ResultsPath,"footprint_"+string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS')));
assert(~isfolder(runDir),'poc:footprint:Output','Output directory already exists.');mkdir(runDir);
m.SelectionStatus=status;writetable(poc.footprint.formatTimeForCSV(m),fullfile(runDir,'matching_inventory.csv'));
if isfield(quick,'ArchiveInventory')&&isfield(quick.ArchiveInventory,'Daily')
 writetable(poc.footprint.formatTimeForCSV(quick.ArchiveInventory.Daily),fullfile(runDir,'archive_coverage.csv'));
end
fprintf('Matched combinations: %d; selected for model: %d. Output: %s\n',height(m),numel(selected),runDir);
orbits=table();footprints=table();scenes=table();geometries=cell(0,1);
eopInfo=struct('Status',"NOT_NEEDED",'SHA256',"",'SourceURL',cfg.download.eopURL);
if ~isempty(selected)
 eopInfo=poc.io.fetchCached(cfg.download.eopURL,cfg.paths.eop,"eop",NaT('TimeZone','UTC'),cfg);
 assert(ismember(eopInfo.Status,["CACHED","DOWNLOADED"]),'poc:footprint:EOP', ...
  'Earth-orientation file unavailable or integrity check failed: %s',eopInfo.Message);
 E=poc.frames.readFinals(cfg.paths.eop);L=poc.time.readLeaps(cfg.paths.leaps,cfg.time.validThroughUTC);
end
for jj=1:numel(selected)
 k=selected(jj);row=m(k,:);
 if mod(jj,10)==1||jj==numel(selected),fprintf('Evaluating matched combination %d/%d.\n',jj,numel(selected));end
 sceneStatus="OK";message="";
 try
  p=poc.footprint.propagatePair(row,row.AcquiredUTC,cfg,L,E);
  om=poc.footprint.orbitMetrics(p,cfg);
  om.FramePolicy=p.FramePolicy;om.EOPStatus=p.EOPStatus;om.CartesianPropagation=p.CartesianPropagation;
  id=identityColumns(row,k);orbits=[orbits;[id struct2table(om)]]; %#ok<AGROW>
  observed=poc.footprint.fromGeoJSON(row.GeometryJSON);
  if opts.Mode=="snapshot"
   times=row.AcquiredUTC;pc=p.rC_E.';vc=p.vC_E.';pt=p.rT_E.';vt=p.vT_E.';
   fovA=2*atand(opts.SceneAlong_m/(2*opts.ReferenceAltitude_m));
   fovC=2*atand(opts.SceneCross_m/(2*opts.ReferenceAltitude_m));kind="scene_proxy";
  else
   times=row.AcquiredUTC+seconds(linspace(-opts.SweepDuration_s/2,opts.SweepDuration_s/2,opts.SweepSamples)).';
   pc=zeros(numel(times),3);vc=pc;pt=pc;vt=pc;
   for q=1:numel(times)
    pq=poc.footprint.propagatePair(row,times(q),cfg,L,E);
    pc(q,:)=pq.rC_E.';vc(q,:)=pq.vC_E.';pt(q,:)=pq.rT_E.';vt(q,:)=pq.vT_E.';
   end
   fovA=opts.InstantaneousFOVAlong_deg;fovC=opts.InstantaneousFOVCross_deg;kind="instantaneous";
  end
  sceneFootprints=table();sceneGeometries=cell(0,1);
  for signValue=opts.CrossSigns(:).'
   model=struct('mode',opts.Mode,'fovKind',kind,'along_deg',opts.AlongPointing_deg, ...
    'cross_deg',signValue*abs(row.ViewAngle_deg),'roll_deg',opts.Roll_deg, ...
    'fovAlong_deg',fovA,'fovCross_deg',fovC,'edgeSamples',opts.EdgeSamples,'timeUTC',times);
   [gc,dc]=poc.footprint.reconstruct(pc,vc,model);
   [gt,dt]=poc.footprint.reconstruct(pt,vt,model);
   assert(dc.Valid&&dt.Valid,'poc:footprint:RayIntersection', ...
    'A modeled sensor boundary ray failed to intersect WGS84; no partial footprint is reported.');
   metricOpts=struct('boundaryStep_m',opts.BoundaryStep_m,'maxBoundaryPoints',opts.MaximumBoundaryPoints);
   [mc,ec]=poc.footprint.metrics(gc,observed,metricOpts);[mt,et]=poc.footprint.metrics(gt,observed,metricOpts);
   [mm,em]=poc.footprint.metrics(gc,gt,metricOpts);
   assert(mc.Status=="OK"&&mt.Status=="OK"&&mm.Status=="OK", ...
    'poc:footprint:InvalidPolygon','Polygon comparison failed: %s', ...
    strjoin([ec.Message,et.Message,em.Message],'; '));
   comparisons={mc,mt,mm};names=["cartesian_vs_published","tle_vs_published","cartesian_vs_tle"];
   [~,middle]=min(abs(seconds(times-row.AcquiredUTC)));
   for a=1:3
    label=table(signValue,names(a),row.ViewAngle_deg,row.SatelliteAzimuth_deg, ...
     dc.Incidence_deg(middle),dt.Incidence_deg(middle), ...
     dc.GroundToSatelliteAzimuth_deg(middle),dt.GroundToSatelliteAzimuth_deg(middle), ...
     'VariableNames',{'CrossSign','Comparison','ReportedViewAngle_deg','ReportedSatelliteAzimuth_deg', ...
     'CartesianIncidence_deg','TLEIncidence_deg','CartesianGroundToSatelliteAzimuth_deg','TLEGroundToSatelliteAzimuth_deg'});
    sceneFootprints=[sceneFootprints;[id label struct2table(comparisons{a})]]; %#ok<AGROW>
   end
   sceneGeometries{end+1,1}=struct('MatchIndex',k,'CrossSign',signValue,'Observed',observed, ...
    'Cartesian',gc,'TLE',gt,'Model',model,'CartesianDiagnostic',dc,'TLEDiagnostic',dt); %#ok<AGROW>
  end
  footprints=[footprints;sceneFootprints];geometries=[geometries;sceneGeometries]; %#ok<AGROW>
 catch ME
  sceneStatus="FAILED";message=string(ME.identifier)+": "+string(ME.message);
  fprintf('  %s: %s\n',row.SceneID,message);
 end
 scenes=[scenes;[identityColumns(row,k) table(sceneStatus,message,'VariableNames',{'Status','Message'})]]; %#ok<AGROW>
end
writetable(poc.footprint.formatTimeForCSV(orbits),fullfile(runDir,'orbital_metrics.csv'));
writetable(poc.footprint.formatTimeForCSV(footprints),fullfile(runDir,'footprint_metrics.csv'));
writetable(poc.footprint.formatTimeForCSV(scenes),fullfile(runDir,'analysis_status.csv'));
summary=orbitSummary(orbits);writetable(summary,fullfile(runDir,'orbital_summary.csv'));
footSummary=footprintSummary(footprints);writetable(footSummary,fullfile(runDir,'footprint_summary.csv'));
result=struct('RunDir',runDir,'Options',opts,'QuicklookMAT',quickPath,'MatchingInventory',m, ...
 'OrbitalMetrics',orbits,'FootprintMetrics',footprints,'AnalysisStatus',scenes, ...
 'OrbitalSummary',summary,'FootprintSummary',footSummary, ...
 'Geometries',{geometries},'EOPProvenance',eopInfo);
save(fullfile(runDir,'footprint_results.mat'),'result','-v7.3');
writeReport(result,quick);
poc.footprint.writeFigures(result);
fprintf('Study output saved: %s\n',runDir);
end

function out=footprintSummary(t)
out=table();
if isempty(t),return;end
for signValue=unique(t.CrossSign).'
 for name=unique(t.Comparison).'
  rows=t(t.CrossSign==signValue & t.Comparison==name & t.Status=="OK",:);
  if isempty(rows),continue;end
  n=height(rows);medianIoU=median(rows.IoU,'omitnan');
  medianCoverage=median(rows.PublishedCoverage,'omitnan');
  medianBoundaryP95=median(rows.BoundarySymmetricP95_m,'omitnan');
  row=table(signValue,name,n,medianIoU,medianCoverage,medianBoundaryP95, ...
   'VariableNames',{'CrossSign','Comparison','N','MedianIoU','MedianPublishedCoverage','MedianSymmetricBoundaryP95_m'});
  out=[out;row]; %#ok<AGROW>
 end
end
end

function out=orbitSummary(t)
out=table();
if isempty(t),return;end
fields=["Radial_m","Transverse_m","Normal_m","Position3D_m","SurfaceGeodesic_m","DeltaHeight_m"];
for k=1:numel(fields)
 values=t.(fields(k));values=values(isfinite(values));
 if isempty(values),continue;end
 measure=fields(k);n=numel(values);meanValue=mean(values);rmsValue=sqrt(mean(values.^2));
 medianValue=median(values);maxAbs=max(abs(values));
 row=table(measure,n,meanValue,rmsValue,medianValue,maxAbs, ...
  'VariableNames',{'Metric','N','Mean','RMS','Median','MaximumAbsolute'});
 out=[out;row]; %#ok<AGROW>
end
end

function t=identityColumns(row,index)
t=table(index,row.SceneID,row.SatelliteID,row.AcquiredUTC,row.StateEpochUTC,row.TLEEpochUTC, ...
 row.SceneMinusState_s,row.SceneMinusTLE_s,row.IdentityStatus, ...
 'VariableNames',{'MatchIndex','SceneID','SatelliteID','AcquiredUTC','StateEpochUTC','TLEEpochUTC', ...
 'SceneMinusState_s','SceneMinusTLE_s','IdentityStatus'});
end

function [r,path]=getQuicklook(opts,start,finish)
path=string(opts.QuicklookMAT);r=[];
if strlength(path)>0
 assert(isfile(path),'poc:footprint:Quicklook','Quicklook MAT does not exist: %s',path);
 s=load(path,'result');assert(isfield(s,'result')&&compatible(s.result,opts,start,finish), ...
  'poc:footprint:Quicklook','The explicit quicklook search does not cover the requested year and tolerance.');
 r=s.result;return
end
if opts.ReuseQuicklook
 files=dir(fullfile(opts.ResultsPath,'quicklook_*','quicklook_results.mat'));
 [~,order]=sort([files.datenum],'descend');
 for i=order
  candidate=string(fullfile(files(i).folder,files(i).name));
  try
   s=load(candidate,'result');
   if isfield(s,'result')&&compatible(s.result,opts,start,finish),r=s.result;path=candidate;break;end
  catch ME
   warning('poc:footprint:QuicklookCache','Cannot read %s: %s',candidate,ME.message);
  end
 end
end
% A catalogue-only snapshot preserves Planet input without preserving prior
% analysis outputs. Re-match it against the currently available native files.
% It contains only the search windows used when the snapshot was acquired;
% newly available archives can require a fresh Planet search for completeness.
if isempty(r)&&opts.ReuseQuicklook
 root=fileparts(mfilename('fullpath'));
 candidate=string(fullfile(root,'data','planet_psscene',sprintf('catalogue_%d.mat',opts.Year)));
 if isfile(candidate)
  loaded=load(candidate,'catalogue');
  assert(isfield(loaded,'catalogue')&&isstruct(loaded.catalogue)&& ...
   isscalar(loaded.catalogue)&&isfield(loaded.catalogue,'Scenes')&& ...
   istable(loaded.catalogue.Scenes)&&isfield(loaded.catalogue,'SearchOptions')&& ...
   isfield(loaded.catalogue,'SearchStats'), ...
   'poc:footprint:Catalogue','Invalid catalogue input snapshot: %s',candidate);
  c=loaded.catalogue;
  if compatible(struct('Options',c.SearchOptions,'Matches',table()),opts,start,finish)
   q=quicklook_config();q.StartUTC=start;q.EndUTC=finish-caldays(1);
   q.TimeToleranceSeconds=opts.TimeToleranceSeconds;q.ResultsPath=opts.ResultsPath;
   q.DownloadThumbnails=false;
   fprintf('Re-matching saved Planet catalogue input against current native archives.\n');
   fprintf('Snapshot contains only its original search windows; new archives can require a fresh API search.\n');
   [states,tles,roster,inventory]=poc.quicklook.loadSources(study_config("audit"),q);
   [matches,sceneStatus]=poc.quicklook.matchScenes(c.Scenes,states,tles,roster,q);
   note="Planet catalogue snapshot covers only its original search windows; newly available archives may require a fresh Planet API search.";
   r=struct('Options',q,'Matches',matches,'Scenes',c.Scenes,'SceneStatus',sceneStatus, ...
    'ArchiveInventory',inventory,'SearchStats',c.SearchStats,'SnapshotCoverageNote',note);
   path=candidate;
  else
   warning('poc:footprint:CatalogueCoverage', ...
    'Saved catalogue input does not cover the requested year and tolerance; a fresh search is required.');
  end
 end
end
if isempty(r)
 q=quicklook_config();q.StartUTC=start;q.EndUTC=finish-caldays(1);
 q.TimeToleranceSeconds=opts.TimeToleranceSeconds;q.ResultsPath=opts.ResultsPath;q.DownloadThumbnails=false;
 r=quicklook_inspector(q);path=fullfile(r.RunDir,'quicklook_results.mat');
end
fprintf('Using quicklook search snapshot: %s\n',path);
end

function ok=compatible(r,opts,start,finish)
ok=isstruct(r)&&isfield(r,'Options')&&isfield(r,'Matches')&& ...
 isfield(r.Options,'StartUTC')&&isfield(r.Options,'EndUTC')&&isfield(r.Options,'TimeToleranceSeconds')&& ...
 r.Options.StartUTC<=start && r.Options.EndUTC>=finish-caldays(1) && ...
 r.Options.TimeToleranceSeconds>=opts.TimeToleranceSeconds;
end

function validateConfig(o)
assert(isstruct(o)&&isscalar(o),'poc:footprint:Config','Use footprint_study_config.');
assert(isscalar(o.Year)&&isfinite(o.Year)&&fix(o.Year)==o.Year&&o.Year>=1972, ...
 'poc:footprint:Year','Year must be a UTC calendar year.');
assert(isscalar(o.TimeToleranceSeconds)&&isfinite(o.TimeToleranceSeconds)&&o.TimeToleranceSeconds>=0, ...
 'poc:footprint:Tolerance','Time tolerance must be finite and nonnegative.');
assert(isscalar(o.MaxMatches)&&o.MaxMatches>=0&&(isinf(o.MaxMatches)||fix(o.MaxMatches)==o.MaxMatches), ...
 'poc:footprint:Limit','MaxMatches must be a nonnegative integer or Inf.');
assert(ismember(string(o.Mode),["snapshot","swept"]),'poc:footprint:Mode','Mode must be snapshot or swept.');
assert(~isempty(o.CrossSigns)&&all(ismember(o.CrossSigns,[-1 1]))&&numel(unique(o.CrossSigns))==numel(o.CrossSigns), ...
 'poc:footprint:Pointing','CrossSigns must contain one or both of -1 and +1.');
assert(all(isfinite([o.AlongPointing_deg,o.Roll_deg,o.ReferenceAltitude_m,o.SceneAlong_m,o.SceneCross_m]))&& ...
 o.ReferenceAltitude_m>0&&o.SceneAlong_m>0&&o.SceneCross_m>0, ...
 'poc:footprint:Sensor','Invalid scene proxy parameters.');
assert(isscalar(o.EdgeSamples)&&o.EdgeSamples>=2&&fix(o.EdgeSamples)==o.EdgeSamples, ...
 'poc:footprint:Sensor','EdgeSamples must be an integer of at least two.');
assert(isscalar(o.BoundaryStep_m)&&isfinite(o.BoundaryStep_m)&&o.BoundaryStep_m>0&& ...
 isscalar(o.MaximumBoundaryPoints)&&isfinite(o.MaximumBoundaryPoints)&& ...
 o.MaximumBoundaryPoints>=4&&fix(o.MaximumBoundaryPoints)==o.MaximumBoundaryPoints, ...
 'poc:footprint:Sampling','Invalid boundary distance sampling settings.');
if string(o.Mode)=="swept"
 assert(all(isfinite([o.InstantaneousFOVAlong_deg,o.InstantaneousFOVCross_deg,o.SweepDuration_s]))&& ...
  o.InstantaneousFOVAlong_deg>0&&o.InstantaneousFOVCross_deg>0&&o.SweepDuration_s>0&& ...
  o.SweepSamples>=2&&fix(o.SweepSamples)==o.SweepSamples, ...
  'poc:footprint:Sweep','Swept mode requires explicit positive instantaneous FOVs, duration and at least two samples.');
end
end

function writeReport(r,q)
m=r.MatchingInventory;ok=0;if ~isempty(r.AnalysisStatus),ok=sum(r.AnalysisStatus.Status=="OK");end
lines=["# Acquisition footprint study", "", "Exploratory research output; this is not independently validated position accuracy.", ...
 "", "- UTC year: "+r.Options.Year, "- Quicklook search snapshot: `"+r.QuicklookMAT+"`", ...
 "- Matching combinations: "+height(m), "- Analysed combinations: "+height(r.AnalysisStatus), ...
 "- Successfully analysed combinations: "+ok, "- Unique matched scenes: "+numel(unique(m.SceneID)), ...
 "- Scene–state tolerance (s): "+r.Options.TimeToleranceSeconds, ...
 "- TLE native epoch constraint: same UTC date as acquisition.", ...
 "- Quality filter: "+string(r.Options.RequireResearchQuality), ...
 "- Boundary distance sampling step (m): "+r.Options.BoundaryStep_m, ...
 "- EOP: "+r.EOPProvenance.Status+"; SHA-256: "+r.EOPProvenance.SHA256, ...
 "", "## Interpretation", "", ...
 "Cartesian propagation uses two-body numerical integration; TLE uses MATLAB SGP4. These are product-and-propagator comparisons. The J2000-labelled Cartesian state is treated as ICRF as an unverified pilot assumption. Historical satellite identity and independent SGP4/frame verification remain required.", ...
 "", "Imaging geometry is a common, conditional WGS84 ellipsoid model; no footprint centre is fitted. Cross sign +1 points right of the Earth-fixed ground-track direction and -1 left, looking forward; these are scenarios, not measured attitude or per-product best fits. The same numerical pointing angles are applied in each product's separately constructed local frame, so the ECEF ray directions can differ; footprint discrepancies include this orbit-dependent orientation, not position alone. Along-track pointing and roll are user assumptions; satellite azimuth is recorded but its convention is not used as a verified pointing direction. Published view angle and acquired time may not represent one common ray and exact exposure instant.", ...
 "", "The default snapshot is a rectangular effective scene proxy derived from nominal PSB.SD delivered scene dimensions at 475 km, with an assumed axis assignment. Those dimensions are not instantaneous sensor FOV. Swept mode requires independently supplied instantaneous FOV and duration. Neither scenario models terrain, clouds, attitude telemetry, scan geometry or orthorectification. Overlap is geometric, not usable-image coverage or independent accuracy.", ...
 "", "See matching_inventory.csv for exclusions, analysis_status.csv for failures, and the saved MAT file for geometry and input configuration. Orbital metrics are retained when orbit propagation succeeded but footprint modeling subsequently failed. Counts refer to combinations, not statistically independent acquisitions."];
if isfield(q,'SnapshotCoverageNote')
 lines(end+1)="";lines(end+1)=q.SnapshotCoverageNote;
end
if ~isempty(r.OrbitalMetrics)
 t=r.OrbitalMetrics;
 lines(end+1)="";lines(end+1)="## Time matching";lines(end+1)="";
 lines(end+1)="Both products are evaluated at the same scene nominal UTC. A positive offset means the scene is after the native product epoch.";
 lines(end+1)=sprintf('- Scene minus Cartesian epoch: %.6f to %.6f s.',min(t.SceneMinusState_s),max(t.SceneMinusState_s));
 lines(end+1)=sprintf('- Scene minus TLE epoch: %.6f to %.6f s; %d of %d TLE epochs are later than the scene.', ...
  min(t.SceneMinusTLE_s),max(t.SceneMinusTLE_s),sum(t.SceneMinusTLE_s<0),height(t));
 lines(end+1)="TLEs with later epochs are evaluated retrospectively; the matching rule permits any TLE on the same UTC day.";
end
if ~isempty(r.OrbitalSummary)
 lines(end+1)="";lines(end+1)="## Orbital discrepancy summary (m)";lines(end+1)="";
 lines(end+1)="| Metric | N | Mean | RMS | Median | Maximum absolute |";
 lines(end+1)="|---|---:|---:|---:|---:|---:|";
 for k=1:height(r.OrbitalSummary)
  s=r.OrbitalSummary(k,:);lines(end+1)=sprintf('| %s | %d | %.3f | %.3f | %.3f | %.3f |', ...
   s.Metric,s.N,s.Mean,s.RMS,s.Median,s.MaximumAbsolute); %#ok<AGROW>
 end
end
if ~isempty(r.FootprintSummary)
 lines(end+1)="";lines(end+1)="## Conditional footprint summary";lines(end+1)="";
 lines(end+1)="| Cross sign | Comparison | N | Median IoU | Median reference coverage | Median symmetric boundary P95 (m) |";
 lines(end+1)="|---:|---|---:|---:|---:|---:|";
 for k=1:height(r.FootprintSummary)
  s=r.FootprintSummary(k,:);lines(end+1)=sprintf('| %d | %s | %d | %.4f | %.4f | %.1f |', ...
   s.CrossSign,s.Comparison,s.N,s.MedianIoU,s.MedianPublishedCoverage,s.MedianSymmetricBoundaryP95_m); %#ok<AGROW>
 end
 lines(end+1)="";lines(end+1)="The two signs are separate pointing hypotheses, not independent scenes. For Cartesian-versus-TLE, the TLE model is the coverage reference. Boundary distances use the local equal-area projection and are sampled approximations; test edge, boundary and swept-time sampling for convergence.";
end
if isfield(q,'ArchiveInventory')&&isfield(q.ArchiveInventory,'Daily')
 d=q.ArchiveInventory.Daily;lines(end+1)="";lines(end+1)="Archive dates with both cached products: "+sum(d.StateArchiveAvailable & d.TLEArchiveAvailable)+" / "+height(d)+"; missing dates are not observations.";
end
if ~isempty(r.Geometries)
 lines(end+1)="";lines(end+1)="## Figures";lines(end+1)="";
 lines(end+1)="- [Acquisition and native-epoch timing](acquisition_timing.png)";
 lines(end+1)="- [RTN and subsatellite geodesic discrepancies over time](rtn_geodesic_by_time.png)";
 lines(end+1)="- [Paired WGS84 subsatellite positions](subsatellite_pairs.png)";
 lines(end+1)="- [Example predicted and published footprints](footprint_example.png)";
 lines(end+1)="- [Paired footprint scores, separated by pointing hypothesis](paired_footprint_metrics.png)";
 lines(end+1)="- [Orbital separation distributions](orbital_separation.png) and [footprint overlap distributions](footprint_overlap.png)";
end
poc.io.writeText(fullfile(r.RunDir,'RUN_REPORT.md'),strjoin(lines,newline)+newline);
end
