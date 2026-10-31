%% Stage 02 -- Parse, reconcile native epochs, deduplicate and flag revisions
[ctx.states,ctx.tles,ctx.parseLog,ctx.occurrences] = ...
    poc.preprocess.loadArchives(ctx.manifest,ctx.cfg,ctx.leaps);
ctx.roster = poc.preprocess.readRoster(ctx.cfg.paths.roster);
assert(all(strcmpi(ctx.roster.Flock,ctx.cfg.study.flock)), ...
    'poc:identity:Flock','Roster contains records outside the configured cohort.');
poc.io.writeTable(fullfile(ctx.runDir,'states.csv'),ctx.states);
poc.io.writeTable(fullfile(ctx.runDir,'tles.csv'),ctx.tles);
poc.io.writeTable(fullfile(ctx.runDir,'parse_log.csv'),ctx.parseLog);
poc.io.writeTable(fullfile(ctx.runDir,'record_occurrences.csv'),ctx.occurrences);
poc.io.writeTable(fullfile(ctx.runDir,'roster_used.csv'),ctx.roster);
ctx.timeAudit=poc.reporting.timeAudit(ctx);
poc.io.writeTable(fullfile(ctx.runDir,'time_precision_audit.csv'),ctx.timeAudit);
