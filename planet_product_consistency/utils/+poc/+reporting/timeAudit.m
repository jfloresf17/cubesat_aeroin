function A=timeAudit(ctx)
%TIMEAUDIT Audit printed source spacing separately from computed epoch separation.
names=["Cartesian TT seconds";"TLE fractional UTC day"];
counts=[height(ctx.states);height(ctx.tles)];
lo=nan(2,1);hi=nan(2,1);coarse=zeros(2,1);
tables={ctx.states,ctx.tles};
for k=1:2
 T=tables{k};
 if ~isempty(T)
  x=T.EpochSerializationStep_ns;lo(k)=min(x);hi(k)=max(x);
  coarse(k)=sum(x>double(ctx.cfg.pairing.primaryTolerance_ns));
 end
end
A=table(names,counts,lo,hi,coarse,'VariableNames', ...
 {'Product','Records','MinPrintedStep_ns','MaxPrintedStep_ns','PrintedStepAbovePrimaryScreen'});
end
