function cfg = study_config(profile)
%STUDY_CONFIG Versioned implementation of SmallSat PDF Sections 3.1--3.4.
% Settings beyond the supplied manuscript are labelled in docs/DECISIONS.md.
if nargin == 0, profile = "audit"; end
profile = string(profile);
assert(ismember(profile,["audit","pilot","research","demo"]), ...
    'poc:config:Profile','Choose audit, pilot, research or demo.');
root = fileparts(fileparts(mfilename('fullpath')));
cfg.projectRoot = root;
cfg.profile = profile;
cfg.protocolVersion = "SmallSatPDF-2026-v1";
cfg.study.startUTC = datetime(2026,3,1,'TimeZone','UTC');
cfg.study.endUTC = datetime(2026,8,31,'TimeZone','UTC');
cfg.study.targetSatellites = 36;
cfg.study.flock = "Flock 4H";
flatRaw = fullfile(root,'data','raw');
nestedRaw = fullfile(root,'data','planet_ephemerides','raw','daily');
% Prefer the existing flat cache. When absent, recognize the existing dated
% YYYY/MM archive tree without moving or rewriting its source payloads.
if ~isfolder(flatRaw) && isfolder(nestedRaw)
    cfg.paths.raw = nestedRaw;
else
    cfg.paths.raw = flatRaw;
end
cfg.paths.runs = fullfile(root,'results');
cfg.paths.roster = fullfile(root,'config','roster.csv');
cfg.paths.leaps = fullfile(root,'config','leap_seconds.csv');
cfg.paths.eop = fullfile(root,'data','auxiliary','finals2000A.all');
cfg.download.enabled = true;
cfg.download.baseURL = "https://ephemerides.planet-labs.com/";
cfg.download.guardDays = 1;
cfg.download.retries = 3;
cfg.download.timeout_s = 60;
cfg.download.pause_s = 0.15;
cfg.download.eopURL = "https://maia.usno.navy.mil/ser7/finals2000A.all";
cfg.download.snapshotIdentity = true;
cfg.download.fetchEOP = profile == "pilot" || profile == "research";
cfg.identity.requireHistoricalApproval = profile == "research";
cfg.identity.requireHeaderHWID = true;
cfg.pairing.primaryTolerance_ns = int64(1000000); % 1 ms, not 1 second.
cfg.pairing.sensitivityTolerance_ns = int64(86400)*int64(1000000000);
cfg.pairing.excludeConflictingRevisions = true;
% USNO announced no leap second at the end of December 2026. The extra day
% supports year-boundary matching; review the official announcement before
% extending this horizon. https://maia.usno.navy.mil/products/leap-second
cfg.time.validThroughUTC = datetime(2027,1,2,'TimeZone','UTC');
cfg.time.maxDatetimeRoundTrip_ns = int64(10000); % 10 us implementation gate.
cfg.time.maxTlereadEpochDifference_ns = int64(100000); % 0.1 ms gate.
cfg.sgp4.backend = "matlab";
cfg.sgp4.verificationApproved = false;
cfg.sgp4.verificationEvidence = "";
cfg.frames.cartesianMode = "unresolved";
% Allowed: identity_assumption | fixed_rotation | custom. Neither name proves
% Planet's underspecified J2000 convention. Record the adopted interpretation.
cfg.frames.rotationToICRF = eye(3);
cfg.frames.customFunction = ""; % Function name: [rI,vI] = f(utc,r,v).
cfg.frames.policyApproved = false;
cfg.frames.evidence = "";
cfg.frames.earthMode = "iers_file"; % No automatic zero-EOP fallback.
cfg.frames.allowPredictedEOP = false;
cfg.frames.customEarthFunction = ""; % C = f(utc,deltaAT), ICRF -> ITRF.
cfg.metrics.geodesic = "matlab"; % distance(...,wgs84Ellipsoid('m'),'degrees').
cfg.metrics.rtnOrthogonalityTolerance = 1e-12;
cfg.metrics.normRelativeTolerance = 1e-11;
cfg.bootstrap.enabled = true;
cfg.bootstrap.blockDays = [7 3 14];
cfg.bootstrap.replicates = 2000;
cfg.bootstrap.minValidReplicates = 1900;
cfg.bootstrap.seed = 20261030;
cfg.bootstrap.groupings = ["pooled","satellite","month"];
% Explicit support rule added because supplementary validity rules were not supplied.
cfg.bootstrap.minDistinctDates = 14;
cfg.bootstrap.minWindowBlocks = 2;
cfg.reporting.figures = true;
cfg.reporting.perSatelliteFigures = true;
cfg.reporting.figureVisible = "off";
cfg.reporting.groundPlotSatellite = ""; % Empty: most represented satellite, lexical tie.
cfg.reporting.archiveDateConventionApproved = false;
if profile == "pilot"
    cfg.frames.cartesianMode = "identity_assumption";
    cfg.frames.evidence = "PILOT ONLY: J2000-labelled Cartesian axes treated as ICRF.";
end
if profile == "demo"
    cfg.study.startUTC = datetime(2026,3,1,'TimeZone','UTC');
    cfg.study.endUTC = datetime(2026,3,31,'TimeZone','UTC');
    cfg.study.targetSatellites = 2;
    cfg.study.flock = "SYNTHETIC";
    cfg.paths.raw = fullfile(root,'data','demo_raw');
    cfg.paths.roster = fullfile(root,'data','demo_raw','roster.csv');
    cfg.download.enabled = false;
    cfg.download.snapshotIdentity = false;
    cfg.sgp4.backend = "synthetic_fixture";
    cfg.frames.cartesianMode = "identity_assumption";
    cfg.frames.earthMode = "synthetic_identity";
    cfg.frames.evidence = "SYNTHETIC TEST COORDINATES; no real orbital evaluation.";
    cfg.metrics.geodesic = "vincenty";
    cfg.bootstrap.replicates = 200;
    cfg.bootstrap.minValidReplicates = 190;
    cfg.bootstrap.groupings = "pooled";
end
end
