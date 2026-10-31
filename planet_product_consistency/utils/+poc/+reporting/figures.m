function figures(ctx)
%FIGURES One diagnostic per figure; never draw a continuous OD reference orbit.
R=ctx.residuals(ctx.residuals.Status=="OK"&ctx.residuals.IsPrimary,:);
if isempty(R),return;end
% Use the same explicit/default satellite selection as the run report.
satellite=poc.reporting.selectGroundSatellite(ctx);
out=fullfile(ctx.runDir,'figures');mkdir(out);
c=ctx.cfg;tag=upper(c.profile)+" - ";
if c.profile=="demo",tag="SYNTHETIC DEMO - ";end
% Sampled positions for one satellite. Daily points are not an orbit track;
% plotting markers only also avoids drawing false connections over the dateline.
D=sortrows(R(R.Satellite==satellite,:),'DateUTC');
f=figure('Visible',c.reporting.figureVisible, ...
 'Name',tag+"Subsatellite coordinates: "+satellite, ...
 'Position',[100 100 1000 800]);
tiledlayout(2,2,'TileSpacing','compact');
cartesianColour=[0.12 0.38 0.75];tleColour=[0.82 0.30 0.12];
nexttile;
a=scatter(D.DateUTC,D.LatC_deg,28,cartesianColour,'o','filled');hold on;
b=scatter(D.DateUTC,D.LatT_deg,36,tleColour,'x','LineWidth',1.2);
grid on;ylabel('Latitude (deg)');
legend([a b],{'Cartesian footpoint','TLE footpoint'},'Location','best');
title('Latitude by date');xlabel('Pair date (UTC)');
nexttile;
scatter(D.DateUTC,D.LonC_deg,28,cartesianColour,'o','filled');hold on;
scatter(D.DateUTC,D.LonT_deg,36,tleColour,'x','LineWidth',1.2);
grid on;ylabel('Longitude (deg)');xlabel('Pair date (UTC)');title('Longitude by date');
nexttile([1 2]);
scatter(D.LonC_deg,D.LatC_deg,28,cartesianColour,'o','filled');hold on;
scatter(D.LonT_deg,D.LatT_deg,36,tleColour,'x','LineWidth',1.2);
grid on;xlabel('Longitude (deg)');ylabel('Latitude (deg)');
title('Sampled positions, not a continuous ground track; estimates can overlap');
sgtitle(tag+satellite+": sampled WGS84 footpoints; N="+height(D));
saveOne(f,out,"ground_satellite_latlon");
% Date groups use the successful primary pair set; no interpolation is made.
dates=unique(R.DateUTC);dayRMS=zeros(numel(dates),1);dayN=zeros(numel(dates),1);
for k=1:numel(dates)
 rows=R.DateUTC==dates(k);dayN(k)=sum(rows);
 dayRMS(k)=sqrt(mean(R.Ground_m(rows).^2));
end
f=figure('Visible',c.reporting.figureVisible,'Name','Daily ground separation RMS');
tiledlayout(2,1,'TileSpacing','compact');
nexttile;scatter(dates,dayRMS,28,'filled');grid on;
ylabel('Ground RMS (m)');title(tag+"Daily WGS84 geodesic RMS");
nexttile;scatter(dates,dayN,28,'filled');grid on;
ylabel('Pairs (N)');xlabel('Pair date (UTC)');
saveOne(f,out,"ground_daily_rms");
% Geographic RMS for each represented satellite, using its successful days.
sats=sort(unique(R.Satellite));satRMS=zeros(numel(sats),1);satN=zeros(numel(sats),1);
for k=1:numel(sats)
 rows=R.Satellite==sats(k);satN(k)=sum(rows);
 satRMS(k)=sqrt(mean(R.Ground_m(rows).^2));
end
[satRMS,order]=sort(satRMS,'descend');sats=sats(order);satN=satN(order);
f=figure('Visible',c.reporting.figureVisible,'Name','Ground RMS by satellite', ...
 'Position',[100 100 1000 max(360,140+22*numel(sats))]);
barh(1:numel(sats),satRMS);grid on;
yticks(1:numel(sats));yticklabels(cellstr(sats));set(gca,'YDir','reverse');
xlabel('WGS84 geodesic separation RMS (m)');
title(tag+"Ground separation RMS by satellite");
right=max(1,max(satRMS)*1.2);xlim([0 right]);
for k=1:numel(sats)
 text(satRMS(k)+0.02*right,k,"N="+satN(k),'VerticalAlignment','middle','FontSize',8);
end
saveOne(f,out,"ground_satellite_rms");
fields=["Position_m","Velocity_mps","Ground_m"];
labels=["3D position discrepancy (m)","3D velocity discrepancy (m/s)","WGS84 subsatellite separation (m)"];
for k=1:3
 f=figure('Visible',c.reporting.figureVisible,'Name',fields(k));
 scatter(R.DateUTC,R.(fields(k)),14,'filled');grid on;
 xlabel('Pair date (UTC)');ylabel(labels(k));title(tag+"Primary paired-product comparison");
 saveOne(f,out,"daily_"+fields(k));
end
f=figure('Visible',c.reporting.figureVisible);
scatter(R.DateUTC,R.DeltaTime_s*1e3,14,'filled');grid on;
xlabel('Pair date (UTC)');ylabel('Signed native epoch separation (ms)');
title(tag+"Pairing audit: primary sample");saveOne(f,out,"native_epoch_separation");
f=figure('Visible',c.reporting.figureVisible);
[g,~]=sort(R.Ground_m);stairs(g,(1:numel(g))/numel(g));grid on;
xlabel('WGS84 subsatellite separation (m)');ylabel('Empirical cumulative fraction');
title(tag+"Ground-position discrepancy distribution");saveOne(f,out,"ground_ecdf");
% Each pair supplies a distinct Cartesian-footpoint local geographic basis.
f=figure('Visible',c.reporting.figureVisible,'Name','Signed ground east/north');
scatter(R.GroundEast_m,R.GroundNorth_m,18,'filled');hold on;
xline(0,':');yline(0,':');grid on;axis equal;
xlabel('East displacement (m)');ylabel('North displacement (m)');
title(tag+"Subsatellite offsets: TLE relative to Cartesian");
subtitle('Each point uses local geographic axes at its Cartesian footpoint');
saveOne(f,out,"ground_en_scatter");
f=figure('Visible',c.reporting.figureVisible,'Name','Ground components over time');
tiledlayout(2,1,'TileSpacing','compact');
groundFields=["GroundEast_m","GroundNorth_m"];
groundLabels=["East (m)","North (m)"];
colours=lines(2);
for k=1:2
 nexttile;scatter(R.DateUTC,R.(groundFields(k)),14,colours(k,:),'filled');
 grid on;yline(0,':');ylabel(groundLabels(k));
 if k==1,title(tag+"Signed subsatellite displacement: TLE relative to Cartesian");end
 if k==2,xlabel('Pair date (UTC)');end
end
saveOne(f,out,"ground_en_daily");
% Plot footpoint locations as observations, never as an interpolated ground track.
f=figure('Visible',c.reporting.figureVisible,'Name','Subsatellite locations');
scatter(R.LonC_deg,R.LatC_deg,22,R.Ground_m,'filled');grid on;
xlabel('Cartesian footpoint longitude (deg)');ylabel('Cartesian footpoint latitude (deg)');
title(tag+"Footpoint locations and subsatellite separation");
cb=colorbar;ylabel(cb,'Geodesic ground separation (m)');
saveOne(f,out,"ground_locations");
% Always include pooled RTN figures, even when individual-satellite plots are off.
f=figure('Visible',c.reporting.figureVisible,'Name','Primary RTN residuals');
tiledlayout(3,1,'TileSpacing','compact');
components=["Radial_m","Transverse_m","Normal_m"];
componentLabels=["R: radial (m)","T: transverse (m)","N: normal (m)"];
colours=lines(3);
for k=1:3
 nexttile;scatter(R.DateUTC,R.(components(k)),14,colours(k,:),'filled');
 grid on;yline(0,':');ylabel(componentLabels(k));
 if k==1,title(tag+"Primary signed RTN residuals: TLE minus Cartesian");end
 if k==3,xlabel('Pair date (UTC)');end
end
saveOne(f,out,"rtn_daily");
X=[R.Radial_m,R.Transverse_m,R.Normal_m];
mu=mean(X,1);rms=sqrt(mean(X.^2,1));sd=nan(1,3);
if height(R)>1,sd=std(X,0,1);end
f=figure('Visible',c.reporting.figureVisible,'Name','Primary RTN summary');
tiledlayout(1,2,'TileSpacing','compact');
nexttile;bar(1:3,mu);hold on;
if height(R)>1,errorbar(1:3,mu,sd,'k.','LineWidth',1);end
xticks(1:3);xticklabels({'R','T','N'});ylabel('Signed residual (m)');
yline(0,':');grid on;title('Signed mean and sample SD');
nexttile;bar(1:3,rms);xticks(1:3);xticklabels({'R','T','N'});
ylabel('Component RMS (m)');grid on;title('RMS includes offset and scatter');
sgtitle(tag+"Primary pooled RTN; "+height(R)+" pairs; TLE minus Cartesian");
saveOne(f,out,"rtn_summary");
if c.reporting.perSatelliteFigures
 sats=unique(R.Satellite,'stable');
 for k=1:numel(sats)
  d=sortrows(R(R.Satellite==sats(k),:),'DateUTC');
  f=figure('Visible',c.reporting.figureVisible);
  plot(d.DateUTC,d.Radial_m,'.-',d.DateUTC,d.Transverse_m,'.-',d.DateUTC,d.Normal_m,'.-');
  grid on;legend('Radial R','Transverse T','Normal N','Location','best');
  ylabel('Signed position residual (m)');xlabel('Pair date (UTC)');
  title(tag+sats(k)+": TLE minus Cartesian");
  saveOne(f,out,"RTN_"+regexprep(sats(k),'[^A-Za-z0-9_-]','_'));
 end
end
end
function saveOne(f,out,name)
exportgraphics(f,fullfile(out,name+".png"),'Resolution',180);
savefig(f,fullfile(out,name+".fig"));close(f);
end
