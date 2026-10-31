function report=verify_against_reference(csvPath,positionTolerance_m,velocityTolerance_mps)
%VERIFY_AGAINST_REFERENCE Compare MATLAB SGP4 with an independent ICRF fixture.
% CSV columns: TLEFile,UTC,Rx_m,Ry_m,Rz_m,Vx_mps,Vy_mps,Vz_mps.
% TLE paths may be relative to the CSV directory. UTC must be an ISO-8601 string.
% The fixture must genuinely be independently produced, not this project's output.
root=startup_consistency();addpath(fullfile(root,'utils'));
opts=detectImportOptions(csvPath,'TextType','string');
opts=setvartype(opts,{'TLEFile','UTC'},'string');
T=readtable(csvPath,opts);parent=fileparts(csvPath);
n=height(T);dr=nan(n,1);dv=nan(n,1);
for k=1:n
 p=T.TLEFile(k);if ~isfile(p),p=fullfile(parent,p);end
 g=tleread(p);assert(isscalar(g),'poc:verify:TLE','One selected TLE is required.');
 utc=datetime(T.UTC(k),'InputFormat',"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",'TimeZone','UTC');
 [r,v]=propagateOrbit(utc,g,PropModel="sgp4",OutputCoordinateFrame="icrf");
 dr(k)=norm(r(:,1)-T{k,{'Rx_m','Ry_m','Rz_m'}}');
 dv(k)=norm(v(:,1)-T{k,{'Vx_mps','Vy_mps','Vz_mps'}}');
end
Pass=dr<=positionTolerance_m&dv<=velocityTolerance_mps;
report=table(T.TLEFile,T.UTC,dr,dv,Pass,'VariableNames', ...
 {'TLEFile','UTC','PositionDifference_m','VelocityDifference_mps','Pass'});
disp(report);
assert(all(Pass),'poc:verify:Failure','Independent comparison exceeds the specified tolerances.');
end
