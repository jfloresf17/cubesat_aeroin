function tests=test_footprint_integration
% Optional integration regression against the existing real-data cache.
% A clean checkout skips this test; no credentials or fabricated data needed.
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
t.TestData.root=root;
assumeTrue(t,strcmp(getenv('POC_REAL_DATA_TESTS'),'1'), ...
 'Set POC_REAL_DATA_TESTS=1 to run slow real-input integration tests.');
cache=fullfile(root,'data','planet_psscene','catalogue_2026.mat');
assumeTrue(t,isfile(cache),'The optional preserved catalogue input is unavailable.');
cfg=study_config("audit");
assumeTrue(t,isfolder(cfg.paths.raw)&&isfile(cfg.paths.roster), ...
 'The optional native ephemeris inputs are unavailable.');
temporary=tempname;mkdir(temporary);t.TestData.temporary=temporary;
% Rebuild once from input-only catalogue and native archives. The resulting
% quicklook fixture remains in a temporary directory, never in the repo.
opts=footprint_study_config(2026);opts.ResultsPath=string(temporary);opts.MaxMatches=0;
r=run_footprint_study(opts);
assumeTrue(t,height(r.MatchingInventory)>0,'No real matches in the optional inputs.');
q=quicklook_config();q.TimeToleranceSeconds=opts.TimeToleranceSeconds;q.DownloadThumbnails=false;
result=struct('Options',q,'Matches',r.MatchingInventory); %#ok<NASGU>
cache=fullfile(temporary,'integration_quicklook.mat');save(cache,'result','-v7.3');
t.TestData.quicklook=cache;
end

function teardownOnce(t)
if isfield(t.TestData,'temporary')&&isfolder(t.TestData.temporary)
 rmdir(t.TestData.temporary,'s');
end
end

function testCachedRealAcquisition(t)
root=t.TestData.root;
cache=t.TestData.quicklook;
eop=fullfile(root,'data','auxiliary','finals2000A.all');
assumeTrue(t,isfile(cache)&&isfile(eop), ...
 'The optional cached 2026 quicklook snapshot and IERS EOP file are unavailable.');
assumeTrue(t,ismember(exist('propagateOrbit','file'),[2 3 6])&& ...
 ismember(exist('wgs84Ellipsoid','file'),[2 3 6]), ...
 'Aerospace and Mapping Toolboxes are required.');
output=tempname;mkdir(output);cleanup=onCleanup(@()rmdir(output,'s')); %#ok<NASGU>
opts=footprint_study_config(2026);
opts.QuicklookMAT=string(cache);opts.ResultsPath=string(output);opts.MaxMatches=1;
r=run_footprint_study(opts);
verifyEqual(t,height(r.AnalysisStatus),1);
verifyEqual(t,r.AnalysisStatus.Status,"OK");
verifyEqual(t,height(r.OrbitalMetrics),1);
verifyEqual(t,height(r.FootprintMetrics),6); % two signs, three pairings
verifyEqual(t,numel(r.Geometries),2);
verifyTrue(t,isfile(fullfile(r.RunDir,'RUN_REPORT.md')));
verifyTrue(t,isfile(fullfile(r.RunDir,'footprint_example.png')));
verifyTrue(t,isfile(fullfile(r.RunDir,'acquisition_timing.png')));
verifyTrue(t,isfile(fullfile(r.RunDir,'rtn_geodesic_by_time.png')));
verifyTrue(t,isfile(fullfile(r.RunDir,'subsatellite_pairs.png')));
verifyTrue(t,isfile(fullfile(r.RunDir,'paired_footprint_metrics.png')));
% A footprint failure must not suppress valid orbital plots.
orbitOnly=r;orbitOnly.Geometries={};orbitOnly.FootprintMetrics=table();
orbitOnly.RunDir=fullfile(string(output),'orbit_only');mkdir(orbitOnly.RunDir);
poc.footprint.writeFigures(orbitOnly);
verifyTrue(t,isfile(fullfile(orbitOnly.RunDir,'rtn_geodesic_by_time.png')));
verifyTrue(t,isfile(fullfile(orbitOnly.RunDir,'subsatellite_pairs.png')));
verifyFalse(t,isfile(fullfile(orbitOnly.RunDir,'footprint_example.png')));
end

function testCachedRealSweptScenario(t)
% FOV and duration are test inputs, not a Planet sensor calibration.
root=t.TestData.root;
cache=t.TestData.quicklook;
eop=fullfile(root,'data','auxiliary','finals2000A.all');
assumeTrue(t,isfile(cache)&&isfile(eop),'Cached research inputs are unavailable.');
assumeTrue(t,ismember(exist('propagateOrbit','file'),[2 3 6])&& ...
 ismember(exist('wgs84Ellipsoid','file'),[2 3 6]),'Required toolboxes are unavailable.');
output=tempname;mkdir(output);cleanup=onCleanup(@()rmdir(output,'s')); %#ok<NASGU>
opts=footprint_study_config(2026);opts.QuicklookMAT=string(cache);
opts.ResultsPath=string(output);opts.MaxMatches=1;opts.Mode="swept";
opts.InstantaneousFOVAlong_deg=0.3;opts.InstantaneousFOVCross_deg=3.9;
opts.SweepDuration_s=2;opts.SweepSamples=5;
r=run_footprint_study(opts);
verifyEqual(t,r.AnalysisStatus.Status,"OK");
verifyEqual(t,height(r.FootprintMetrics),6);
verifyEqual(t,r.Geometries{1}.CartesianDiagnostic.TemporalSampling,"DISCRETE_UNION");
end
