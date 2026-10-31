function out=propagatePair(row,targetUTC,cfg,L,E)
%PROPAGATEPAIR Evaluate one native state and TLE at the same UTC epoch.
% out=poc.footprint.propagatePair(row,targetUTC,cfg,L,E) takes one row of
% the quick-look Matches table; L is a reviewed leap-second table and E is
% the decoded IERS table where cfg.frames.earthMode="iers_file".
% The caller MUST choose an explicit frame policy; no silent J2000/ICRF or
% zero-EOP fallback occurs. Research profiles retain the repository's
% independent SGP4/frame approval gates.
%
% rC_I/vC_I, rT_I/vT_I: Cartesian and TLE inertial states [m, m/s].
% rC_E/vC_E, rT_E/vT_E: same states in the Earth-fixed frame [m, m/s].
% Velocities include the rotation derivative; they are not just C*v_I.
% The Cartesian baseline uses only two-body gravity and is not Planet OD.
assert(istable(row)&&height(row)==1,'poc:footprint:Pair', ...
 'Pass one row from the native quick-look match table.');
needed={'StateEpochUTC','StateRx_m','StateRy_m','StateRz_m','StateVx_mps', ...
 'StateVy_mps','StateVz_mps','TLEEpochUTC','TLEEpochTTns','TLECatalogID', ...
 'TLEName','TLELine1','TLELine2'};
assert(all(ismember(needed,row.Properties.VariableNames)),'poc:footprint:Pair', ...
 'The match row is missing native state or TLE fields.');
assert(isdatetime(targetUTC)&&isscalar(targetUTC)&&~isnat(targetUTC)&& ...
 ~isempty(targetUTC.TimeZone),'poc:footprint:Epoch','Target UTC must be timezone-aware.');
assert(isdatetime(row.StateEpochUTC)&&~isnat(row.StateEpochUTC)&& ...
 ~isempty(row.StateEpochUTC.TimeZone)&&isdatetime(row.TLEEpochUTC)&& ...
 ~isnat(row.TLEEpochUTC)&&~isempty(row.TLEEpochUTC.TimeZone), ...
 'poc:footprint:Epoch','Native epochs must be timezone-aware.');
targetUTC.TimeZone='UTC';
assert(string(cfg.sgp4.backend)=="matlab",'poc:footprint:SGP4Backend', ...
 'Scene-epoch evaluation requires MATLAB SGP4, not a synthetic backend.');
poc.frames.checkPolicy(cfg);
r0=row{1,{'StateRx_m','StateRy_m','StateRz_m'}}';
v0=row{1,{'StateVx_mps','StateVy_mps','StateVz_mps'}}';
[r0,v0,framePolicy]=poc.frames.planetToICRF(row.StateEpochUTC,r0,v0,cfg);
dt=seconds(targetUTC-row.StateEpochUTC);
[rC,vC]=poc.footprint.propagateCartesian(r0,v0,dt);
g=readNativeTLE(row);
if isempty(g.Epoch.TimeZone),g.Epoch.TimeZone='UTC';end
assert(string(g.SatelliteCatalogNumber)==string(row.TLECatalogID), ...
 'poc:footprint:TLEIdentity','Parsed TLE does not match the recorded catalog ID.');
assert(isa(row.TLEEpochTTns,'int64'),'poc:footprint:TLEPrecision', ...
 'Native TLE epoch must retain int64 nanoseconds; load the MAT output, not lossy CSV.');
epochError=double(poc.time.utcToTTns(g.Epoch,L)-row.TLEEpochTTns);
assert(abs(epochError)<=double(cfg.time.maxTlereadEpochDifference_ns), ...
 'poc:footprint:TLEPrecision','MATLAB tleread epoch exceeds the precision gate.');
% tleread MeanMotion is in degrees/second (not revolutions/day).
assert(isfinite(g.MeanMotion)&&g.MeanMotion>0&&6/g.MeanMotion<225, ...
 'poc:footprint:SGP4Regime', ...
 'Selected TLE is outside the near-Earth SGP4 regime.');
% MathWorks documents default inertial output as ICRF. The R2026b Update 1
% executable rejects its documented explicit "icrf" option, so omit it.
[rT,vT]=propagateOrbit(targetUTC,g,PropModel="sgp4");
rT=rT(:,1);vT=vT(:,1);
assert(numel(rT)==3&&numel(vT)==3&&all(isfinite([rT;vT])), ...
 'poc:footprint:SGP4','SGP4 produced an invalid state.');
[C,eopStatus]=poc.frames.earthRotation(targetUTC,cfg,L,E);
% Compute the entire Earth-rotation derivative, including the selected EOP
% policy, without substituting a fixed spin rate for the frame transform.
% EOP coverage and leap validity are checked at both derivative epochs.
h=0.25;
[Cp,sp]=poc.frames.earthRotation(targetUTC+seconds(h),cfg,L,E);
[Cm,sm]=poc.frames.earthRotation(targetUTC-seconds(h),cfg,L,E);
assert(sp==eopStatus&&sm==eopStatus,'poc:footprint:EOPBoundary', ...
 'Earth-rotation derivative straddles differing EOP quality statuses.');
Cdot=(Cp-Cm)/(2*h);
out=struct('UTC',targetUTC,'rC_I',rC,'vC_I',vC,'rT_I',rT,'vT_I',vT, ...
 'rC_E',C*rC,'vC_E',C*vC+Cdot*rC,'rT_E',C*rT,'vT_E',C*vT+Cdot*rT, ...
 'FramePolicy',framePolicy,'EOPStatus',eopStatus, ...
 'CartesianPropagation',"two_body_ode113",'SceneMinusState_s',dt, ...
 'SceneMinusTLE_s',seconds(targetUTC-row.TLEEpochUTC), ...
 'TLEEpochParseError_ns',epochError);
end

function g=readNativeTLE(row)
% Cache immutable parsed TLEs to avoid one filesystem read per image.
persistent cache
if isempty(cache),cache=containers.Map('KeyType','char','ValueType','any');end
line1=string(row.TLELine1);line2=string(row.TLELine2);
assert(isscalar(line1)&&isscalar(line2)&&strlength(line1)>0&&strlength(line2)>0, ...
 'poc:footprint:TLE','Missing native TLE lines.');
key=char(line1+newline+line2);
if isKey(cache,key),g=cache(key);return;end
path=[tempname,'.tle'];cleanup=onCleanup(@()deleteTemp(path)); %#ok<NASGU>
poc.io.writeText(path,"0 "+string(row.TLEName)+newline+line1+newline+line2+newline);
g=tleread(path);
assert(isscalar(g),'poc:footprint:TLE','Expected one parsed TLE.');
cache(key)=g;
end

function deleteTemp(path)
if isfile(path),delete(path);end
end
