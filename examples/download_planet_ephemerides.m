%% Download and archive Planet ephemerides for the consistency study
% Run this file from any working directory. The first call uses bundled data
% only; change the configuration below for an online research archive.
% SPDX-License-Identifier: MIT
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'utilities'));

%% Configuration shared by the main research pipeline
startDate = "2026-09-01";
endDate = "2026-09-03";
flocks = "4q";
satelliteIDs = ["24bd","24d1"]; % Planet HWIDs, not NORAD/CATIDs
outputDirectory = fullfile(projectRoot,'data','planet_ephemerides');
offline = true; % Set false to retrieve new dates from Planet.

%% One public entry point; raw files are shared across all selected satellites
archive = downloadPlanetEphemerides(startDate,endDate, ...
    'Flock',flocks,'ID',satelliteIDs, ...
    'OutputDirectory',outputDirectory,'CacheOnly',offline,'Strict',true);
disp(archive.Groups);
disp(archive.Availability);
fprintf('Saved MATLAB dataset: %s\n',fullfile(archive.RunDirectory,'archive.mat'));

%% Inputs to subsequent common-epoch/common-frame processing
% These tables retain native epochs, SI units, original TLE lines and B*.
% TLE output from SGP4 is TEME; Planet labels its Cartesian frame "J2000".
% The ingestion stage does not equate these frames or subtract their states.
tleRecords = archive.TLE;
cartesianRecords = archive.States;

% This is the signed native epoch separation, not a consistency error:
% NativeEpochSeparation_s = TLE epoch - Cartesian epoch (SI seconds).
nativeEpochSeparation_s = archive.Availability.NativeEpochSeparation_s;

%% Other selectors (uncomment to run)
% A full flock, using live downloads:
% archive = downloadPlanetEphemerides("2026-04-01","2026-09-30", ...
%     'Flock',"4q",'OutputDirectory',outputDirectory);
%
% Several flocks; all their published satellite records:
% archive = downloadPlanetEphemerides(startDate,endDate, ...
%     'Flock',["4q","4be"],'OutputDirectory',outputDirectory);
%
% Explicit catalog-number filter (flagged mapping retained in output):
% archive = downloadPlanetEphemerides(startDate,endDate, ...
%     'ID',58320,'IDType','catid','OutputDirectory',outputDirectory);
