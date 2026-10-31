function O=bootstrapGroups(ctx)
%BOOTSTRAPGROUPS Primary daily data only; no automatic imputation or re-draw.
c=ctx.cfg;R=ctx.residuals(ctx.residuals.Status=="OK"&ctx.residuals.IsPrimary,:);
sets={};starts={};ends={};groupings=strings(0,1);groups=strings(0,1);
if ismember("pooled",c.bootstrap.groupings)
 sets{end+1}=R;starts{end+1}=c.study.startUTC;ends{end+1}=c.study.endUTC;
 groupings(end+1)="pooled";groups(end+1)="ALL";
end
if ismember("satellite",c.bootstrap.groupings)
 sats=unique(ctx.roster.Satellite,'stable');
 for k=1:numel(sats)
  sets{end+1}=R(R.Satellite==sats(k),:);starts{end+1}=c.study.startUTC;ends{end+1}=c.study.endUTC; %#ok<AGROW>
  groupings(end+1)="satellite";groups(end+1)=sats(k); %#ok<AGROW>
 end
end
if ismember("month",c.bootstrap.groupings)
 months=unique(dateshift((c.study.startUTC:caldays(1):c.study.endUTC)','start','month'));
 for k=1:numel(months)
  a=max(months(k),c.study.startUTC);b=min(months(k)+calmonths(1)-caldays(1),c.study.endUTC);
  sets{end+1}=R(R.DateUTC>=a&R.DateUTC<=b,:);starts{end+1}=a;ends{end+1}=b; %#ok<AGROW>
  groupings(end+1)="month";groups(end+1)=string(a,'yyyy-MM'); %#ok<AGROW>
 end
end
O=table();
for k=1:numel(sets)
 for j=1:numel(c.bootstrap.blockDays)
  L=c.bootstrap.blockDays(j);seed=c.bootstrap.seed+1000*k+L;
  B=poc.stats.bootstrap(sets{k},starts{k},ends{k},L,c.bootstrap,seed);
  B.Grouping=repmat(groupings(k),height(B),1);B.Group=repmat(groups(k),height(B),1);
  if isempty(O),O=B;else,O=[O;B];end %#ok<AGROW>
 end
 fprintf('Uncertainty group %d/%d complete.\n',k,numel(sets));
end
end
