function A=aggregate(ctx)
%AGGREGATE Keep primary, full wide-window and asynchronous-only samples separate.
R=ctx.residuals;R=R(R.Status=="OK",:);c=ctx.cfg;
sets={R(R.IsPrimary,:),R(R.IsWide,:),R(R.IsAsyncOnly,:)};
names=["primary_1ms","sensitivity_24h","asynchronous_only"];
blank=poc.stats.summaryRow(R([],:),"","","","pair");
rows=repmat(blank,0,1);
months=unique(dateshift((c.study.startUTC:caldays(1):c.study.endUTC)','start','month'));
sats=unique(ctx.roster.Satellite,'stable');
for j=1:numel(sets)
 D=sets{j};nm=names(j);
 rows(end+1,1)=poc.stats.summaryRow(D,nm,"pooled","ALL","pair"); %#ok<AGROW>
 rows(end+1,1)=poc.stats.summaryRow(D,nm,"pooled","ALL","equal_satellite"); %#ok<AGROW>
 for k=1:numel(sats)
  d=D(D.Satellite==sats(k),:);
  rows(end+1,1)=poc.stats.summaryRow(d,nm,"satellite",sats(k),"pair"); %#ok<AGROW>
 end
 for k=1:numel(months)
  key=string(months(k),'yyyy-MM');
  d=D(string(D.DateUTC,'yyyy-MM')==key,:);
  rows(end+1,1)=poc.stats.summaryRow(d,nm,"month",key,"pair"); %#ok<AGROW>
  if j==1
   for a=1:numel(sats)
    ds=d(d.Satellite==sats(a),:);
    rows(end+1,1)=poc.stats.summaryRow(ds,nm,"satellite_month",sats(a)+"|"+key,"pair"); %#ok<AGROW>
   end
  end
 end
end
P=sets{1};W=poc.pairing.weekly(P);
rows(end+1,1)=poc.stats.summaryRow(W,"primary_weekly","pooled","ALL","pair");
for k=1:numel(sats)
 rows(end+1,1)=poc.stats.summaryRow(W(W.Satellite==sats(k),:), ...
  "primary_weekly","satellite",sats(k),"pair"); %#ok<AGROW>
end
for k=1:numel(months)
 key=string(months(k),'yyyy-MM');d=P(string(P.DateUTC,'yyyy-MM')~=key,:);
 rows(end+1,1)=poc.stats.summaryRow(d,"primary_leave_month_out","omitted_month",key,"pair"); %#ok<AGROW>
end
A=struct2table(rows);
end
