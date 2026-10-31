function tests=test_quicklook_matching
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
startup_consistency();t.TestData.root=root;
end

function testAllCombinationsAtToleranceAndUtcMidnight(t)
[S,T,R,opts]=fixtures();
scenes=scene("known","0001","2026-03-02T00:00:00.000Z");
% One state on either side of midnight is exactly 10 seconds away. Two
% TLEs are on the scene UTC date; the third is on the prior day even though
% its source archive date is the same as the scene date.
[M,status]=poc.quicklook.matchScenes(scenes,S,T,R,opts);
verifyEqual(t,height(M),4);
verifyEqual(t,status.StateCandidateCount,2);
verifyEqual(t,status.SameDayTLECount,2);
verifyEqual(t,status.MatchCount,4);
verifyEqual(t,sort(unique(M.SceneMinusState_s)),[-10;10],'AbsTol',1e-7);
verifyTrue(t,all(dateshift(M.TLEEpochUTC,'start','day')== ...
 datetime(2026,3,2,'TimeZone','UTC')));
verifyTrue(t,all(M.IdentityVerified));
verifyTrue(t,all(M.IdentityStatus=="HISTORICALLY_VERIFIED"));
% No implicit primary 1-ms restriction is allowed: one accepted TLE is hours
% away but falls on the same UTC day.
verifyTrue(t,any(abs(M.SceneMinusTLE_s)>3600));
end

function testUnverifiedNativeHeaderAndRosterConflict(t)
[S,T,R,opts]=fixtures();
S.HWID(:)="beef";T.HeaderHWID(:)="beef";
unknown=scene("unknown","beef","2026-03-02T00:00:00.000Z");
[M,status]=poc.quicklook.matchScenes(unknown,S,T,R,opts);
verifyEqual(t,height(M),4);
verifyEqual(t,status.Status,"MATCHED");
verifyFalse(t,any(M.IdentityVerified));
verifyTrue(t,all(M.IdentityStatus=="HEADER_ONLY_UNVERIFIED"));

[S,T,R,opts]=fixtures();T.CatalogID(2)="99999";
known=scene("known","0001","2026-03-02T00:00:00.000Z");
[M,status]=poc.quicklook.matchScenes(known,S,T,R,opts);
conflict=M.TLECatalogID=="99999";
verifyEqual(t,sum(conflict),2);
verifyTrue(t,all(M.IdentityStatus(conflict)=="ROSTER_CATALOG_CONFLICT"));
verifyTrue(t,all(M.MatchStatus(conflict)=="IDENTITY_CONFLICT"));
verifyFalse(t,any(M.IdentityVerified(conflict)));
verifyEqual(t,status.Status,"MATCHED_WITH_ROSTER_CONFLICT");
end

function testNoStateNoSameDayTleAndEmptyInputs(t)
[S,T,R,opts]=fixtures();
x=scene("known","0001","2026-03-02T00:00:00.000Z");
opts.TimeToleranceSeconds=9;
[M,status]=poc.quicklook.matchScenes(x,S,T,R,opts);
verifyEmpty(t,M);
verifyEqual(t,status.Status,"NO_STATE_WITHIN_TOLERANCE");
opts.TimeToleranceSeconds=10;
[M,status]=poc.quicklook.matchScenes(x,S,T(3,:),R,opts);
verifyEmpty(t,M);
verifyEqual(t,status.Status,"NO_USABLE_SAME_DAY_TLE");
[M,status]=poc.quicklook.matchScenes(x([],:),S([],:),T([],:),R,opts);
verifyEqual(t,height(M),0);verifyEqual(t,height(status),0);
end

function testSearchWindowsMergeClipAndExcludeRejectedStates(t)
start=datetime(2026,12,31,'TimeZone','UTC');finish=start+caldays(1);
z=poc.schema("state");z.HWID="0001";
a=z;a.EpochUTC=start-seconds(5);
b=z;b.EpochUTC=start+seconds(5);
c=z;c.EpochUTC=start+seconds(12);
d=z;d.EpochUTC=finish-seconds(1);
bad=z;bad.EpochUTC=start+hours(12);bad.Status="CONFLICTING_REVISION";
S=poc.toTable([a;b;c;d;bad],"state");
opts=struct('StartUTC',start,'EndUTC',start,'TimeToleranceSeconds',10);
W=poc.quicklook.searchWindows(S,opts);
verifyEqual(t,size(W),[2 2]);
verifyEqual(t,W(1,1),start);
verifyLessThan(t,abs(seconds(W(1,2)-(start+seconds(22)+milliseconds(1)))),1e-6);
verifyEqual(t,W(2,1),finish-seconds(11));
verifyEqual(t,W(2,2),finish);
end

function testSearchWindowZeroToleranceIncludesExactTime(t)
start=datetime(2026,3,2,'TimeZone','UTC');
z=poc.schema("state");z.HWID="0001";z.EpochUTC=start+hours(12);
S=poc.toTable(z,"state");
opts=struct('StartUTC',start,'EndUTC',start,'TimeToleranceSeconds',0);
W=poc.quicklook.searchWindows(S,opts);
verifyEqual(t,size(W),[1 2]);verifyEqual(t,W(1,1),z.EpochUTC);
verifyLessThan(t,abs(seconds(W(1,2)-(z.EpochUTC+milliseconds(1)))),1e-6);
end

function testWindowIDsPreserveMatchingBoundaryAndExcludeOtherTimes(t)
[S,T,R,opts]=fixtures();
% Both 0001 states touch the acquisition at the inclusive tolerance. An
% unrelated satellite's interval overlaps the same merged window; a later
% window has only satellite 0003. Rejected states must not add an ID.
other=S(1,:);other.HWID="0002";other.EpochUTC=opts.StartUTC+seconds(15);
later=other;later.HWID="0003";later.EpochUTC=opts.StartUTC+hours(4);
rejected=other;rejected.HWID="0004";rejected.Status="CONFLICTING_REVISION";
S=[S;other;later;rejected];
W=poc.quicklook.searchWindows(S,opts);
ids=poc.quicklook.searchWindowIDs(W,S,opts);
verifyEqual(t,numel(ids),2);
verifyEqual(t,sort(ids{1}),["0001";"0002"]);
verifyEqual(t,ids{2},"0003");
catalogue=[scene("match","0001","2026-03-02T00:00:00.000Z"); ...
 scene("unrelated","0003","2026-03-02T00:00:00.000Z")];
allMatches=poc.quicklook.matchScenes(catalogue,S,T,R,opts);
filteredMatches=poc.quicklook.matchScenes(catalogue(ismember(catalogue.SatelliteID,ids{1}),:),S,T,R,opts);
verifyEqual(t,filteredMatches,allMatches);
verifyEqual(t,height(filteredMatches),4);
end

function testOfflineReportEscapesMetadataAndHandlesEmptyMatches(t)
[S,T,R,opts]=fixtures();
x=scene("scene<script>&","0001","2026-03-02T00:00:00.000Z");
x.StripID="strip<unsafe>&";
x.QualityCategory="standard<unsafe>&";
[M,status]=poc.quicklook.matchScenes(x,S,T,R,opts);
previews=x;previews.ThumbnailLocalPath="thumbnails/example.png";
previews.ThumbnailStatus="DOWNLOADED";
ArchiveDateUTC=opts.StartUTC;StateArchiveAvailable=true;TLEArchiveAvailable=true;
inventory=struct();
inventory.Daily=table(ArchiveDateUTC,StateArchiveAvailable,TLEArchiveAvailable);
Status=["LOADED";"MISSING"];inventory.Files=table(Status);
inventory.ParseLog=poc.schema("log",true);
inventory.StateCount=height(S);inventory.TLECount=height(T);
stats=struct('Searches',1,'Pages',2);
windows=[opts.StartUTC,opts.StartUTC+seconds(10)];
tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
poc.quicklook.writeReport(tmp,opts,inventory,stats,windows,M,status,previews);
html=string(fileread(fullfile(tmp,'index.html')));
report=string(fileread(fullfile(tmp,'QUICKLOOK_REPORT.md')));
verifyTrue(t,contains(html,"scene&lt;script&gt;&amp;"));
verifyFalse(t,contains(html,"scene<script>&"));
verifyTrue(t,contains(html,"strip&lt;unsafe&gt;&amp;"));
verifyTrue(t,contains(html,"standard&lt;unsafe&gt;&amp;"));
verifyTrue(t,contains(html,'src="thumbnails/example.png"'));
verifyTrue(t,contains(html,'href="matches.csv"'));
verifyTrue(t,contains(html,'href="QUICKLOOK_REPORT.md"'));
verifyTrue(t,contains(report,"| Matched unique scenes | 1 |"));
verifyTrue(t,contains(report,"| Matching scene-state-TLE combinations | 4 |"));
verifyTrue(t,contains(report,"[Preview gallery](index.html)"));

emptyDir=fullfile(tmp,'empty');mkdir(emptyDir);
emptyWindows=NaT(0,2,'TimeZone','UTC');
poc.quicklook.writeReport(emptyDir,opts,inventory,stats,emptyWindows, ...
 M([],:),status([],:),previews([],:));
emptyHTML=string(fileread(fullfile(emptyDir,'index.html')));
emptyReport=string(fileread(fullfile(emptyDir,'QUICKLOOK_REPORT.md')));
verifyTrue(t,contains(emptyHTML,"No matched scenes were found"));
verifyTrue(t,contains(emptyReport,"| Matched unique scenes | 0 |"));
end

function testResultsPersistBeforeAndAfterPreviews(t)
[S,T,R,opts]=fixtures();
x=scene("checkpoint_scene","0001","2026-03-02T00:00:00.000Z");
[M,status]=poc.quicklook.matchScenes(x,S,T,R,opts);
previews=x;previews.ThumbnailLocalPath="";previews.ThumbnailStatus="PENDING";
ArchiveDateUTC=opts.StartUTC;StateArchiveAvailable=true;TLEArchiveAvailable=true;
inventory=struct();
inventory.Daily=table(ArchiveDateUTC,StateArchiveAvailable,TLEArchiveAvailable);
Status="LOADED";inventory.Files=table(Status);
inventory.ParseLog=poc.schema("log",true);
inventory.StateCount=height(S);inventory.TLECount=height(T);
stats=struct('Searches',1,'Pages',1);
windows=[opts.StartUTC,opts.StartUTC+seconds(10)];
tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
result=struct('RunDir',string(tmp),'Options',opts,'SearchStats',stats, ...
 'Matches',M,'Scenes',x,'SceneStatus',status,'Previews',previews, ...
 'ArchiveInventory',inventory);
poc.quicklook.writeResults(result,windows,true);
verifyTrue(t,isfile(fullfile(tmp,'matches.csv')));
verifyTrue(t,isfile(fullfile(tmp,'candidate_scenes.csv')));
verifyTrue(t,isfile(fullfile(tmp,'scene_status.csv')));
verifyTrue(t,isfile(fullfile(tmp,'quicklook_results.mat')));
saved=load(fullfile(tmp,'quicklook_results.mat'),'result');
verifyEqual(t,saved.result.Previews.ThumbnailStatus,"PENDING");
report=string(fileread(fullfile(tmp,'QUICKLOOK_REPORT.md')));
verifyTrue(t,contains(report,"| Previews awaiting download | 1 |"));
verifyTrue(t,contains(string(fileread(fullfile(tmp,'index.html'))),"Preview: PENDING"));

% Finalization preserves the search tables and replaces the preview data.
result.Previews.ThumbnailStatus="DOWNLOADED";
result.Previews.ThumbnailLocalPath="thumbnails/checkpoint_scene.png";
poc.quicklook.writeResults(result,windows,false);
saved=load(fullfile(tmp,'quicklook_results.mat'),'result');
verifyEqual(t,saved.result.Previews.ThumbnailStatus,"DOWNLOADED");
report=string(fileread(fullfile(tmp,'QUICKLOOK_REPORT.md')));
verifyTrue(t,contains(report,"| Downloaded scene previews | 1 |"));
verifyTrue(t,contains(report,"| Previews awaiting download | 0 |"));
verifyTrue(t,contains(string(fileread(fullfile(tmp,'index.html'))), ...
 'src="thumbnails/checkpoint_scene.png"'));
verifyFalse(t,isfile(fullfile(tmp,'quicklook_results_pending.mat')));
end

function testReportGroupsInterleavedMatchesAndFindsPreviews(t)
[S,T,R,opts]=fixtures();
x=scene("scene","0001","2026-03-02T00:00:00.000Z");
[M,status]=poc.quicklook.matchScenes(x,S,T,R,opts);
M=[M;M(1,:)];M.SceneID=["z";"a";"z";"a";"m"];
M.SceneMinusState_s=[101;102;103;104;105];
previews=[x;x;x];previews.SceneID=["z";"a";"z"];
previews.ThumbnailLocalPath=["";"thumbnails/a.png";"thumbnails/duplicate.png"];
previews.ThumbnailStatus=["PENDING";"DOWNLOADED";"DOWNLOADED"];
ArchiveDateUTC=opts.StartUTC;StateArchiveAvailable=true;TLEArchiveAvailable=true;
inventory=struct();
inventory.Daily=table(ArchiveDateUTC,StateArchiveAvailable,TLEArchiveAvailable);
Status="LOADED";inventory.Files=table(Status);
inventory.ParseLog=poc.schema("log",true);
inventory.StateCount=height(S);inventory.TLECount=height(T);
stats=struct('Searches',1,'Pages',1);
tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
poc.quicklook.writeReport(tmp,opts,inventory,stats, ...
 [opts.StartUTC,opts.StartUTC+seconds(10)],M,status,previews);
html=string(fileread(fullfile(tmp,'index.html')));
cardA=extractBetween(html,'<h2>a</h2>','</section>');
cardM=extractBetween(html,'<h2>m</h2>','</section>');
cardZ=extractBetween(html,'<h2>z</h2>','</section>');
verifyTrue(t,contains(cardA,'src="thumbnails/a.png"'));
verifyFalse(t,contains(cardM,'Preview:'));
verifyTrue(t,contains(cardZ,'Preview: PENDING'));
verifyFalse(t,contains(cardZ,'thumbnails/duplicate.png'));
verifyLessThan(t,strfind(cardZ,'<td>101</td>'),strfind(cardZ,'<td>103</td>'));
verifyLessThan(t,strfind(cardA,'<td>102</td>'),strfind(cardA,'<td>104</td>'));
verifyTrue(t,contains(cardM,'1 matching combination(s)'));
end

function testLoaderCoverageConflictAndNoCacheSidecars(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
cfg=study_config("demo");
tmp=tempname;mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
cfg.study.startUTC=datetime(2026,3,1,'TimeZone','UTC');
cfg.study.endUTC=cfg.study.startUTC;
cfg.paths.raw=fullfile(tmp,'raw');cfg.paths.roster=fullfile(cfg.paths.raw,'roster.csv');
poc.testing.makeDemo(cfg);
opts=struct('StartUTC',cfg.study.startUTC,'EndUTC',cfg.study.endUTC, ...
 'RawPath',cfg.paths.raw,'RosterPath',cfg.paths.roster,'TimeToleranceSeconds',10);
[S,T,~,inventory]=poc.quicklook.loadSources(cfg,opts);
verifyEqual(t,height(S),2);verifyEqual(t,height(T),2);
verifyTrue(t,inventory.Daily.StateArchiveAvailable);
verifyTrue(t,inventory.Daily.TLEArchiveAvailable);
source=fullfile(cfg.paths.raw,'planet_20260301.states');
verifyFalse(t,isfile(string(source)+".provenance.json"));
% An invalid historical receipt excludes the source rather than rewriting it.
receipt=string(source)+".receipt.json";
poc.io.writeText(receipt,string(jsonencode(struct('SHA256',repmat('0',1,64)))));
[S,~,~,inventory]=poc.quicklook.loadSources(cfg,opts);
verifyEqual(t,height(S),0);
invalid=inventory.Files.LocalPath==string(source);
verifyEqual(t,inventory.Files.Status(invalid),"INPUT_INVALID");
delete(receipt);
% A different dated copy must not be silently combined with the flat file.
nested=fullfile(cfg.paths.raw,'2026','03');mkdir(nested);
copy=fullfile(nested,'planet_20260301.states');copyfile(source,copy);
fid=fopen(copy,'a');assert(fid>=0);fprintf(fid,'\n# changed copy\n');fclose(fid);
[S,~,~,inventory]=poc.quicklook.loadSources(cfg,opts);
verifyEqual(t,height(S),0);
conflict=inventory.Files.Kind=="state" & ...
 inventory.Files.ArchiveDateUTC==cfg.study.startUTC;
verifyEqual(t,sum(conflict),2);
verifyTrue(t,all(inventory.Files.Status(conflict)=="ARCHIVE_CONFLICT"));
verifyFalse(t,inventory.Daily.StateArchiveAvailable);
end

function x=scene(id,satellite,utc)
f=struct('id',id,'properties',struct('satellite_id',satellite, ...
 'acquired',utc,'strip_id',"strip1"));
x=poc.quicklook.normalizeScenes(f);
end

function [S,T,R,opts]=fixtures
sceneTime=datetime(2026,3,2,'TimeZone','UTC');
s1=poc.schema("state");s1.HWID="0001";s1.RecordID="state-before";
s1.EpochUTC=sceneTime-seconds(10);s1.ArchiveDateUTC=sceneTime;
s2=s1;s2.RecordID="state-after";s2.EpochUTC=sceneTime+seconds(10);
S=poc.toTable([s1;s2],"state");
t1=poc.schema("tle");t1.HeaderHWID="0001";t1.CatalogID="12345";
t1.RecordID="tle-early";t1.EpochUTC=sceneTime+minutes(1);t1.ArchiveDateUTC=sceneTime;
t2=t1;t2.RecordID="tle-late";t2.EpochUTC=sceneTime+hours(23);
t3=t1;t3.RecordID="tle-previous";t3.EpochUTC=sceneTime-seconds(1);
T=poc.toTable([t1;t2;t3],"tle");
Satellite="Known";HWID="0001";CatalogID="12345";
ValidFromUTC=sceneTime-caldays(30);ValidToUTC=sceneTime+caldays(30);
HistoricallyVerified=true;
R=table(Satellite,HWID,CatalogID,ValidFromUTC,ValidToUTC,HistoricallyVerified);
opts=struct('StartUTC',sceneTime,'EndUTC',sceneTime,'TimeToleranceSeconds',10);
end
