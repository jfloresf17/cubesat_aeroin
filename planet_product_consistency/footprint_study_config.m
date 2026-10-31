function opts=footprint_study_config(yearValue)
%FOOTPRINT_STUDY_CONFIG Configuration for a real-data acquisition study.
% Start from this structure; credentials belong in .env, never in opts.
if nargin<1,yearValue=2026;end
assert(isnumeric(yearValue)&&isscalar(yearValue)&&isfinite(yearValue)&& ...
 fix(yearValue)==yearValue&&yearValue>=1972,'poc:footprint:Year','Invalid UTC calendar year.');
startup_consistency(); c=study_config("pilot");
opts=struct;
opts.Year=yearValue;
opts.TimeToleranceSeconds=1;
opts.ReuseQuicklook=true; % Cached searches are snapshots, not live updates.
opts.QuicklookMAT=""; % Optional explicit compatible quicklook_results.mat.
opts.ResultsPath=string(c.paths.runs);
opts.RequireResearchQuality=true; % finalized, standard, ground controlled.
opts.MaxMatches=Inf; % Optional exploratory cap AFTER quality selection.
opts.Mode="snapshot";
% Planet's nominal delivered-scene dimensions are NOT instantaneous FOV.
% The axis assignment, 475 km height and rectangular frame are hypotheses.
opts.ReferenceAltitude_m=475000;
opts.SceneAlong_m=19600;
opts.SceneCross_m=32500;
opts.AlongPointing_deg=0;
opts.Roll_deg=0;
opts.CrossSigns=[-1 1]; % Equal hypotheses applied to both orbital products.
opts.EdgeSamples=8;
opts.BoundaryStep_m=250; % Uniform arc-length sampling for boundary distances.
opts.MaximumBoundaryPoints=50000;
% To enable swept mode, provide independently justified instantaneous FOV,
% duration and sampling. Do not sweep the full nominal scene dimensions.
opts.InstantaneousFOVAlong_deg=NaN;
opts.InstantaneousFOVCross_deg=NaN;
opts.SweepDuration_s=NaN;
opts.SweepSamples=11;
opts.AllowPredictedEOP=false;
end
