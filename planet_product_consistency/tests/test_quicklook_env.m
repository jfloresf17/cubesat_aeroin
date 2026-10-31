function tests=test_quicklook_env
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root);startup_consistency();
end

function testEnvironmentTakesPrecedenceWithoutReadingFile(t)
[tmp,cleanup]=sandbox(); %#ok<ASGLU>
previous=getenv('PLANET_API_KEY');
restore=onCleanup(@()setenv('PLANET_API_KEY',previous)); %#ok<NASGU>
setenv('PLANET_API_KEY','environment-key');
% This malformed file would fail if read. Environment takes precedence.
poc.io.writeText(fullfile(tmp,'.env'),"PLANET_API_KEY='unterminated");
verifyEqual(t,poc.quicklook.loadPlanetKey(tmp),"environment-key");
end

function testMissingAndEmptyKey(t)
[tmp,cleanup]=sandbox(); %#ok<ASGLU>
previous=getenv('PLANET_API_KEY');
restore=onCleanup(@()setenv('PLANET_API_KEY',previous)); %#ok<NASGU>
setenv('PLANET_API_KEY','');
verifyEqual(t,poc.quicklook.loadPlanetKey(tmp),"");
poc.io.writeText(fullfile(tmp,'.env'),"# comment"+newline+"PLANET_API_KEY="+newline);
verifyEqual(t,poc.quicklook.loadPlanetKey(tmp),"");
end

function testQuotedAndUnquotedKeysAreReadWithoutMutation(t)
[tmp,cleanup]=sandbox(); %#ok<ASGLU>
previous=getenv('PLANET_API_KEY');
restore=onCleanup(@()setenv('PLANET_API_KEY',previous)); %#ok<NASGU>
setenv('PLANET_API_KEY','');
path=fullfile(tmp,'.env');
cases={...
 "# comment"+newline+"MATLAB_EXE=C:\MATLAB\bin\matlab.exe"+newline+ ...
   "PLANET_API_KEY=unquoted-key"+newline, "unquoted-key"; ...
 "PLANET_API_KEY='single-quoted-key' # safe comment"+newline, "single-quoted-key"; ...
 "PLANET_API_KEY="+string(char(34))+"double-quoted-key"+string(char(34))+newline, "double-quoted-key"; ...
 "PLANET_API_KEY=literal#hash # comment"+newline, "literal#hash"; ...
 "PLANET_API_KEY='$NOT_EXPANDED'"+newline, '$NOT_EXPANDED'};
for k=1:size(cases,1)
 poc.io.writeText(path,cases{k,1});
 before=fileread(path);
 verifyEqual(t,poc.quicklook.loadPlanetKey(tmp),string(cases{k,2}));
 verifyEqual(t,fileread(path),before);
 verifyEqual(t,string(getenv('PLANET_API_KEY')),"");
 listing=dir(tmp);names=string({listing.name});
 verifyFalse(t,any(endsWith(names,".provenance.json")));
end
end

function testDuplicateAndMalformedEntriesDoNotEchoSecret(t)
[tmp,cleanup]=sandbox(); %#ok<ASGLU>
previous=getenv('PLANET_API_KEY');
restore=onCleanup(@()setenv('PLANET_API_KEY',previous)); %#ok<NASGU>
setenv('PLANET_API_KEY','');
path=fullfile(tmp,'.env');secret="not-a-real-secret";
poc.io.writeText(path,"PLANET_API_KEY="+secret+newline+ ...
 "PLANET_API_KEY=second"+newline);
verifyError(t,@()poc.quicklook.loadPlanetKey(tmp),'poc:quicklook:EnvDuplicate');
try
 poc.quicklook.loadPlanetKey(tmp);
 verifyFail(t,'Expected duplicate-key error.');
catch ME
 verifyEqual(t,string(ME.identifier),"poc:quicklook:EnvDuplicate");
 verifyFalse(t,contains(string(ME.message),secret));
end
poc.io.writeText(path,"PLANET_API_KEY='"+secret);
verifyError(t,@()poc.quicklook.loadPlanetKey(tmp),'poc:quicklook:EnvFormat');
try
 poc.quicklook.loadPlanetKey(tmp);
 verifyFail(t,'Expected malformed-key error.');
catch ME
 verifyEqual(t,string(ME.identifier),"poc:quicklook:EnvFormat");
 verifyFalse(t,contains(string(ME.message),secret));
end
end

function [tmp,cleanup]=sandbox
tmp=tempname;mkdir(tmp);
cleanup=onCleanup(@()rmdir(tmp,'s'));
end
