function tests=test_demo_pipeline
 tests=functiontests(localfunctions);
end
function testFullSyntheticRun(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=first_analysis_config("demo");tmp=tempname;mkdir(tmp);
 cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 c.paths.raw=fullfile(tmp,'raw');c.paths.roster=fullfile(c.paths.raw,'roster.csv');c.paths.runs=fullfile(tmp,'runs');
 c.bootstrap.replicates=20;c.bootstrap.minValidReplicates=19;
 c.reporting.figures=false;
 poc.testing.makeDemo(c);
 ctx=run_study(c);
 verifyEqual(t,height(ctx.primary),57);verifyEqual(t,height(ctx.wide),58);
 verifyEqual(t,sum(ctx.residuals.Status=="OK"),58);
 verifyEqual(t,sum(ctx.residuals.IsAsyncOnly),1);
 successful=ctx.residuals(ctx.residuals.IsPrimary & ctx.residuals.Status=="OK",:);
 verifyTrue(t,all(isfinite(successful.GroundEast_m)));
 verifyTrue(t,all(isfinite(successful.GroundNorth_m)));
 verifyEqual(t,hypot(successful.GroundEast_m,successful.GroundNorth_m), ...
  successful.Ground_m,'AbsTol',1e-7);
 groundSummary=readtable(fullfile(ctx.runDir,'table6_ground_en_pooled.csv'), ...
  'TextType','string');
 verifyEqual(t,height(groundSummary),2);
 verifyTrue(t,all(groundSummary.N==57));
 daily=readtable(fullfile(ctx.runDir,'ground_daily_summary.csv'));
 satellite=readtable(fullfile(ctx.runDir,'ground_satellite_summary.csv'));
 verifyEqual(t,sum(daily.N),57);
 verifyEqual(t,sum(satellite.N),57);
 verifyTrue(t,all(daily.RMS_m>=0));
 verifyTrue(t,all(satellite.N>=0));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'RUN_COMPLETE.txt')));
 verifyEqual(t,ctx.latestReportStatus,"PUBLISHED");
 verifyTrue(t,isfile(ctx.latestReportPath));
 latest=string(fileread(ctx.latestReportPath));
 verifyTrue(t,contains(latest,"### Signed east/north subsatellite displacement"));
 [~,runName]=fileparts(ctx.runDir);
 verifyTrue(t,contains(latest,string(runName)+"/table6_ground_en_pooled.csv"));
 verifyTrue(t,contains(latest,"Profile: **demo**"));
 verifyEqual(t,ctx.stageLog.Stage,(0:7)');
 verifyEqual(t,ctx.stageLog.Status,repmat("COMPLETE",8,1));
 verifyTrue(t,all(isfile(ctx.stageLog.Checkpoint)));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'stage_log.csv')));
 saved=load(fullfile(ctx.runDir,'results.mat'),'results');
 verifyEqual(t,saved.results.stageLog.Status,ctx.stageLog.Status);
 verifyEqual(t,saved.results.latestReportPath,string(fullfile(ctx.runDir,'RUN_REPORT.md')));
 pub=load(fullfile(ctx.runDir,'publication_status.mat'),'publicationStatus');
 verifyEqual(t,pub.publicationStatus.Status,"PUBLISHED");
 verifyEqual(t,pub.publicationStatus.LatestReportPath,ctx.latestReportPath);
end
function testStageFailurePreservesDiagnosticLedger(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=first_analysis_config("demo");tmp=tempname;mkdir(tmp);
 cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 c.paths.raw=fullfile(tmp,'raw');c.paths.roster=fullfile(c.paths.raw,'roster.csv');c.paths.runs=fullfile(tmp,'runs');
 poc.testing.makeDemo(c);mkdir(c.paths.runs);
 previousLatest=fullfile(c.paths.runs,'RUN_REPORT.md');
 poc.io.writeText(previousLatest,"Previously completed report");
 roster=readtable(c.paths.roster,'TextType','string');
 roster.Flock(:)="WRONG_COHORT";writetable(roster,c.paths.roster);
 verifyError(t,@()run_study(c),'poc:identity:Flock');
 logs=dir(fullfile(c.paths.runs,'*','stage_log.csv'));
 verifyNumElements(t,logs,1);
 log=readtable(fullfile(logs(1).folder,logs(1).name),'TextType','string');
 verifyEqual(t,log.Status(1:3),["COMPLETE";"COMPLETE";"FAILED"]);
 verifyEqual(t,log.Status(4:end),repmat("PENDING",5,1));
 verifyTrue(t,contains(log.Message(3),"poc:identity:Flock"));
 verifyTrue(t,isfile(fullfile(logs(1).folder,'RUN_FAILED.txt')));
 verifyTrue(t,isfile(fullfile(logs(1).folder,'failed_context.mat')));
 verifyFalse(t,isfile(fullfile(logs(1).folder,'RUN_COMPLETE.txt')));
 verifyEqual(t,string(fileread(previousLatest)),"Previously completed report");
end
function testAuditStopsAfterPairingAndWritesReport(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=first_analysis_config("demo","2026-03-01","2026-03-03");tmp=tempname;mkdir(tmp);
 cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 c.paths.raw=fullfile(tmp,'raw');c.paths.roster=fullfile(c.paths.raw,'roster.csv');c.paths.runs=fullfile(tmp,'runs');
 poc.testing.makeDemo(c);c.profile="audit";
 ctx=run_study(c);
 verifyEqual(t,ctx.stageLog.Stage,(0:3)');
 verifyEqual(t,ctx.stageLog.Status,repmat("COMPLETE",4,1));
 verifyTrue(t,all(isfile(ctx.stageLog.Checkpoint)));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'RUN_REPORT.md')));
 verifyFalse(t,isfield(ctx,'evaluations'));
 verifyFalse(t,isfile(fullfile(ctx.runDir,'paired_residuals.csv')));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'RUN_COMPLETE.txt')));
 verifyTrue(t,isfile(ctx.latestReportPath));
 latest=string(fileread(ctx.latestReportPath));
 verifyTrue(t,contains(latest,"MATLAB AUDIT: stages 00--03 only"));
 verifyTrue(t,contains(latest,"No SGP4, RTN or ground result was computed"));
end
function testLatestReportRebasesLocalLinksAndKeepsOriginal(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'utils'));
 tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 ctx=publicationFixture(tmp,"run one");
 body=strjoin(["# Original run report"; ...
  "[Table](table6_ground_en_pooled.csv)"; ...
  "![Ground scatter](figures/ground_en_scatter.png)"; ...
  "[Parent](../shared.csv#section)"; ...
  "[Spaced](<figures/some plot.png> ""plot"")"; ...
  "[Anchor](#ground) [Web](https://example.org/file)"; ...
  "[Mail](mailto:test@example.org) [Absolute](/shared/file.csv)"; ...
  "Inline `[example](untouched.csv)` remains code."; ...
  "```matlab";"[example](also-untouched.csv)";"```"],newline);
 poc.io.writeText(fullfile(ctx.runDir,'RUN_REPORT.md'),body);
 latestPath=poc.reporting.publishLatest(ctx);
 latest=string(fileread(latestPath));
 verifyEqual(t,latestPath,string(fullfile(tmp,'RUN_REPORT.md')));
 verifyTrue(t,startsWith(latest,"<!-- Generated by poc.reporting.publishLatest -->"));
 verifyTrue(t,contains(latest,"[Open the original run report](run%20one/RUN_REPORT.md)"));
 verifyTrue(t,contains(latest,"[Table](run%20one/table6_ground_en_pooled.csv)"));
 verifyTrue(t,contains(latest,"![Ground scatter](run%20one/figures/ground_en_scatter.png)"));
 verifyTrue(t,contains(latest,"[Parent](run%20one/../shared.csv#section)"));
 verifyTrue(t,contains(latest,"[Spaced](<run%20one/figures/some plot.png> ""plot"")"));
 verifyTrue(t,contains(latest,"[Anchor](#ground) [Web](https://example.org/file)"));
 verifyTrue(t,contains(latest,"[Mail](mailto:test@example.org) [Absolute](/shared/file.csv)"));
 verifyTrue(t,contains(latest,"`[example](untouched.csv)`"));
 verifyTrue(t,contains(latest,"[example](also-untouched.csv)"));
 verifyEqual(t,string(fileread(fullfile(ctx.runDir,'RUN_REPORT.md'))),body);
end
function testLatestReportAdvancesOnlyForNonemptyCompletedRuns(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'utils'));
 tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 a=publicationFixture(tmp,"run-a");
 poc.io.writeText(fullfile(a.runDir,'RUN_REPORT.md'),"First complete result");
 latestPath=poc.reporting.publishLatest(a);
 b=publicationFixture(tmp,"run-b");
 poc.io.writeText(fullfile(b.runDir,'RUN_REPORT.md'),"Second complete result");
 poc.reporting.publishLatest(b);
 latest=string(fileread(latestPath));
 verifyTrue(t,contains(latest,"Second complete result"));
 verifyFalse(t,contains(latest,"First complete result"));
 verifyTrue(t,contains(latest,"run-b/RUN_REPORT.md"));
 c=publicationFixture(tmp,"run-c");
 poc.io.writeText(fullfile(c.runDir,'RUN_REPORT.md'),"   ");
 verifyError(t,@()poc.reporting.publishLatest(c),'poc:report:LatestEmpty');
 verifyEqual(t,string(fileread(latestPath)),latest);
 poc.io.writeText(fullfile(c.runDir,'RUN_REPORT.md'),"Incomplete result");
 c.stageLog.Status(1)="FAILED";
 verifyError(t,@()poc.reporting.publishLatest(c),'poc:report:LatestIncomplete');
 verifyEqual(t,string(fileread(latestPath)),latest);
 d=publicationFixture(tmp,"run-d");
 verifyError(t,@()poc.reporting.publishLatest(d),'poc:report:LatestMissing');
 verifyEqual(t,string(fileread(latestPath)),latest);
 poc.io.writeText(fullfile(d.runDir,'RUN_REPORT.md'), ...
  "No primary orbital-consistency result is available for this run.");
 poc.reporting.publishLatest(d);
 latest=string(fileread(latestPath));
 verifyTrue(t,contains(latest,"No primary orbital-consistency result"));
 verifyFalse(t,contains(latest,"Second complete result"));
end
function testUnownedLatestReportIsNotOverwritten(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'utils'));
 tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 ctx=publicationFixture(tmp,"run-a");
 poc.io.writeText(fullfile(ctx.runDir,'RUN_REPORT.md'),"New analysis result");
 latestPath=fullfile(tmp,'RUN_REPORT.md');
 poc.io.writeText(latestPath,"Handwritten report belongs to the user.");
 verifyError(t,@()poc.reporting.publishLatest(ctx),'poc:report:LatestUnowned');
 verifyEqual(t,string(fileread(latestPath)),"Handwritten report belongs to the user.");
end
function testReadOnlyOwnedReportIsNotOverwritten(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'utils'));
 tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()cleanupReadOnlyFixture(tmp)); %#ok<NASGU>
 first=publicationFixture(tmp,"run-a");
 poc.io.writeText(fullfile(first.runDir,'RUN_REPORT.md'),"First result");
 latestPath=poc.reporting.publishLatest(first);
 latest=string(fileread(latestPath));
 [changed,~]=fileattrib(latestPath,'-w');
 [readOK,attributes]=fileattrib(latestPath);
 assumeTrue(t,changed&&readOK&&isfield(attributes,'UserWrite') ...
  &&isfinite(attributes.UserWrite)&&attributes.UserWrite==0, ...
  'This runtime cannot set and report a read-only file attribute.');
 second=publicationFixture(tmp,"run-b");
 poc.io.writeText(fullfile(second.runDir,'RUN_REPORT.md'),"Second result");
 verifyError(t,@()poc.reporting.publishLatest(second),'poc:report:LatestReadOnly');
 verifyEqual(t,string(fileread(latestPath)),latest);
end
function testUnownedLatestLeavesCompletedAuditAvailable(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=first_analysis_config("demo","2026-03-01","2026-03-03");tmp=tempname;mkdir(tmp);
 cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
 c.paths.raw=fullfile(tmp,'raw');c.paths.roster=fullfile(c.paths.raw,'roster.csv');c.paths.runs=fullfile(tmp,'runs');
 poc.testing.makeDemo(c);c.profile="audit";mkdir(c.paths.runs);
 userReport=fullfile(c.paths.runs,'RUN_REPORT.md');
 poc.io.writeText(userReport,"Handwritten report belongs to the user.");
 warningState=warning('off','poc:report:LatestPublishFailed');
 warningCleanup=onCleanup(@()warning(warningState)); %#ok<NASGU>
 ctx=run_study(c);
 verifyEqual(t,ctx.latestReportStatus,"FAILED");
 verifyEqual(t,ctx.latestReportPath,string(fullfile(ctx.runDir,'RUN_REPORT.md')));
 verifyTrue(t,contains(ctx.latestReportMessage,"poc:report:LatestUnowned"));
 verifyTrue(t,isfile(ctx.latestReportPath));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'RUN_COMPLETE.txt')));
 verifyTrue(t,isfile(fullfile(ctx.runDir,'REPORT_PUBLISH_FAILED.txt')));
 verifyFalse(t,isfile(fullfile(ctx.runDir,'RUN_FAILED.txt')));
 verifyEqual(t,string(fileread(userReport)),"Handwritten report belongs to the user.");
 pub=load(fullfile(ctx.runDir,'publication_status.mat'),'publicationStatus');
 verifyEqual(t,pub.publicationStatus.Status,"FAILED");
 verifyEqual(t,pub.publicationStatus.LatestReportPath,ctx.latestReportPath);
end
function ctx=publicationFixture(root,runName)
 ctx.cfg=study_config("demo");ctx.cfg.paths.runs=string(root);
 ctx.runDir=fullfile(root,runName);mkdir(ctx.runDir);
 ctx.stageLog=table("COMPLETE",'VariableNames',{'Status'});
 poc.io.writeText(fullfile(ctx.runDir,'RUN_COMPLETE.txt'),"Complete");
end
function cleanupReadOnlyFixture(root)
latest=fullfile(root,'RUN_REPORT.md');
if isfile(latest),fileattrib(latest,'+w');end
if isfolder(root),rmdir(root,'s');end
end
