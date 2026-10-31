%% Stage 06 -- Pooled/grouped statistics, thinning and date-block uncertainty
ctx.summaries = poc.stats.aggregate(ctx);
if ctx.cfg.bootstrap.enabled
    ctx.intervals = poc.stats.bootstrapGroups(ctx);
else
    ctx.intervals = table();
end
