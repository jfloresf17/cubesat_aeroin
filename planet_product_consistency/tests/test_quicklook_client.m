function tests=test_quicklook_client
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
startup_consistency();
end

function testNormalizesUTCAndPreservesLeadingZeros(t)
f=scene("scene_1","00a1","2026-03-01T20:00:00Z");
f.properties.view_angle=4.2;f.properties.ground_control=true;
f.properties.satellite_azimuth=120.5;
T=poc.quicklook.normalizeScenes(f);
verifyEqual(t,T.SatelliteID,"00a1");
verifyEqual(t,T.AcquiredUTC,datetime(2026,3,1,20,0,0,'TimeZone','UTC'));
verifyEqual(t,T.GroundControl,1);
verifyEqual(t,T.ViewAngle_deg,4.2);
verifyEqual(t,T.MetadataStatus,"OK");
end

function testFractionalAndOffsetTimestamp(t)
a=scene("scene_1","00a1","2026-03-01T20:00:00.123456Z");
b=scene("scene_2","00a1","2026-03-01T22:00:00.123456+02:00");
c=scene("scene_3","00a1","2026-03-01T15:00:00-05:00");
T=poc.quicklook.normalizeScenes({a,b,c});
expected=datetime(2026,3,1,20,0,0,'TimeZone','UTC');
verifyLessThan(t,abs(seconds(T.AcquiredUTC(1)-(expected+seconds(.123456)))),1e-6);
verifyLessThan(t,abs(seconds(T.AcquiredUTC(2)-T.AcquiredUTC(1))),1e-6);
verifyEqual(t,T.AcquiredUTC(3),expected);
end

function testMissingAndMalformedValuesRemainVisible(t)
f=scene("scene_1","00a1","not-a-time");
f.properties=rmfield(f.properties,'satellite_id');
T=poc.quicklook.normalizeScenes(f);
verifyTrue(t,isnat(T.AcquiredUTC));
verifyTrue(t,contains(T.MetadataStatus,"INVALID_ACQUIRED_TIME"));
verifyTrue(t,contains(T.MetadataStatus,"MISSING_SATELLITE_ID"));
verifyTrue(t,isnan(T.GroundControl));
end

function testSceneLinksDoNotPersistQueryCredentials(t)
f=scene("scene_1","00a1","2026-03-01T20:00:00Z");
f.x_links=struct( ...
 'thumbnail',"https://tiles.planet.com/data/v1/item-types/PSScene/items/scene_1/thumb?api_key=SECRET", ...
 'x_self',"https://api.planet.com/data/v1/item-types/PSScene/items/scene_1?token=SECRET");
T=poc.quicklook.normalizeScenes(f);
verifyEqual(t,T.ThumbnailURL,"https://tiles.planet.com/data/v1/item-types/PSScene/items/scene_1/thumb");
verifyEqual(t,T.ItemURL,"https://api.planet.com/data/v1/item-types/PSScene/items/scene_1");
verifyFalse(t,contains(T.ThumbnailURL,"SECRET")||contains(T.ItemURL,"SECRET"));
f.x_links.thumbnail="https://untrusted.example/scene_1/thumb";
T=poc.quicklook.normalizeScenes(f);
verifyEqual(t,T.ThumbnailURL,"");
end

function testThumbnailPathsAndInvalidIDsWithoutNetwork(t)
out=string(tempname);mkdir(fullfile(out,"thumbnails"));
cleanup=onCleanup(@()rmdir(out,'s')); %#ok<NASGU>
imwrite(zeros(2,2,3,'uint8'),fullfile(out,"thumbnails","scene_1.png"));
T=table(["scene_1";"../bad";"scene_1"],'VariableNames',{'SceneID'});
T=poc.quicklook.downloadThumbnails(T,"not-used",out,struct('MaxRetries',0));
verifyEqual(t,T.ThumbnailStatus,["EXISTS";"INVALID_SCENE_ID";"EXISTS"]);
verifyEqual(t,T.ThumbnailLocalPath, ...
 ["thumbnails/scene_1.png";"";"thumbnails/scene_1.png"]);
end

function f=scene(id,satellite,acquired)
f=struct();f.id=id;f.properties=struct('satellite_id',satellite,'acquired',acquired);
end
