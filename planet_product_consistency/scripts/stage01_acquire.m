%% Stage 01 -- Cache immutable source archives and auxiliary data
ctx.manifest = poc.io.acquire(ctx.cfg);
poc.io.writeTable(fullfile(ctx.runDir,'archive_manifest.csv'),ctx.manifest);
