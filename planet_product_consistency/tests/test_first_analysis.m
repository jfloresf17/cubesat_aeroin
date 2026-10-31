function tests=test_first_analysis
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root);
t.TestData.root=startup_consistency();
end
function testStartupAddsPackageParent(t)
verifyEqual(t,string(which('poc.preflight')), ...
 string(fullfile(t.TestData.root,'utils','+poc','preflight.m')));
end
function testResearchRequiresExplicitStudyConfiguration(t)
verifyError(t,@()first_analysis_config("research"),'poc:first:Profile');
end
function testDefaultScopeIsSmallAndExplicit(t)
demo=first_analysis_config();
pilot=first_analysis_config("pilot");
verifyEqual(t,demo.profile,"demo");
verifyFalse(t,demo.download.enabled);
verifyEqual(t,days(demo.study.endUTC-demo.study.startUTC),30);
verifyEqual(t,days(pilot.study.endUTC-pilot.study.startUTC),2);
verifyFalse(t,pilot.bootstrap.enabled);
verifyFalse(t,pilot.reporting.perSatelliteFigures);
full=study_config("research");
verifyEqual(t,days(full.study.endUTC-full.study.startUTC),183);
verifyTrue(t,full.bootstrap.enabled);
verifyTrue(t,full.identity.requireHistoricalApproval);
end
function testExplicitUTCDateWindowAndSharedDefaults(t)
cfg=first_analysis_config("audit","2026-03-02","2026-03-08");
verifyEqual(t,cfg.study.startUTC,datetime(2026,3,2,'TimeZone','UTC'));
verifyEqual(t,cfg.study.endUTC,datetime(2026,3,8,'TimeZone','UTC'));
cfg=first_analysis_config("pilot","2026-03-04");
verifyEqual(t,cfg.study.endUTC,datetime(2026,3,6,'TimeZone','UTC'));
end
function testInvalidStarterDatesFailBeforeRunning(t)
verifyError(t,@()first_analysis_config("pilot","2026-03-03","2026-03-01"), ...
 'poc:first:Dates');
end
function testMissingAerospaceFailsBeforeCreatingRun(t)
assumeTrue(t,~ismember(exist('propagateOrbit','file'),[2 3 6]) || ...
 ~ismember(exist('tleread','file'),[2 3 6]), ...
 'Aerospace functions are available; missing-dependency case skipped.');
c=study_config("pilot");
c.paths.runs=tempname;
verifyError(t,@()poc.preflight(struct('cfg',c)),'poc:environment:Aerospace');
verifyFalse(t,isfolder(c.paths.runs));
end
