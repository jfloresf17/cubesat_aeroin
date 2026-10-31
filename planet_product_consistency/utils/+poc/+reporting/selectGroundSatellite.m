function satellite=selectGroundSatellite(ctx)
%SELECTGROUNDSATELLITE Choose one represented satellite for the coordinate plot.
% A configured name must match exactly. Otherwise choose the largest primary
% successful-pair count, breaking ties by lexical satellite name. Return an
% empty string when no successful primary observations exist.
R=ctx.residuals(ctx.residuals.IsPrimary & ctx.residuals.Status=="OK",:);
satellite="";
if isempty(R),return;end
names=unique(string(R.Satellite));
requested="";
if isfield(ctx.cfg,'reporting') && isfield(ctx.cfg.reporting,'groundPlotSatellite')
 value=ctx.cfg.reporting.groundPlotSatellite;
 if ~isempty(value)
  requested=string(value);
  assert(isscalar(requested)&&~ismissing(requested), ...
   'poc:report:GroundSatellite','Select one satellite name or leave it empty.');
  requested=strtrim(requested);
 end
end
if strlength(requested)>0
 assert(any(names==requested),'poc:report:GroundSatellite', ...
  'Selected ground-plot satellite %s has no successful primary pairs.',requested);
 satellite=requested;return;
end
counts=zeros(numel(names),1);
for k=1:numel(names),counts(k)=sum(string(R.Satellite)==names(k));end
choices=sort(names(counts==max(counts)));
satellite=choices(1);
end
