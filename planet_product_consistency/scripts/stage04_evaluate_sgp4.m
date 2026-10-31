%% Stage 04 -- Fixed SGP4 evaluation; Cartesian frame preparation only
% No Cartesian propagation, BStar override, or physical-parameter fitting.
poc.frames.checkPolicy(ctx.cfg);
ctx.evaluations = poc.propagation.evaluatePairs(ctx);
poc.io.writeTable(fullfile(ctx.runDir,'evaluated_states.csv'),ctx.evaluations);
