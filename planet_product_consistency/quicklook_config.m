function opts = quicklook_config()
%QUICKLOOK_CONFIG Defaults for the PlanetScope acquisition inspector.
% The default calendar year is searched against locally available orbital
% records. Missing archive dates are reported, not silently invented.
startup_consistency();
cfg = study_config("audit");
opts = struct();
opts.StartUTC = datetime(2026,1,1,'TimeZone','UTC');
opts.EndUTC = datetime(2026,12,31,'TimeZone','UTC'); % Inclusive calendar date.
opts.TimeToleranceSeconds = 60; % Exploratory matching filter, not an accuracy claim.
opts.RawPath = cfg.paths.raw;
opts.RosterPath = cfg.paths.roster;
opts.ResultsPath = cfg.paths.runs;
opts.DownloadThumbnails = true;
opts.TimeoutSeconds = 60;
opts.PageSize = 250;
opts.WindowsPerRequest = 25;
opts.PauseSeconds = 0.25;
end
