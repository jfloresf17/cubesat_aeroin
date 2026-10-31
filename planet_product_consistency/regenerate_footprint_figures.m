function regenerate_footprint_figures(runDir)
%REGENERATE_FOOTPRINT_FIGURES Replot an existing real-data MATLAB result.
% regenerate_footprint_figures("results/footprint_YYYYMMDD_HHMMSS_SSS")
% uses the archived result; it does not re-query Planet or repropagate orbits.
startup_consistency();
runDir=string(runDir);
assert(isscalar(runDir)&&strlength(runDir)>0&&isfolder(runDir), ...
 'poc:footprint:ResultsPath','Provide the existing study output directory.');
resultPath=fullfile(runDir,'footprint_results.mat');
assert(isfile(resultPath),'poc:footprint:ResultsPath', ...
 'No footprint_results.mat exists in %s.',runDir);
s=load(resultPath,'result');
assert(isfield(s,'result')&&isstruct(s.result)&&isscalar(s.result), ...
 'poc:footprint:Results','The MAT file does not contain a valid result.');
s.result.RunDir=runDir;
poc.footprint.writeFigures(s.result);
fprintf('Figures updated from saved results: %s\n',runDir);
end
