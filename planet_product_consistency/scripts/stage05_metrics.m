%% Stage 05 -- Position/velocity, signed RTN and WGS84 ground displacement
% East/north are geodesic distance-and-bearing components from the Cartesian
% footpoint to the TLE footpoint, in metres at the same comparison epoch.
ctx.residuals = poc.metrics.evaluate(ctx);
poc.io.writeTable(fullfile(ctx.runDir,'paired_residuals.csv'),ctx.residuals);
