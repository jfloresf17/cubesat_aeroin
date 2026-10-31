function key=loadPlanetKey(projectRoot)
%LOADPLANETKEY Read a Planet key without executing configuration text.
% The process environment wins. If it has no key, only PLANET_API_KEY is
% read from the optional project-root .env file. Values may be unquoted or
% enclosed in matching single/double quotes. No expansion is performed.
% Key material is never included in diagnostic messages.
key=string(getenv('PLANET_API_KEY'));
if strlength(strtrim(key))>0,return;end
key="";
assert((ischar(projectRoot)&&isrow(projectRoot)) || ...
 (isstring(projectRoot)&&isscalar(projectRoot)&&~ismissing(projectRoot)), ...
 'poc:quicklook:EnvPath','Project root must be a scalar path.');
path=fullfile(string(projectRoot),'.env');
if ~isfile(path),return;end
[fid,~]=fopen(path,'r','n','UTF-8');
assert(fid>=0,'poc:quicklook:EnvRead','Could not read the project .env file.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
found=false;
while true
 line=fgetl(fid);
 if ~ischar(line),break;end
 if ~isempty(line)&&line(1)==char(65279),line=line(2:end);end
 line=strtrim(line);
 if isempty(line)||line(1)=='#',continue;end
 % Ignore other variables, such as a MATLAB executable location.
 if isempty(regexp(line,'^PLANET_API_KEY(?:\s|=|$)','once')),continue;end
 assignment=regexp(line,'^PLANET_API_KEY\s*=(.*)$','tokens','once');
 assert(~isempty(assignment),'poc:quicklook:EnvFormat', ...
  'Invalid PLANET_API_KEY assignment in .env; use KEY=value.');
 assert(~found,'poc:quicklook:EnvDuplicate', ...
  'The project .env file has more than one PLANET_API_KEY assignment.');
 found=true;
 value=strtrim(assignment{1});
 if startsWith(string(value),"#"),value='';end
 if ~isempty(value) && (value(1)==char(39)||value(1)==char(34))
  quote=value(1);
  closing=find(value(2:end)==quote,1,'first');
  assert(~isempty(closing),'poc:quicklook:EnvFormat', ...
   'The PLANET_API_KEY value in .env has an unmatched quote.');
  closing=closing+1;
  tail=strtrim(value(closing+1:end));
  assert(isempty(tail)||tail(1)=='#','poc:quicklook:EnvFormat', ...
   'Unexpected text after the quoted PLANET_API_KEY value in .env.');
  value=value(2:closing-1);
 else
  % A comment starts only after whitespace, so a literal # may be retained.
  comment=regexp(value,'\s+#','once');
  if ~isempty(comment),value=strtrim(value(1:comment-1));end
  assert(isempty(regexp(value,'\s','once')),'poc:quicklook:EnvFormat', ...
   'Unquoted PLANET_API_KEY values cannot contain whitespace.');
 end
 assert(~any(double(value)<32)||isempty(value),'poc:quicklook:EnvFormat', ...
  'The PLANET_API_KEY value contains a control character.');
 key=string(value);
end
end
