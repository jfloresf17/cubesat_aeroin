function writeFigures(r)
%WRITEFIGURES Export legible figures without changing the MATLAB theme.
if ~isempty(r.Geometries)
indices=find(cellfun(@(v)v.MatchIndex==r.Geometries{1}.MatchIndex,r.Geometries));
f=figure('Visible','off','Color','w','Position',[100 100 1000 450]);tiledlayout(1,numel(indices));
for i=indices(:).'
 g=r.Geometries{i};ax=nexttile;hold(ax,'on');styleAxes(ax);
 plot(ax,g.Observed.lon_deg,g.Observed.lat_deg,'k-','LineWidth',1.6);
 plot(ax,g.Cartesian.lon_deg,g.Cartesian.lat_deg,'b-','LineWidth',1.3);
 plot(ax,g.TLE.lon_deg,g.TLE.lat_deg,'r--','LineWidth',1.3);
 xlabel(ax,'Longitude (deg)');ylabel(ax,'Latitude (deg)');
 legend(ax,{'Published','Cartesian proxy','TLE proxy'},'Location','best','Color','w','TextColor','k');
 title(ax,sprintf('Cross-track sign %+d',g.CrossSign));grid(ax,'on');
end
sgtitle('Example conditional footprints; no fitted boundary','Color','k');
exportgraphics(f,fullfile(r.RunDir,'footprint_example.png'),'BackgroundColor','white');close(f);
end
if ~isempty(r.OrbitalMetrics)
 t=r.OrbitalMetrics;f=figure('Visible','off','Color','w','Position',[100 100 1000 450]);tiledlayout(1,2);
 ax=nexttile;styleAxes(ax);histogram(ax,t.SurfaceGeodesic_m);xlabel(ax,'WGS84 surface separation (m)');ylabel(ax,'Matched combinations');grid(ax,'on');
 ax=nexttile;styleAxes(ax);histogram(ax,t.Position3D_m);xlabel(ax,'3D position separation (m)');ylabel(ax,'Matched combinations');grid(ax,'on');
 exportgraphics(f,fullfile(r.RunDir,'orbital_separation.png'),'BackgroundColor','white');close(f);
 writeTimingFigure(t,r.RunDir);
 writeRTNFigure(t,r.RunDir);
 writeSubsatelliteFigure(t,r.RunDir);
end
if ~isempty(r.FootprintMetrics)&&ismember('IoU',r.FootprintMetrics.Properties.VariableNames)
 t=r.FootprintMetrics;signs=unique(t.CrossSign).';
 f=figure('Visible','off','Color','w','Position',[100 100 1000 450]);tiledlayout(1,numel(signs));
 names=["cartesian_vs_published","tle_vs_published"];
 for signValue=signs
  ax=nexttile;styleAxes(ax);hold(ax,'on');
  for k=1:numel(names)
   vals=t.IoU(t.Comparison==names(k)&t.CrossSign==signValue);vals=vals(isfinite(vals));
   if ~isempty(vals),histogram(ax,vals,'BinLimits',[0 1],'BinWidth',0.1,'FaceAlpha',0.45);end
  end
  xlabel(ax,'Intersection over union');ylabel(ax,'Matched combinations');
  legend(ax,{'Cartesian proxy','TLE proxy'},'Color','w','TextColor','k');grid(ax,'on');
  title(ax,sprintf('Cross-track sign %+d',signValue));
 end
 sgtitle('Conditional footprint overlap by pointing hypothesis','Color','k');
 exportgraphics(f,fullfile(r.RunDir,'footprint_overlap.png'),'BackgroundColor','white');close(f);
 writePairedFootprintFigure(t,r.RunDir);
end
end

function writeTimingFigure(t,runDir)
% Record age is acquisition minus native epoch; negative TLE ages are allowed.
f=figure('Visible','off','Color','w','Position',[100 100 1000 450]);tiledlayout(1,2);
ax=nexttile;histogram(ax,t.SceneMinusState_s,25,'FaceColor',[0.15 0.4 0.7]);styleAxes(ax);
xlabel(ax,'Acquisition minus Cartesian epoch (s)');ylabel(ax,'Matched combinations');grid(ax,'on');
title(ax,'Cartesian time offsets');
if max(abs(t.SceneMinusTLE_s))<=300,tleOffset=t.SceneMinusTLE_s;timeUnits='s';
else,tleOffset=t.SceneMinusTLE_s/3600;timeUnits='h';end
ax=nexttile;histogram(ax,tleOffset,25,'FaceColor',[0.75 0.3 0.15]);styleAxes(ax);
xlabel(ax,['Acquisition minus TLE epoch (' timeUnits ')']);ylabel(ax,'Matched combinations');grid(ax,'on');
title(ax,sprintf('TLE epoch after scene: %d / %d',sum(t.SceneMinusTLE_s<0),numel(t.SceneMinusTLE_s)));
sgtitle('Native epoch offsets; both products evaluated at acquisition','Color','k');
exportgraphics(f,fullfile(runDir,'acquisition_timing.png'),'BackgroundColor','white');close(f);
end

function writeRTNFigure(t,runDir)
f=figure('Visible','off','Color','w','Position',[100 100 1100 720]);tiledlayout(2,2);
names={'Radial_m','Transverse_m','Normal_m','SurfaceGeodesic_m'};
labels={'Radial (m)','Transverse (m)','Normal (m)','WGS84 surface separation (m)'};
for k=1:4
 ax=nexttile;scatter(ax,t.AcquiredUTC,t.(names{k}),14,[0.12 0.35 0.67],'filled');styleAxes(ax);
 xlabel(ax,'Nominal acquisition UTC');ylabel(ax,labels{k});grid(ax,'on');
 if k<4,title(ax,'Signed TLE minus Cartesian');else,title(ax,'Subsatellite geodesic distance');end
end
sgtitle('Orbital-product discrepancy at the common scene epoch','Color','k');
exportgraphics(f,fullfile(runDir,'rtn_geodesic_by_time.png'),'BackgroundColor','white');close(f);
end

function writeSubsatelliteFigure(t,runDir)
f=figure('Visible','off','Color','w','Position',[100 100 1400 460]);tiledlayout(1,3);
ax=nexttile;styleAxes(ax);hold(ax,'on');
% Each NaN-delimited segment is one matched pair, not a track. Skip
% dateline-crossing connectors rather than draw a false line across the map.
good=isfinite(t.LonC_deg)&isfinite(t.LatC_deg)&isfinite(t.LonT_deg)&isfinite(t.LatT_deg);
seg=good&abs(t.LonC_deg-t.LonT_deg)<=180;
x=[t.LonC_deg(seg),t.LonT_deg(seg),nan(sum(seg),1)]';
y=[t.LatC_deg(seg),t.LatT_deg(seg),nan(sum(seg),1)]';
plot(ax,x(:),y(:),'-','Color',[0.5 0.5 0.5],'HandleVisibility','off');
scatter(ax,t.LonC_deg(good),t.LatC_deg(good),15,[0 0.3 0.8],'filled');
scatter(ax,t.LonT_deg(good),t.LatT_deg(good),15,[0.85 0.2 0.1]);
xlabel(ax,'Longitude (deg)');ylabel(ax,'Latitude (deg)');title(ax,'All paired subsatellite points');
legend(ax,{'Cartesian','TLE'},'Color','w','TextColor','k','Location','best');grid(ax,'on');
ax=nexttile;styleAxes(ax);hold(ax,'on');k=find(good,1);
if ~isempty(k)
 lon=[t.LonC_deg(k),t.LonT_deg(k)];lon(2)=lon(1)+mod(lon(2)-lon(1)+180,360)-180;
 plot(ax,lon,[t.LatC_deg(k),t.LatT_deg(k)],'-','Color',[0.5 0.5 0.5]);
 scatter(ax,lon(1),t.LatC_deg(k),50,[0 0.3 0.8],'filled');scatter(ax,lon(2),t.LatT_deg(k),50,[0.85 0.2 0.1],'filled');
 if abs(diff(lon))>1e-10,xticks(ax,linspace(min(lon),max(lon),3));xtickformat(ax,'%.4f');end
 title(ax,{'Example pair',char(t.SceneID(k))},'Interpreter','none');
end
xlabel(ax,'Longitude (deg, locally unwrapped)');ylabel(ax,'Latitude (deg)');grid(ax,'on');
ax=nexttile;styleAxes(ax);hold(ax,'on');
scatter(ax,t.SurfaceEast_m,t.SurfaceNorth_m,16,[0.15 0.4 0.7],'filled');
plot(ax,0,0,'k+','MarkerSize',10,'LineWidth',1.3);
xlabel(ax,'TLE minus Cartesian: east (m)');ylabel(ax,'TLE minus Cartesian: north (m)');
title(ax,'Geodesic displacement components');axis(ax,'equal');grid(ax,'on');
sgtitle('Common-epoch WGS84 subsatellite pairs; lines are not trajectories','Color','k');
exportgraphics(f,fullfile(runDir,'subsatellite_pairs.png'),'BackgroundColor','white');close(f);
end

function writePairedFootprintFigure(t,runDir)
signs=unique(t.CrossSign).';
f=figure('Visible','off','Color','w','Position',[100 100 1100 780]);tiledlayout(2,numel(signs));
% MatchIndex identifies the same native state/TLE/scene combination. Never
% pair sorted distributions, nor choose a sign separately for each product.
names={'IoU','BoundarySymmetricP95_m'};
for metric=1:2
 for s=signs
  ax=nexttile;styleAxes(ax);hold(ax,'on');
  c=t(t.CrossSign==s&t.Comparison=="cartesian_vs_published",:);
  q=t(t.CrossSign==s&t.Comparison=="tle_vs_published",:);
  [~,ic,iq]=intersect(c.MatchIndex,q.MatchIndex,'stable');
  xx=c.(names{metric})(ic);yy=q.(names{metric})(iq);valid=isfinite(xx)&isfinite(yy);xx=xx(valid);yy=yy(valid);
  if metric==2,xx=xx/1000;yy=yy/1000;end
  scatter(ax,xx,yy,20,[0.12 0.4 0.68],'filled','MarkerFaceAlpha',0.55);
  if metric==1
   lim=1;label='IoU';
  else
   lim=max([xx;yy;1]);label='boundary P95 (km)';
  end
  plot(ax,[0 lim],[0 lim],'k--','LineWidth',1);xlim(ax,[0 lim]);ylim(ax,[0 lim]);axis(ax,'square');
  xlabel(ax,['Cartesian ' label]);ylabel(ax,['TLE ' label]);
  title(ax,sprintf('Cross-track sign %+d; %d pairs',s,numel(xx)));grid(ax,'on');
 end
end
sgtitle('Same-scene footprint metrics against published polygon; diagonal means equal score','Color','k');
exportgraphics(f,fullfile(runDir,'paired_footprint_metrics.png'),'BackgroundColor','white');close(f);
end

function styleAxes(ax)
ax.Color='w';ax.XColor='k';ax.YColor='k';ax.GridColor=[0.5 0.5 0.5];
ax.Title.Color='k';ax.XLabel.Color='k';ax.YLabel.Color='k';
end
