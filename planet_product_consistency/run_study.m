function ctx = run_study(cfg)
%RUN_STUDY Execute the numbered scripts inside a private function workspace.
% Each script receives/updates ctx; all algorithms live under utils/+poc.
% Script snapshots are saved, but a new run never reuses stale stage outputs.
% stage_log.csv records status, elapsed time and checkpoint path per stage.
if nargin == 0
    startup_consistency();
    cfg = study_config("audit");
end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
ctx = struct('cfg',cfg);
ctx.latestReportPath="";ctx.latestReportStatus="PENDING";ctx.latestReportMessage="";
stages = ["stage00_preflight.m","stage01_acquire.m", ...
    "stage02_preprocess.m","stage03_pair.m"];
names = ["Preflight","Acquire archives","Preprocess records","Pair products"];
if cfg.profile ~= "audit"
    stages = [stages,"stage04_evaluate_sgp4.m","stage05_metrics.m", ...
        "stage06_summarize.m","stage07_export.m"];
    names = [names,"Evaluate SGP4","Compute metrics","Summarize","Export report"];
end
count = numel(stages);
ctx.stageLog = table((0:count-1)',names',repmat("PENDING",count,1), ...
    nan(count,1),strings(count,1),strings(count,1), ...
    'VariableNames',{'Stage','Name','Status','Elapsed_s','Checkpoint','Message'});
for k = 1:numel(stages)
    fprintf('\n[Stage %02d; %d/%d] %s\n',k-1,k,count,names(k));
    ctx.stageLog.Status(k) = "RUNNING";
    stageClock = tic;
    try
        if isfield(ctx,'runDir')
            poc.io.writeTable(fullfile(ctx.runDir,'stage_log.csv'),ctx.stageLog);
        end
        run(fullfile(root,'scripts',stages(k)));
        if k==1
            % This immutable per-run report is the safe fallback if the
            % optional stable latest-report publication cannot proceed.
            ctx.latestReportPath=string(fullfile(ctx.runDir,'RUN_REPORT.md'));
        end
        ctx.stageLog.Elapsed_s(k) = toc(stageClock);
        ctx.stageLog.Status(k) = "COMPLETE";
        ctx.stageLog.Checkpoint(k) = string(fullfile(ctx.runDir,sprintf('stage_%02d.mat',k-1)));
        poc.io.writeTable(fullfile(ctx.runDir,'stage_log.csv'),ctx.stageLog);
        if cfg.profile=="audit" && k==count
            poc.reporting.auditReport(ctx);
        end
        if cfg.profile~="audit" && k==count
            % Export ran while its ledger row was RUNNING; persist final status.
            results = ctx; %#ok<NASGU>
            save(fullfile(ctx.runDir,'results.mat'),'results','-v7.3');
        end
        snapshot = ctx; %#ok<NASGU>
        save(ctx.stageLog.Checkpoint(k),'snapshot','-v7.3');
    catch ME
        ctx.stageLog.Status(k) = "FAILED";
        ctx.stageLog.Elapsed_s(k) = toc(stageClock);
        ctx.stageLog.Message(k) = string(ME.identifier)+": "+string(ME.message);
        if isfield(ctx,'runDir')
            poc.io.writeTable(fullfile(ctx.runDir,'stage_log.csv'),ctx.stageLog);
            poc.io.writeText(fullfile(ctx.runDir,'RUN_FAILED.txt'), ...
                string(getReport(ME,'extended','hyperlinks','off')));
            failedContext = ctx; %#ok<NASGU>
            save(fullfile(ctx.runDir,'failed_context.mat'),'failedContext','-v7.3');
        end
        rethrow(ME);
    end
end
completePath=fullfile(ctx.runDir,'RUN_COMPLETE.txt');
poc.io.writeText(completePath, ...
    "Completed profile="+cfg.profile+"; "+count+" stages. See RUN_REPORT.md and stage_log.csv.");
try
    ctx.latestReportPath=poc.reporting.publishLatest(ctx);
    ctx.latestReportStatus="PUBLISHED";
catch ME
    % The analysis succeeded. Keep its completion marker and original report;
    % do not overwrite an unowned or read-only stable report.
    ctx.latestReportStatus="FAILED";
    ctx.latestReportMessage=string(ME.identifier)+": "+string(ME.message);
    try
        poc.io.writeText(fullfile(ctx.runDir,'REPORT_PUBLISH_FAILED.txt'), ...
            ctx.latestReportMessage);
    catch
        % Preserve the successful analysis even if the diagnostic cannot be saved.
    end
    try
        warning('poc:report:LatestPublishFailed', ...
            'The latest report was not updated. Use %s. %s',ctx.latestReportPath,ctx.latestReportMessage);
    catch
        % A caller may configure warnings as errors; publication is optional.
        fprintf(2,'The latest report was not updated. Use %s. %s\n', ...
            ctx.latestReportPath,ctx.latestReportMessage);
    end
end
% The stage snapshots/results.mat reflect the context at Stage 07, before this
% optional publication. Persist the final publication outcome separately.
publicationStatus=struct('Status',ctx.latestReportStatus, ...
    'LatestReportPath',ctx.latestReportPath,'Message',ctx.latestReportMessage); %#ok<NASGU>
try
    save(fullfile(ctx.runDir,'publication_status.mat'),'publicationStatus');
catch ME
    try
        warning('poc:report:LatestStatusSave', ...
            'Could not save publication status in %s: %s',ctx.runDir,ME.message);
    catch
        fprintf(2,'Could not save publication status in %s: %s\n',ctx.runDir,ME.message);
    end
end
fprintf('\nOutputs: %s\n',ctx.runDir);
fprintf('Report (%s): %s\n',ctx.latestReportStatus,ctx.latestReportPath);
end
