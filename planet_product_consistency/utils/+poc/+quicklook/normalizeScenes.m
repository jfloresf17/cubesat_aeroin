function T = normalizeScenes(features)
%NORMALIZESCENES Convert Planet PSScene features into a stable MATLAB table.
% Missing mandatory identifiers/times are retained with MetadataStatus set.
% Raw geometry and properties are preserved as JSON for later inspection.
if isempty(features)
 features=cell(0,1);
elseif isstruct(features)
 features=num2cell(features(:));
elseif iscell(features)
 features=features(:);
else
 error('poc:quicklook:SceneSchema','Planet features must be an array.');
end
n=numel(features);
names={'SatelliteID','SceneID','AcquiredUTC','AcquiredRaw','StripID', ...
 'ViewAngle_deg','SatelliteAzimuth_deg','GeometryJSON','GroundControl', ...
 'QualityCategory','PublishingStage','CloudCover','SunAzimuth_deg', ...
 'SunElevation_deg','GSD_m','Instrument','ThumbnailURL','ItemURL', ...
 'PropertiesJSON','MetadataStatus'};
types={'string','string','datetime','string','string','double','double', ...
 'string','double','string','string','double','double','double','double', ...
 'string','string','string','string','string'};
T=table('Size',[n numel(names)],'VariableTypes',types,'VariableNames',names);
T.AcquiredUTC.TimeZone='UTC';
for k=1:n
 f=features{k};
 if ~isstruct(f)||~isscalar(f)
  error('poc:quicklook:SceneSchema','A Planet feature is not an object.');
 end
 p=getObject(f,{'properties'});links=getObject(f,{'x_links','_links','links'});
 T.SceneID(k)=getText(f,{'id'});
 T.SatelliteID(k)=lower(getText(p,{'satellite_id'}));
 T.AcquiredRaw(k)=getText(p,{'acquired'});
 T.AcquiredUTC(k)=parseUTC(T.AcquiredRaw(k));
 T.StripID(k)=getText(p,{'strip_id'});
 T.ViewAngle_deg(k)=getNumber(p,{'view_angle'});
 T.SatelliteAzimuth_deg(k)=getNumber(p,{'satellite_azimuth'});
 geometry=getObject(f,{'geometry'});
 if isempty(fieldnames(geometry)),T.GeometryJSON(k)="";
 else,T.GeometryJSON(k)=string(jsonencode(geometry));end
 T.GroundControl(k)=getNumber(p,{'ground_control'});
 T.QualityCategory(k)=getText(p,{'quality_category'});
 T.PublishingStage(k)=getText(p,{'publishing_stage'});
 T.CloudCover(k)=getNumber(p,{'cloud_cover'});
 T.SunAzimuth_deg(k)=getNumber(p,{'sun_azimuth'});
 T.SunElevation_deg(k)=getNumber(p,{'sun_elevation'});
 T.GSD_m(k)=getNumber(p,{'gsd'});
 T.Instrument(k)=getText(p,{'instrument'});
 T.ThumbnailURL(k)=safeURL(getText(links,{'thumbnail','x_thumbnail','_thumbnail'}),"thumbnail");
 T.ItemURL(k)=safeURL(getText(links,{'x_self','_self','self'}),"item");
 T.PropertiesJSON(k)=string(jsonencode(p));
 issues=strings(0,1);
 if strlength(T.SceneID(k))==0,issues(end+1)="MISSING_SCENE_ID";end %#ok<AGROW>
 if strlength(T.SatelliteID(k))==0,issues(end+1)="MISSING_SATELLITE_ID";end %#ok<AGROW>
 if isnat(T.AcquiredUTC(k)),issues(end+1)="INVALID_ACQUIRED_TIME";end %#ok<AGROW>
 if isempty(issues),T.MetadataStatus(k)="OK";
 else,T.MetadataStatus(k)=strjoin(issues,';');end
end
end

function url=safeURL(value,kind)
% Retain only trusted HTTPS item/thumbnail paths; never persist query tokens.
url="";
if strlength(value)==0,return;end
if kind=="thumbnail"
 pattern='^(https://tiles\.planet\.com/data/v1/item-types/PSScene/items/[A-Za-z0-9_-]+/thumb)(?:[?#].*)?$';
else
 pattern='^(https://api\.planet\.com/data/v1/item-types/PSScene/items/[A-Za-z0-9_-]+/?)(?:[?#].*)?$';
end
m=regexpi(char(value),pattern,'tokens','once');
if ~isempty(m),url=string(m{1});end
end

function value=getObject(parent,names)
value=struct();
if ~isstruct(parent)||~isscalar(parent),return;end
for j=1:numel(names)
 name=names{j};
 if isfield(parent,name)&&isstruct(parent.(name))&&isscalar(parent.(name))
  value=parent.(name);return
 end
end
end

function value=getText(parent,names)
value="";
if ~isstruct(parent)||~isscalar(parent),return;end
for j=1:numel(names)
 name=names{j};if ~isfield(parent,name),continue;end
 v=parent.(name);
 if (isstring(v)&&isscalar(v)&&~ismissing(v)) || (ischar(v)&&isrow(v))
  value=string(v);return
 end
end
end

function value=getNumber(parent,names)
value=NaN;
if ~isstruct(parent)||~isscalar(parent),return;end
for j=1:numel(names)
 name=names{j};if ~isfield(parent,name),continue;end
 v=parent.(name);
 if (isnumeric(v)||islogical(v))&&isscalar(v)&&isfinite(double(v))
  value=double(v);return
 end
end
end

function t=parseUTC(value)
% RFC 3339, including fractional seconds and explicit timezone offsets.
t=NaT('TimeZone','UTC');
if ~isscalar(value)||ismissing(value)||strlength(value)==0,return;end
m=regexp(char(value), ...
 '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?([Zz]|[+-]\d{2}:\d{2})$', ...
 'tokens','once');
if isempty(m),return;end
try
 t=datetime(m{1},'InputFormat',"yyyy-MM-dd'T'HH:mm:ss",'TimeZone','UTC');
 if ~isempty(m{2}),t=t+seconds(str2double(m{2}));end
 zone=m{3};
 if ~strcmpi(zone,'Z')
  hoursOffset=str2double(zone(2:3));minutesOffset=str2double(zone(5:6));
  if hoursOffset>23||minutesOffset>59,t=NaT('TimeZone','UTC');return;end
  shift=hoursOffset*3600+minutesOffset*60;
  if zone(1)=='-',shift=-shift;end
  t=t-seconds(shift);
 end
catch
 t=NaT('TimeZone','UTC');
end
end
