function z=summaryRow(R,sample,grouping,group,weighting)
%SUMMARYROW Add grouping metadata; equal-satellite sensitivity concerns RMS only.
if nargin<5,weighting="pair";end
s=poc.stats.point(poc.stats.matrix(R));
z=struct('Sample',sample,'Grouping',grouping,'Group',group,'Weighting',weighting, ...
 'N',s.N,'DistinctDates',numel(unique(R.DateUTC)), ...
 'Satellites',numel(unique(R.Satellite)));
f=fieldnames(s);for k=1:numel(f),z.(f{k})=s.(f{k});end
if weighting=="equal_satellite" && ~isempty(R)
 fields=string(fieldnames(s));metricFields=fields(fields~="N");
 for k=1:numel(metricFields),z.(metricFields(k))=NaN;end
 sats=unique(R.Satellite);sq=zeros(numel(sats),8);
 for k=1:numel(sats)
  X=poc.stats.matrix(R(R.Satellite==sats(k),:));sq(k,:)=mean(X.^2,1);
 end
 a=sqrt(mean(sq,1));z.RMS_Position_m=a(1);z.RMS_Velocity_mps=a(2);
 z.RMS_R_m=a(3);z.RMS_T_m=a(4);z.RMS_N_m=a(5);z.RMS_Ground_m=a(6);
 z.RMS_GroundEast_m=a(7);z.RMS_GroundNorth_m=a(8);
end
end
