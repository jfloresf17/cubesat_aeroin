%% Planet orbital-product consistency: reproducible data-ingestion stage
% This repository currently implements data ingestion. Common-frame/epoch
% alignment and consistency metrics belong to subsequent research stages.
% SPDX-License-Identifier: MIT
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot,'utilities'));

%% Experiment configuration
% Target: 36 Flock 4H satellites across 184 inclusive UTC archive dates.
study.startDate = "2026-03-01";
study.endDate = "2026-08-31";
study.flocks = "4h";
study.ids = strings(0,1); % No ID restriction: select the entire flock.
study.dataDirectory = fullfile(projectRoot,'data','planet_ephemerides');

%% Stage 1: retrieve published products and preserve their native information
data = downloadPlanetEphemerides(study.startDate,study.endDate, ...
    'Flock',study.flocks,'ID',study.ids, ...
    'OutputDirectory',study.dataDirectory,'Strict',true);
disp(data.Groups);
disp(data.Summary);
fprintf('Research input archive: %s\n',fullfile(data.RunDirectory,'archive.mat'));

% Downstream code can consume data.TLE, data.States and data.Availability.
% Retain the TLE lines/B*; do not use a two-body conversion as an SGP4 input.
