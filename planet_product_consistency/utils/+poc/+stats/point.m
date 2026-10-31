function s=point(X,w)
%POINT Summary statistics of paired residuals, not absolute orbital errors.
% X columns: |dr|, |dv|, R, T, N, ground, east, north.
% Six columns are accepted for callers with only the original scalar metric.
% w are bootstrap multiplicities.
if nargin<2,w=ones(size(X,1),1);end
w=w(:);hasGroundComponents=size(X,2)==8;
assert((size(X,2)==6||hasGroundComponents)&&size(X,1)==numel(w), ...
 'poc:stats:Shape','Invalid data shape.');
assert(all(w>=0)&all(w==floor(w)),'poc:stats:Weights','Counts must be nonnegative integers.');
s=struct('N',sum(w),'RMS_Position_m',NaN,'Median_Position_m',NaN, ...
 'Q95_Position_m',NaN,'Max_Position_m',NaN,'RMS_Velocity_mps',NaN, ...
 'Median_Velocity_mps',NaN,'Q95_Velocity_mps',NaN, ...
 'Mean_R_m',NaN,'SD_R_m',NaN,'RMS_R_m',NaN, ...
 'Mean_T_m',NaN,'SD_T_m',NaN,'RMS_T_m',NaN, ...
 'Mean_N_m',NaN,'SD_N_m',NaN,'RMS_N_m',NaN, ...
 'RMS_Ground_m',NaN,'Median_Ground_m',NaN,'Q95_Ground_m',NaN,'Max_Ground_m',NaN, ...
 'Mean_GroundEast_m',NaN,'SD_GroundEast_m',NaN,'RMS_GroundEast_m',NaN, ...
 'Mean_GroundNorth_m',NaN,'SD_GroundNorth_m',NaN,'RMS_GroundNorth_m',NaN);
if s.N==0,return;end
ok=w>0;X=X(ok,:);w=w(ok);
assert(all(isfinite(X),'all'),'poc:stats:Finite','Retained metrics must all be finite.');
rms=sqrt(sum(w.*X.^2,1)/s.N);
s.RMS_Position_m=rms(1);s.RMS_Velocity_mps=rms(2);s.RMS_Ground_m=rms(6);
s.Median_Position_m=poc.stats.quantile(X(:,1),0.5,w);
s.Q95_Position_m=poc.stats.quantile(X(:,1),0.95,w);s.Max_Position_m=max(X(:,1));
s.Median_Velocity_mps=poc.stats.quantile(X(:,2),0.5,w);
s.Q95_Velocity_mps=poc.stats.quantile(X(:,2),0.95,w);
s.Median_Ground_m=poc.stats.quantile(X(:,6),0.5,w);
s.Q95_Ground_m=poc.stats.quantile(X(:,6),0.95,w);s.Max_Ground_m=max(X(:,6));
axes=["R","T","N"];
for k=1:3
 q=k+2;b=sum(w.*X(:,q))/s.N;sd=NaN;
 if s.N>1,sd=sqrt(sum(w.*(X(:,q)-b).^2)/(s.N-1));end
 s.("Mean_"+axes(k)+"_m")=b;s.("SD_"+axes(k)+"_m")=sd;
 s.("RMS_"+axes(k)+"_m")=rms(q);
 if s.N>1
  assert(abs(rms(q)^2-b^2-(s.N-1)/s.N*sd^2)<1e-9*max(1,rms(q)^2), ...
   'poc:stats:MomentIdentity','Component RMS/mean/SD identity failed.');
 end
end
assert(abs(rms(1)^2-sum(rms(3:5).^2))<1e-9*max(1,rms(1)^2), ...
 'poc:stats:RTNIdentity','Vector and component mean squares disagree.');
if hasGroundComponents
 components=["GroundEast","GroundNorth"];
 for k=1:2
  q=k+6;b=sum(w.*X(:,q))/s.N;sd=NaN;
  if s.N>1,sd=sqrt(sum(w.*(X(:,q)-b).^2)/(s.N-1));end
  s.("Mean_"+components(k)+"_m")=b;
  s.("SD_"+components(k)+"_m")=sd;
  s.("RMS_"+components(k)+"_m")=rms(q);
 end
 assert(abs(rms(6)^2-sum(rms(7:8).^2))<1e-9*max(1,rms(6)^2), ...
  'poc:stats:GroundIdentity','Ground and east/north component mean squares disagree.');
end
end
