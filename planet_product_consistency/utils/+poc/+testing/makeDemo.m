function makeDemo(cfg)
%MAKEDEMO Write deterministic synthetic inputs; never presented as Planet data.
if ~isfolder(cfg.paths.raw),mkdir(cfg.paths.raw);end
L=poc.time.readLeaps(cfg.paths.leaps,cfg.time.validThroughUTC);
Satellite=["Synthetic A";"Synthetic B"];HWID=["00a1";"00a2"];
CatalogID=["99001";"99002"];Flock=["SYNTHETIC";"SYNTHETIC"];
ValidFromUTC=["2026-01-01";"2026-01-01"];ValidToUTC=["2026-12-31";"2026-12-31"];
HistoricallyVerified=["true";"true"];Evidence=["Synthetic identity";"Synthetic identity"];
writetable(table(Satellite,HWID,CatalogID,Flock,ValidFromUTC,ValidToUTC, ...
 HistoricallyVerified,Evidence),cfg.paths.roster);
dates=(cfg.study.startUTC-caldays(1)):caldays(1):(cfg.study.endUTC+caldays(1));
pr=struct([]);previousStates="";previousTles="";
for k=1:numel(dates)
 states="# SYNTHETIC TEST DATA: NOT PLANET OD"+newline;
 tles="# SYNTHETIC TEST DATA: NOT FOR ORBITAL USE"+newline;
 d=dates(k);
 if d>=cfg.study.startUTC&&d<=cfg.study.endUTC&&~ismember(day(d),[5 12])
  for s=1:2
   utc=d+hours(12);doy=days(d-datetime(year(d),1,1,'TimeZone','UTC'))+1;
   epoch=sprintf('%02d%03d.50000000',mod(year(d),100),doy);
   a='1 60481U 24149P   26221.03108796  .00000000  00000+0  34456-3 0    03';
   b='2 60481 097.3739 304.6256 0003992 089.3974 100.3268 15.42428719    01';
   a(3:7)=char(CatalogID(s));b(3:7)=char(CatalogID(s));a(19:32)=epoch;
   a(69)=checkChar(a);b(69)=checkChar(b);
   tles=tles+"0 "+Satellite(s)+" "+upper(HWID(s))+newline+string(a)+newline+string(b)+newline;
   ns=poc.time.utcToTTns(utc,L)+int64(224000);
   if day(d)==10&&s==2,ns=ns+int64(3600)*int64(1000000000);end
   theta=2*pi*(day(d)-1)/31+0.7*s;
   u=[cos(theta);sin(theta);0];w=[-sin(theta);cos(theta);0];
   rT=7000000*u;vT=7500*w;
   rC=rT-((10+s)*u+(20+5*sin(theta))*w+[0;0;3*s]);
   vC=vT-[0.01*s;0.02;0];
   values=sprintf(' %.15e',[rC;vC]);
   states=states+HWID(s)+" "+poc.time.formatTT(ns)+string(values)+" 20 inf"+newline;
   z=struct('HWID',HWID(s),'EpochTTns',ns,'Rx_m',rT(1),'Ry_m',rT(2),'Rz_m',rT(3), ...
    'Vx_mps',vT(1),'Vy_mps',vT(2),'Vz_mps',vT(3));
   if isempty(pr),pr=z;else,pr(end+1,1)=z;end %#ok<AGROW>
  end
 end
 % A repeat in a later archive is preserved as an occurrence, not another state.
 if day(d)==8,states=states+previousStates;tles=tles+previousTles;end
 ds=string(d,'yyyyMMdd');
 poc.io.writeText(fullfile(cfg.paths.raw,"planet_"+ds+".states"),states);
 poc.io.writeText(fullfile(cfg.paths.raw,"planet_mc_"+ds+".tle"),tles);
 previousStates=states;previousTles=tles;
end
predictions=struct2table(pr); %#ok<NASGU>
save(fullfile(cfg.paths.raw,'fixture_predictions.mat'),'predictions');
end
function c=checkChar(a)
b=a(1:68);digit=b>='0'&b<='9';v=mod(sum(double(b(digit))-48)+sum(b=='-'),10);
c=char(48+v);
end
