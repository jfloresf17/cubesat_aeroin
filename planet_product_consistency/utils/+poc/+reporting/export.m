function export(ctx)
%EXPORT Preserve all stages plus manuscript-facing tables and descriptive plots.
d=ctx.runDir;A=ctx.summaries;
poc.io.writeTable(fullfile(d,'summary_all.csv'),A);
poc.io.writeTable(fullfile(d,'table3_coverage.csv'),ctx.coverage);
P=A(A.Sample=="primary_1ms"&A.Weighting=="pair",:);
poc.io.writeTable(fullfile(d,'table4_pooled_state_ground.csv'),P(P.Grouping=="pooled",:));
poc.io.writeTable(fullfile(d,'summary_satellite.csv'),P(P.Grouping=="satellite",:));
poc.io.writeTable(fullfile(d,'summary_month.csv'),P(P.Grouping=="month",:));
poc.io.writeTable(fullfile(d,'summary_satellite_month.csv'),P(P.Grouping=="satellite_month",:));
row=struct('Grouping',"",'Group',"",'Component',"",'N',0,'Mean_m',NaN,'SD_m',NaN,'RMS_m',NaN);
rows=repmat(row,0,1);axes=["R","T","N"];
for k=1:height(P)
 for j=1:3
  z=row;z.Grouping=P.Grouping(k);z.Group=P.Group(k);z.Component=axes(j);z.N=P.N(k);
  z.Mean_m=P.("Mean_"+axes(j)+"_m")(k);z.SD_m=P.("SD_"+axes(j)+"_m")(k);
  z.RMS_m=P.("RMS_"+axes(j)+"_m")(k);rows(end+1,1)=z; %#ok<AGROW>
 end
end
T=struct2table(rows);
poc.io.writeTable(fullfile(d,'table5_rtn_all_groups.csv'),T);
poc.io.writeTable(fullfile(d,'table5_rtn_pooled.csv'),T(T.Grouping=="pooled",:));
% Geographic components use each Cartesian footpoint as its local origin.
% Retain sample and weighting labels, including equal-satellite RMS sensitivity.
G=A;
row=struct('Sample',"",'Grouping',"",'Group',"",'Weighting',"",'Component',"", ...
 'N',0,'Mean_m',NaN,'SD_m',NaN,'RMS_m',NaN);
rows=repmat(row,0,1);components=["GroundEast","GroundNorth"];
labels=["East","North"];
for k=1:height(G)
 for j=1:2
  z=row;z.Sample=G.Sample(k);z.Grouping=G.Grouping(k);z.Group=G.Group(k);
  z.Weighting=G.Weighting(k);
  z.Component=labels(j);z.N=G.N(k);
  z.Mean_m=G.("Mean_"+components(j)+"_m")(k);
  z.SD_m=G.("SD_"+components(j)+"_m")(k);
  z.RMS_m=G.("RMS_"+components(j)+"_m")(k);
  rows(end+1,1)=z; %#ok<AGROW>
 end
end
T=struct2table(rows);
poc.io.writeTable(fullfile(d,'table6_ground_en_all_groups.csv'),T);
poc.io.writeTable(fullfile(d,'table6_ground_en_pooled.csv'), ...
 T(T.Sample=="primary_1ms"&T.Grouping=="pooled"&T.Weighting=="pair",:));
poc.io.writeTable(fullfile(d,'bootstrap_intervals.csv'),ctx.intervals);
R=ctx.residuals(ctx.residuals.IsPrimary&ctx.residuals.Status=="OK",:);
% Ground summaries use only successful primary pairs. Keep the full roster
% in the satellite table; dates without successful pairs are not invented.
S=P(P.Grouping=="satellite",{'Group','N','DistinctDates','RMS_Ground_m', ...
 'Median_Ground_m','Q95_Ground_m','Max_Ground_m'});
S.Properties.VariableNames={'Satellite','N','DistinctDates','RMS_m', ...
 'Median_m','Q95_m','Max_m'};
poc.io.writeTable(fullfile(d,'ground_satellite_summary.csv'),S);
dailyRow=struct('DateUTC',NaT(1,1,'TimeZone','UTC'),'N',0,'RMS_m',NaN, ...
 'Median_m',NaN,'Q95_m',NaN,'Max_m',NaN);
dailyRows=repmat(dailyRow,0,1);dates=unique(R.DateUTC);
for k=1:numel(dates)
 values=R.Ground_m(R.DateUTC==dates(k));z=dailyRow;
 z.DateUTC=dates(k);z.N=numel(values);z.RMS_m=sqrt(mean(values.^2));
 z.Median_m=poc.stats.quantile(values,0.5);z.Q95_m=poc.stats.quantile(values,0.95);
 z.Max_m=max(values);dailyRows(end+1,1)=z; %#ok<AGROW>
end
dailyTable=struct2table(dailyRow);dailyTable(1,:)=[];
if ~isempty(dailyRows),dailyTable=struct2table(dailyRows);end
poc.io.writeTable(fullfile(d,'ground_daily_summary.csv'),dailyTable);
poc.io.writeTable(fullfile(d,'weekly_pairs.csv'),poc.pairing.weekly(R));
poc.io.writeTable(fullfile(d,'failed_evaluations.csv'),ctx.evaluations(ctx.evaluations.Status~="OK",:));
poc.io.writeTable(fullfile(d,'failed_metrics.csv'),ctx.residuals(ctx.residuals.Status~="OK",:));
if ctx.cfg.reporting.figures,poc.reporting.figures(ctx);end
poc.reporting.report(ctx);
results=ctx; %#ok<NASGU>
save(fullfile(d,'results.mat'),'results','-v7.3');
end
