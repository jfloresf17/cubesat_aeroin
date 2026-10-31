function cfg = first_analysis_config(profile,startUTC,endUTC)
%FIRST_ANALYSIS_CONFIG Build an editable MATLAB starter configuration.
%   cfg = first_analysis_config() selects the offline synthetic March demo.
%   cfg = first_analysis_config("pilot") selects real data for 1--3 March.
%   cfg = first_analysis_config("audit",startUTC,endUTC) checks dated sources.
%   Optional dates are scalar datetime values or ISO yyyy-MM-dd text.
%   A supplied start without an end selects three dates, inclusive.
%   Research settings remain explicit through study_config("research").
if nargin<1 || isempty(profile),profile="demo";end
profile=string(profile);
assert(isscalar(profile)&&ismember(profile,["demo","pilot","audit"]), ...
 'poc:first:Profile','Choose demo, pilot or audit; use run_study for research.');
cfg=study_config(profile);
hasStart=nargin>=2 && ~isempty(startUTC);
hasEnd=nargin>=3 && ~isempty(endUTC);
if hasStart,cfg.study.startUTC=calendarDate(startUTC);end
if hasEnd
 cfg.study.endUTC=calendarDate(endUTC);
elseif hasStart || profile~="demo"
 cfg.study.endUTC=cfg.study.startUTC+caldays(2);
end
assert(cfg.study.endUTC>=cfg.study.startUTC, ...
 'poc:first:Dates','End date must be on or after the start date.');
if profile~="demo"
 % A small first look is descriptive; full uncertainty settings stay separate.
 cfg.bootstrap.enabled=false;
 cfg.reporting.perSatelliteFigures=false;
end
end
function d=calendarDate(value)
if isdatetime(value)
 d=value;
else
 assert((isstring(value)&&isscalar(value))||ischar(value), ...
  'poc:first:Dates','Use a scalar datetime or an ISO yyyy-MM-dd date.');
 d=datetime(value,'InputFormat','yyyy-MM-dd','TimeZone','UTC');
end
assert(isscalar(d)&&~isnat(d),'poc:first:Dates','Use a valid scalar date.');
d.TimeZone='UTC';
d=dateshift(d,'start','day');
end
