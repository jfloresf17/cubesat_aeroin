function ctx = preflight(ctx)
%PREFLIGHT Resolve paths and create a non-overwriting run directory.
c = ctx.cfg;
assert(c.study.endUTC >= c.study.startUTC,'poc:config:Dates','Invalid dates.');
assert(c.pairing.primaryTolerance_ns >= 0,'poc:config:Tolerance','Negative tolerance.');
assert(c.bootstrap.minValidReplicates <= c.bootstrap.replicates, ...
    'poc:config:Bootstrap','Minimum valid replicates exceeds total.');
assert(isfile(c.paths.roster),'poc:identity:MissingRoster', ...
    'Missing roster: %s',c.paths.roster);
if ~usejava('jvm')
    error('poc:environment:JVM','Java is required for SHA-256 input provenance.');
end
% Check evaluation requirements before downloading any orbital archives.
if c.profile=="pilot" || c.profile=="research"
    poc.frames.checkPolicy(c);
    if ismember(c.frames.earthMode,["iers_file","zero_eop_pilot"])
        assert(exist('dcmeci2ecef','file')==2, ...
            'poc:environment:Aerospace','Aerospace Toolbox dcmeci2ecef is required.');
    end
    if c.metrics.geodesic=="matlab"
        assert(exist('wgs84Ellipsoid','file')==2 && exist('distance','file')==2, ...
            'poc:environment:Mapping', ...
            'Mapping Toolbox is required for the MATLAB geodesic backend.');
    end
end
if ~isfolder(c.paths.runs), mkdir(c.paths.runs); end
stamp = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
ctx.runDir = fullfile(c.paths.runs,stamp+"_"+c.profile);
assert(~isfolder(ctx.runDir),'poc:io:RunExists','Run directory already exists.');
mkdir(ctx.runDir);
ctx.leaps = poc.time.readLeaps(c.paths.leaps,c.time.validThroughUTC);
if c.study.endUTC+caldays(1) > ctx.leaps.validThroughUTC
    error('poc:time:LeapValidity','Review leap table validity before extending dates.');
end
runManifest.protocol = c.protocolVersion;
runManifest.profile = c.profile;
runManifest.matlabVersion = string(version);
runManifest.toolboxes = ver;
runManifest.createdUTC = stamp;
runManifest.sourceHash = poc.io.sourceHash(c.projectRoot);
runManifest.config = c;
runManifest.runtimeTestStatus = "This execution is separate from authoring-time static checks.";
runManifest.repositoryIntegration = "Additive module; upstream repository was inaccessible during authoring.";
runManifest.sgp4Path = string(which('propagateOrbit'));
runManifest.tlereadPath = string(which('tleread'));
runManifest.geodesicPath = string(which('distance'));
runManifest.leapTableSHA256 = poc.io.hashFile(c.paths.leaps);
runManifest.rosterSHA256 = poc.io.hashFile(c.paths.roster);
poc.io.writeText(fullfile(ctx.runDir,'run_manifest.json'), ...
    jsonencode(runManifest,'PrettyPrint',true));
config = c; %#ok<NASGU>
save(fullfile(ctx.runDir,'configuration.mat'),'config');
if c.profile == "demo"
    fprintf('SYNTHETIC DEMO: no Planet observations and no SGP4 evaluation.\n');
elseif c.profile == "pilot"
    warning('poc:Pilot','Pilot output is not research-verified. Review frame and identity flags.');
end
end
