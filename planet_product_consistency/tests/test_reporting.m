function tests=test_reporting
tests=functiontests(localfunctions);
end
function testReportShowsSignedRTNAndSyntheticProvenance(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
poc.reporting.export(ctx);
text=string(fileread(fullfile(ctx.runDir,'RUN_REPORT.md')));
verifyTrue(t,contains(text,"SYNTHETIC DEMONSTRATION"));
verifyTrue(t,contains(text,"SGP4 was not called"));
verifyTrue(t,contains(text,"| R | 2 | 0 | 4.24264 | 3 |"));
verifyTrue(t,contains(text,"| T | 2 | 4 | 0 | 4 |"));
verifyTrue(t,contains(text,"| East | 2 | 0 | 4.24264 | 3 |"));
verifyTrue(t,contains(text,"| North | 2 | 4 | 0 | 4 |"));
verifyTrue(t,contains(text,"Geographic north is not the RTN orbital normal"));
verifyTrue(t,contains(text,"INSUFFICIENT_DATE_SUPPORT"));
for k=0:7
 verifyTrue(t,contains(text,"## Stage "+string(sprintf('%02d',k))+" -- "));
end
verifyTrue(t,contains(text,"| Usable cached/downloaded entries | 2 |"));
verifyTrue(t,contains(text,"| Missing, failed or checksum-mismatched entries | 1 |"));
verifyTrue(t,contains(text,"| Cartesian conflicting revisions | 1 |"));
verifyFalse(t,contains(text,"![")); % Figures were explicitly disabled.
T=readtable(fullfile(ctx.runDir,'table5_rtn_pooled.csv'),'TextType','string');
verifyEqual(t,T.Component,["R";"T";"N"]);
verifyEqual(t,T.Mean_m,[0;4;6]);
verifyEqual(t,T.RMS_m,[3;4;sqrt(72)],'AbsTol',1e-10);
G=readtable(fullfile(ctx.runDir,'table6_ground_en_pooled.csv'),'TextType','string');
verifyEqual(t,G.Component,["East";"North"]);
verifyEqual(t,G.Sample,repmat("primary_1ms",2,1));
verifyEqual(t,G.Mean_m,[0;4]);
verifyEqual(t,G.RMS_m,[3;4],'AbsTol',1e-12);
allGround=readtable(fullfile(ctx.runDir,'table6_ground_en_all_groups.csv'),'TextType','string');
wide=allGround(allGround.Sample=="sensitivity_24h"&allGround.Grouping=="pooled"&allGround.Weighting=="pair",:);
verifyEqual(t,wide.Component,["East";"North"]);
verifyEqual(t,wide.Mean_m,[0;4]);
equal=allGround(allGround.Sample=="primary_1ms"&allGround.Grouping=="pooled"&allGround.Weighting=="equal_satellite",:);
verifyEqual(t,equal.Component,["East";"North"]);
verifyTrue(t,all(isnan(equal.Mean_m))&&all(isnan(equal.SD_m)));
verifyEqual(t,equal.RMS_m,[3;4],'AbsTol',1e-12);
end
function testGroundFiguresAreExportedAndLinked(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.cfg.reporting.figures=true;ctx.cfg.reporting.figureVisible="off";
ctx.cfg.reporting.perSatelliteFigures=false;
poc.reporting.export(ctx);
text=string(fileread(fullfile(ctx.runDir,'RUN_REPORT.md')));
for name=["ground_satellite_latlon","ground_daily_rms","ground_satellite_rms", ...
 "ground_ecdf","ground_en_scatter","ground_en_daily","ground_locations"]
 verifyTrue(t,isfile(fullfile(ctx.runDir,'figures',name+".png")));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'figures',name+".fig")));
 verifyTrue(t,contains(text,"figures/"+name+".png"));
end
ordered=["ground_satellite_latlon","ground_daily_rms", ...
 "ground_satellite_rms","ground_ecdf"];
positions=zeros(size(ordered));
for k=1:numel(ordered)
 found=strfind(char(text),char("figures/"+ordered(k)+".png"));
 verifyNotEmpty(t,found);
 if ~isempty(found),positions(k)=found(1);end
end
verifyTrue(t,all(diff(positions)>0));
end
function testSelectedSatelliteAndGroundRMSFigures(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.cfg.reporting.figureVisible="off";ctx.cfg.reporting.perSatelliteFigures=false;
ctx.cfg.reporting.groundPlotSatellite="Second satellite";
% A second satellite on the first date gives nontrivial daily and satellite RMS.
z=ctx.residuals(1,:);z.Satellite="Second satellite";z.PairID="fixture-3";
z.Ground_m=10;z.GroundEast_m=6;z.GroundNorth_m=8;
ctx.residuals=[ctx.residuals;z];
poc.reporting.figures(ctx);
f=openfig(fullfile(ctx.runDir,'figures','ground_satellite_latlon.fig'),'new','invisible');
fCleanup=onCleanup(@()close(f)); %#ok<NASGU>
verifyTrue(t,contains(string(f.Name),"Second satellite"));
points=findobj(f,'Type','scatter');
verifyNumElements(t,points,6); % Two products in each of three coordinate panels.
for k=1:numel(points),verifyEqual(t,numel(points(k).YData),1);end
g=openfig(fullfile(ctx.runDir,'figures','ground_daily_rms.fig'),'new','invisible');
gCleanup=onCleanup(@()close(g)); %#ok<NASGU>
points=findobj(g,'Type','scatter');
verifyNumElements(t,points,2);
hasRMS=false;hasCounts=false;
for k=1:numel(points)
 y=sort(double(points(k).YData(:)));
 hasRMS=hasRMS||(numel(y)==2&&all(abs(y-sort([5;sqrt(62.5)]))<1e-10));
 hasCounts=hasCounts||(numel(y)==2&&all(y==[1;2]));
end
verifyTrue(t,hasRMS);verifyTrue(t,hasCounts);
h=openfig(fullfile(ctx.runDir,'figures','ground_satellite_rms.fig'),'new','invisible');
hCleanup=onCleanup(@()close(h)); %#ok<NASGU>
bars=findobj(h,'Type','bar');verifyNumElements(t,bars,1);
verifyEqual(t,sort(double(bars.YData(:))),[5;10],'AbsTol',1e-10);
end
function testUnknownGroundSatelliteFailsClearlyBeforeExport(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.cfg.reporting.groundPlotSatellite="Not present";
verifyError(t,@()poc.reporting.figures(ctx),'poc:report:GroundSatellite');
verifyFalse(t,isfolder(fullfile(ctx.runDir,'figures')));
end
function testReportDoesNotInventResultsForEmptySample(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.primary=ctx.primary([],:);ctx.residuals=ctx.residuals([],:);
ctx.summaries=poc.stats.summaryRow(ctx.residuals,"primary_1ms","pooled","ALL","pair");
ctx.summaries=struct2table(ctx.summaries);ctx.intervals=table();
poc.reporting.report(ctx);
text=string(fileread(fullfile(ctx.runDir,'RUN_REPORT.md')));
verifyTrue(t,contains(text,"No primary orbital-consistency result"));
verifyTrue(t,contains(text,"| R | 0 | NaN | NaN | NaN |"));
verifyTrue(t,contains(text,"| East | 0 | NaN | NaN | NaN |"));
end
function testEmptySampleExportsHeaderOnlyDailyGroundSummary(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.primary=ctx.primary([],:);ctx.residuals=ctx.residuals([],:);
ctx.summaries=struct2table(poc.stats.summaryRow( ...
 ctx.residuals,"primary_1ms","pooled","ALL","pair"));
ctx.intervals=table();ctx.cfg.reporting.figures=false;
poc.reporting.export(ctx);
p=fullfile(ctx.runDir,'ground_daily_summary.csv');
verifyTrue(t,isfile(p));
lines=splitlines(strtrim(string(fileread(p))));
verifyEqual(t,numel(lines),1); % A header and no fabricated daily records.
verifyEqual(t,lines(1),"DateUTC,N,RMS_m,Median_m,Q95_m,Max_m");
end
function testAuditReportsCountsWithoutInventingOrbitalResults(t)
ctx=fixture();cleanup=onCleanup(@()rmdir(ctx.runDir,'s')); %#ok<NASGU>
ctx.cfg.profile="audit";
ctx=rmfield(ctx,{'evaluations','residuals','summaries','intervals'});
poc.reporting.auditReport(ctx);
text=string(fileread(fullfile(ctx.runDir,'RUN_REPORT.md')));
verifyTrue(t,contains(text,"No SGP4, RTN or ground result was computed"));
verifyTrue(t,contains(text,"| Selected primary daily pairs | 2 |"));
verifyTrue(t,contains(text,"| Parse-log entries | 1 |"));
verifyTrue(t,contains(text,"## Stage 04 -- SGP4 evaluation (not run)"));
verifyTrue(t,contains(text,"## Stage 07 -- Full result export (not run)"));
verifyFalse(t,contains(text,"| Signed mean"));
verifyFalse(t,contains(text,"!["));
end
function ctx=fixture()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
cfg=study_config("demo");cfg.reporting.figures=false;
ctx=struct('cfg',cfg,'runDir',tempname);mkdir(ctx.runDir);
z=poc.schema("metric");z.Satellite="Synthetic fixture";z.HWID="00a1";
z.IsPrimary=true;z.IsWide=true;z.Status="OK";
z.DateUTC=cfg.study.startUTC;z.PairID="fixture-1";
z.Radial_m=3;z.Transverse_m=4;z.Normal_m=12;
z.Position_m=13;z.Velocity_mps=0.02;z.Ground_m=5;
z.GroundEast_m=3;z.GroundNorth_m=4;z.LatC_deg=0;z.LonC_deg=0;
z.LatT_deg=0.000036;z.LonT_deg=0.000027;z.DeltaTime_s=0;
R=struct2table(z);z.DateUTC=z.DateUTC+caldays(1);z.PairID="fixture-2";
z.Radial_m=-3;z.Normal_m=0;z.Position_m=5;z.GroundEast_m=-3;
z.LatC_deg=1;z.LonC_deg=1;z.LatT_deg=1.000036;z.LonT_deg=0.999973;
R=[R;struct2table(z)];ctx.residuals=R;
ctx.primary=[poc.schema("pair",true);struct2table(poc.schema("pair"));struct2table(poc.schema("pair"))];
ctx.wide=ctx.primary;ctx.coverage=table();ctx.evaluations=poc.schema("evaluation",true);
ctx.primaryCandidates=ctx.primary;
ctx.manifest=[struct2table(poc.schema("manifest"));struct2table(poc.schema("manifest"));struct2table(poc.schema("manifest"))];
ctx.manifest.Status=["CACHED";"DOWNLOADED";"MISSING_OFFLINE"];
ctx.states=struct2table(poc.schema("state"));ctx.states.Revision=true;
ctx.tles=poc.schema("tle",true);
ctx.occurrences=table("fixture-state",'VariableNames',{'RecordID'});
ctx.parseLog=struct2table(poc.schema("log"));
p=poc.stats.summaryRow(R,"primary_1ms","pooled","ALL","pair");
s=poc.stats.summaryRow(R,"primary_1ms","satellite","Synthetic fixture","pair");
w=poc.stats.summaryRow(R,"sensitivity_24h","pooled","ALL","pair");
e=poc.stats.summaryRow(R,"primary_1ms","pooled","ALL","equal_satellite");
ctx.summaries=struct2table([p;s;w;e]);
B=poc.stats.bootstrap(R,cfg.study.startUTC,cfg.study.endUTC,7,cfg.bootstrap,1);
B.Grouping=repmat("pooled",height(B),1);B.Group=repmat("ALL",height(B),1);
ctx.intervals=B;
end
