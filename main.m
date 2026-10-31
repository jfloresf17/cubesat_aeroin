function result = main(opts)
%MAIN Run the PlanetScope orbit and footprint consistency study.
%   result = main() uses the default 2026 study configuration.
%   result = main(opts) accepts options from footprint_study_config.
%   Source data, credentials and results use the study folder's paths.
repoRoot = fileparts(mfilename('fullpath'));
studyRoot = fullfile(repoRoot,'planet_product_consistency');
addpath(studyRoot);
startup_consistency();
if nargin < 1 || isempty(opts)
    opts = footprint_study_config(2026);
end
result = run_footprint_study(opts);
fprintf('Study output: %s\n',result.RunDir);
end
