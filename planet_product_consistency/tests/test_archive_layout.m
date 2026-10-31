function tests=test_archive_layout
%TEST_ARCHIVE_LAYOUT Exercise cache selection using isolated temporary inputs.
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
t.TestData.root=root;
end
function testNestedGuardDaysFlatPrecedenceAndOfflineMissing(t)
tmp=tempname;mkdir(tmp);
cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
c=study_config("audit");c.paths.raw=tmp;
c.study.startUTC=datetime(2026,3,1,'TimeZone','UTC');
c.study.endUTC=c.study.startUTC;c.download.guardDays=1;
c.download.enabled=false;c.download.snapshotIdentity=false;c.download.fetchEOP=false;
feb=fullfile(tmp,'2026','02');mar=fullfile(tmp,'2026','03');
mkdir(feb);mkdir(mar);
writeFixture(fullfile(feb,'planet_20260228.states'),"February state");
writeFixture(fullfile(feb,'planet_mc_20260228.tle'),"February TLE");
writeFixture(fullfile(mar,'planet_20260301.states'),"Shared state");
writeFixture(fullfile(mar,'planet_mc_20260301.tle'),"March TLE");
writeFixture(fullfile(tmp,'planet_20260301.states'),"Shared state");
writeFixture(fullfile(mar,'planet_mc_20260302.tle'),"March guard TLE");
M=poc.io.acquire(c);
verifyEqual(t,height(M),6);
verifyEqual(t,numel(unique(M.ArchiveDateUTC)),3);
checkRow(t,M,datetime(2026,2,28,'TimeZone','UTC'),"state", ...
 fullfile(feb,'planet_20260228.states'),"CACHED");
checkRow(t,M,datetime(2026,2,28,'TimeZone','UTC'),"tle", ...
 fullfile(feb,'planet_mc_20260228.tle'),"CACHED");
checkRow(t,M,datetime(2026,3,1,'TimeZone','UTC'),"state", ...
 fullfile(tmp,'planet_20260301.states'),"CACHED");
checkRow(t,M,datetime(2026,3,1,'TimeZone','UTC'),"tle", ...
 fullfile(mar,'planet_mc_20260301.tle'),"CACHED");
checkRow(t,M,datetime(2026,3,2,'TimeZone','UTC'),"state", ...
 fullfile(tmp,'planet_20260302.states'),"MISSING_OFFLINE");
checkRow(t,M,datetime(2026,3,2,'TimeZone','UTC'),"tle", ...
 fullfile(mar,'planet_mc_20260302.tle'),"CACHED");
verifyEqual(t,string(fileread(fullfile(tmp,'planet_20260301.states'))),"Shared state");
verifyEqual(t,string(fileread(fullfile(mar,'planet_20260301.states'))),"Shared state");
verifyFalse(t,isfile(fullfile(tmp,'planet_20260228.states')));
verifyFalse(t,isfile(fullfile(tmp,'planet_20260302.states')));
end
function testHistoricalReceiptValidatesHashAndPreservesTime(t)
tmp=tempname;mkdir(tmp);
cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
c=offlineConfig(tmp,1);mar=fullfile(tmp,'2026','03');mkdir(mar);
p=fullfile(mar,'planet_20260301.states');writeFixture(p,"abc");
% This standard SHA-256 value is independent of the project hash helper.
expectedHash="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
stamp="2026-10-26T03:23:01.482Z";
receipt=struct('SHA256',expectedHash,'RetrievedUTC',stamp, ...
 'LocalFile',"Z:\old-machine\planet_20260301.states");
receiptPath=string(p)+".receipt.json";poc.io.writeText(receiptPath,jsonencode(receipt));
originalReceipt=string(fileread(receiptPath));
M=poc.io.acquire(c);row=M(M.Kind=="state",:);
verifyEqual(t,row.Status,"CACHED");
verifyEqual(t,row.LocalPath,string(p)); % Never use the receipt's old Z: path.
verifyEqual(t,row.SHA256,expectedHash);
verifyEqual(t,row.RetrievedUTC,stamp);
verifyEqual(t,string(fileread(receiptPath)),originalReceipt);
verifyEqual(t,string(fileread(p)),"abc");
end
function testConflictingCopiesAndInvalidReceiptsAreExcluded(t)
tmp=tempname;mkdir(tmp);
cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
c=offlineConfig(tmp,2);mar=fullfile(tmp,'2026','03');mkdir(mar);
flat=fullfile(tmp,'planet_20260301.states');
nested=fullfile(mar,'planet_20260301.states');
writeFixture(flat,"flat revision");writeFixture(nested,"nested revision");
badHash=fullfile(mar,'planet_mc_20260301.tle');writeFixture(badHash,"abc");
poc.io.writeText(string(badHash)+".receipt.json", ...
 jsonencode(struct('SHA256',repmat('0',1,64),'RetrievedUTC',"2026-10-26T00:00:00Z")));
badJSON=fullfile(mar,'planet_20260302.states');writeFixture(badJSON,"abc");
writeFixture(string(badJSON)+".receipt.json","not valid JSON");
missingHash=fullfile(mar,'planet_mc_20260302.tle');writeFixture(missingHash,"abc");
poc.io.writeText(string(missingHash)+".receipt.json",jsonencode(struct('RetrievedUTC',"2026-10-26")));
M=poc.io.acquire(c);
verifyEqual(t,height(M),4);
verifyTrue(t,all(M.Status=="CACHE_HASH_MISMATCH"));
r=M(M.Kind=="state"&M.ArchiveDateUTC==c.study.startUTC,:);
verifyEqual(t,r.LocalPath,string(flat));
verifyTrue(t,contains(r.Message,"different SHA-256"));
verifyTrue(t,any(contains(M.Message,"Receipt SHA-256 differs")));
verifyTrue(t,any(contains(M.Message,"Cannot read or validate receipt")));
verifyTrue(t,any(contains(M.Message,"Receipt lacks SHA-256")));
verifyEqual(t,string(fileread(flat)),"flat revision");
verifyEqual(t,string(fileread(nested)),"nested revision");
% A syntactically valid receipt with a malformed digest also fails closed.
poc.io.writeText(string(badJSON)+".receipt.json",jsonencode(struct('SHA256',"bad-hash")));
M=poc.io.acquire(c);
r=M(M.Kind=="state"&M.ArchiveDateUTC==c.study.endUTC,:);
verifyEqual(t,r.Status,"CACHE_HASH_MISMATCH");
verifyTrue(t,contains(r.Message,"Receipt has invalid SHA-256"));
end
function testConfigSelectsExistingDefaultCacheWithoutUserData(t)
% Copy the config to a temporary checkout so mfilename resolves the test root.
tmp=tempname;mkdir(fullfile(tmp,'config'));
copyfile(fullfile(t.TestData.root,'config','study_config.m'),fullfile(tmp,'config','study_config.m'));
originalPath=path;originalDirectory=pwd;
cleanup=onCleanup(@()restoreConfigPath(originalPath,originalDirectory,tmp)); %#ok<NASGU>
cd(tmp);
addpath(fullfile(tmp,'config'),'-begin');clear study_config;rehash;
verifyEqual(t,string(which('study_config')),string(fullfile(tmp,'config','study_config.m')));
c=study_config("pilot");
verifyEqual(t,string(c.paths.raw),string(fullfile(tmp,'data','raw')));
nested=fullfile(tmp,'data','planet_ephemerides','raw','daily');mkdir(nested);
c=study_config("pilot");verifyEqual(t,string(c.paths.raw),string(nested));
flat=fullfile(tmp,'data','raw');mkdir(flat);
c=study_config("pilot");verifyEqual(t,string(c.paths.raw),string(flat));
c=study_config("demo");verifyEqual(t,string(c.paths.raw),string(fullfile(tmp,'data','demo_raw')));
end
function c=offlineConfig(raw,daysCount)
c=study_config("audit");c.paths.raw=raw;
c.study.startUTC=datetime(2026,3,1,'TimeZone','UTC');
c.study.endUTC=c.study.startUTC+caldays(daysCount-1);c.download.guardDays=0;
c.download.enabled=false;c.download.snapshotIdentity=false;c.download.fetchEOP=false;
end
function checkRow(t,M,d,kind,expectedPath,expectedStatus)
row=M(M.ArchiveDateUTC==d&M.Kind==kind,:);
verifyEqual(t,height(row),1);
verifyEqual(t,row.LocalPath,string(expectedPath));
verifyEqual(t,row.Status,expectedStatus);
end
function writeFixture(path,text)
[fid,msg]=fopen(path,'w');assert(fid>=0,'%s',msg);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',char(text));
end
function restoreConfigPath(originalPath,originalDirectory,tmp)
cd(originalDirectory);path(originalPath);clear study_config;rehash;
if isfolder(tmp),rmdir(tmp,'s');end
end
