function [C,status]=earthRotation(utc,cfg,L,E)
%EARTHROTATION Common inertial-to-terrestrial rotation for POSITIONS only.
% Complete Cartesian velocity transformation is handled by planetToICRF.
if cfg.frames.earthMode=="synthetic_identity"
 assert(cfg.profile=="demo",'poc:frame:Synthetic','Demo-only rotation.');
 C=eye(3);status="SYNTHETIC_IDENTITY";return;
end
dat=poc.time.taiMinusUTC(utc,L);
if cfg.frames.earthMode=="custom"
 C=feval(char(cfg.frames.customEarthFunction),utc,dat);
 status="CUSTOM_REVIEWED";
elseif cfg.frames.earthMode=="zero_eop_pilot"
 assert(cfg.profile=="pilot",'poc:frame:ZeroEOP','Zero EOP is pilot-only.');
 C=dcmeci2ecef('IAU-2000/2006',datevec(utc),dat,0,[0 0],'dCIP',[0 0]);
 status="ZERO_EOP_PILOT";
else
 assert(cfg.frames.earthMode=="iers_file",'poc:frame:EarthMode','Unknown Earth-frame mode.');
 mjd=days(dateshift(utc,'start','day')-datetime(1858,11,17,'TimeZone','UTC')) ...
  +seconds(utc-dateshift(utc,'start','day'))/86400;
 assert(mjd>=E.MJD(1)&&mjd<=E.MJD(end),'poc:frame:EOPRange','No EOP extrapolation is permitted.');
 lo=find(E.MJD<=mjd,1,'last');hi=find(E.MJD>=mjd,1,'first');
 ix=unique([lo hi]);
 pred=any(contains(E.Flags(ix),"P"));
 assert(~pred||cfg.frames.allowPredictedEOP,'poc:frame:PredictedEOP','Predicted EOP not enabled.');
 assert(all(strlength(E.Flags(ix))==3),'poc:frame:EOPFlags','Missing EOP status flags.');
 if lo==hi
  vals=[E.DUT1_s(lo),E.xp_arcsec(lo),E.yp_arcsec(lo),E.dX_mas(lo),E.dY_mas(lo)];
 else
  assert(E.MJD(hi)-E.MJD(lo)<=1.1,'poc:frame:EOPGap','EOP gap larger than one day.');
  % Interpolate UT1-TAI, not across a discontinuity in UT1-UTC.
  dd=datetime(1858,11,17,'TimeZone','UTC')+caldays(E.MJD(ix));
  aa=poc.time.taiMinusUTC(dd,L);
  base=[E.DUT1_s(ix)-aa,E.xp_arcsec(ix),E.yp_arcsec(ix),E.dX_mas(ix),E.dY_mas(ix)];
  vals=interp1(E.MJD(ix),base,mjd,'linear');vals(1)=vals(1)+dat;
 end
 arcsecToRad=pi/(180*3600);
 C=dcmeci2ecef('IAU-2000/2006',datevec(utc),dat,vals(1), ...
   vals(2:3)*arcsecToRad,'dCIP',vals(4:5)*arcsecToRad/1000);
 status="IERS_BULLETIN_A_OBSERVED";if pred,status="IERS_BULLETIN_A_PREDICTED";end
end
assert(isequal(size(C),[3 3])&&all(isfinite(C),'all')&&norm(C*C'-eye(3),'fro')<1e-10, ...
 'poc:frame:EarthRotation','Invalid ICRF-to-Earth-fixed rotation.');
end
