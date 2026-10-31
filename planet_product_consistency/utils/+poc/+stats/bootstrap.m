function B=bootstrap(R,firstDate,lastDate,L,settings,seed)
%BOOTSTRAP Date-cluster non-circular moving-block bootstrap with no redrawing.
% Output intervals are uncertainty of summaries, NOT spacecraft covariances.
X=poc.stats.matrix(R);base=poc.stats.point(X);
fields=string(fieldnames(base));fields=fields(fields~="N");
nDays=round(days(lastDate-firstDate))+1;
dateIndex=round(days(R.DateUTC-firstDate))+1;
assert(all(dateIndex>=1&dateIndex<=nDays),'poc:stats:Dates','Records outside bootstrap window.');
row=struct('Metric',"",'Estimate',NaN,'Lower95',NaN,'Upper95',NaN, ...
 'BlockDays',L,'Replicates',settings.replicates,'ValidReplicates',0,'Seed',seed,'Status',"");
rows=repmat(row,numel(fields),1);
for k=1:numel(fields),rows(k).Metric=fields(k);rows(k).Estimate=base.(fields(k));end
support=numel(unique(R.DateUTC))>=max(settings.minDistinctDates,settings.minWindowBlocks*L) ...
 && nDays>=settings.minWindowBlocks*L;
if ~support
 for k=1:numel(rows),rows(k).Status="INSUFFICIENT_DATE_SUPPORT";end
 B=struct2table(rows);return;
end
stream=RandStream('mt19937ar','Seed',seed);values=nan(settings.replicates,numel(fields));
for b=1:settings.replicates
 indices=poc.stats.drawDateBlocks(nDays,L,stream);
 dayCounts=accumarray(indices,1,[nDays,1]);weights=dayCounts(dateIndex);
 s=poc.stats.point(X,weights);
 for k=1:numel(fields),values(b,k)=s.(fields(k));end
end
for k=1:numel(fields)
 a=values(:,k);a=a(isfinite(a));rows(k).ValidReplicates=numel(a);
 if numel(a)>=settings.minValidReplicates
  rows(k).Lower95=poc.stats.quantile(a,0.025);
  rows(k).Upper95=poc.stats.quantile(a,0.975);
  rows(k).Status="COMPUTED_CONDITIONAL_ON_STATIONARITY";
 else
  rows(k).Status="INSUFFICIENT_VALID_REPLICATES";
 end
end
B=struct2table(rows);
end
