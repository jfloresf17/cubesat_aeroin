function writeResults(result,windows,writeSearchTables)
%WRITERESULTS Persist the completed search and the current preview status.
% The first call writes all tables before preview downloads begin. A second
% call updates the preview status, MATLAB result and reports after downloads.
runDir=result.RunDir;
if writeSearchTables
 poc.io.writeTable(fullfile(runDir,'matches.csv'),result.Matches);
 poc.io.writeTable(fullfile(runDir,'candidate_scenes.csv'),result.Scenes);
 poc.io.writeTable(fullfile(runDir,'scene_status.csv'),result.SceneStatus);
 poc.io.writeTable(fullfile(runDir,'archive_inventory.csv'),result.ArchiveInventory.Files);
 poc.io.writeTable(fullfile(runDir,'archive_coverage.csv'),result.ArchiveInventory.Daily);
 poc.io.writeTable(fullfile(runDir,'parse_log.csv'),result.ArchiveInventory.ParseLog);
end
poc.io.writeTable(fullfile(runDir,'preview_status.csv'), ...
 result.Previews(:,{'SceneID','ThumbnailURL','ThumbnailLocalPath','ThumbnailStatus'}));
% Write to a separate file before replacing the prior checkpoint. If the
% update fails, the original result remains available.
checkpoint=fullfile(runDir,'quicklook_results_pending.mat');
save(checkpoint,'result','-v7.3');
[ok,msg]=movefile(checkpoint,fullfile(runDir,'quicklook_results.mat'),'f');
assert(ok,'poc:quicklook:Output','Could not save MATLAB results: %s',msg);
poc.quicklook.writeReport(runDir,result.Options,result.ArchiveInventory, ...
 result.SearchStats,windows,result.Matches,result.SceneStatus,result.Previews);
end
