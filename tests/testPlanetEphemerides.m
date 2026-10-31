function tests = testPlanetEphemerides
%TESTPLANETEPHEMERIDES Offline parser, cache, transport and integration tests.
% Run from the repository root: addpath('utilities'); results = runtests('tests'); assertSuccess(results)
% SPDX-License-Identifier: MIT
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.TestData.Root = root;
    testCase.TestData.PreviousPath = path;
    addpath(fullfile(root,'utilities'));
    testCase.TestData.Raw = fullfile(root,'data','planet_ephemerides','raw');
end

function teardownOnce(testCase)
    path(testCase.TestData.PreviousPath);
end

function setup(testCase)
    folder = string(tempname);
    mkdir(folder);
    testCase.TestData.Temp = folder;
end

function teardown(testCase)
    if isfolder(testCase.TestData.Temp)
        rmdir(testCase.TestData.Temp,'s');
    end
end

function testSyntheticTLEParserAndChecksum(testCase)
    % Entirely artificial records: no archived Planet input is required.
    first = fixChecksum('1 99999U 24001A   26001.50000000  .00000000  00000-0  00000-0 0  9990');
    secondLine = fixChecksum('2 99999  97.1234 123.4567 0012345  10.0000 350.0000 15.00000000123450');
    text = "Flock 4q-1 1234" + newline + string(first) + newline + string(secondLine);
    t = planetephem.readTLE(text);
    verifyEqual(testCase,height(t),1);
    verifyEqual(testCase,t.HWID,"1234");
    verifyEqual(testCase,t.CatalogID,"99999");
    verifyEqual(testCase,t.EpochYYDDD,"26001.50000000");
    verifyEqual(testCase,t.MeanMotion_rev_day,15,'AbsTol',1e-10);
    verifyTrue(testCase,t.ChecksumValid);
    bad = first;
    bad(69) = char(double('0') + mod(str2double(first(69))+1,10));
    verifyError(testCase,@() planetephem.readTLE(string(bad)+newline+string(secondLine)), ...
        'planetephem:TLEChecksum');
end

function testSyntheticTruncationAndYearPivot(testCase)
    first = fixChecksum('1 99999U 24001A   26001.50000000  .00000000  00000-0  00000-0 0  9990');
    secondLine = fixChecksum('2 99999  97.1234 123.4567 0012345  10.0000 350.0000 15.00000000123450');
    verifyError(testCase,@() planetephem.readTLE(string(first)), ...
        'planetephem:TLEFormat');
    first(19:32) = '57001.00000000';
    t = planetephem.readTLE(string(fixChecksum(first))+newline+string(secondLine));
    verifyEqual(testCase,year(t.EpochUTC),1957);
    first(19:32) = '56001.00000000';
    t = planetephem.readTLE(string(fixChecksum(first))+newline+string(secondLine));
    verifyEqual(testCase,year(t.EpochUTC),2056);
end

function testSyntheticOfflineCache(testCase)
    % Exercise the downloader's offline cache and identity match using only
    % artificial inputs written to this test's temporary directory.
    first = fixChecksum('1 99999U 24001A   26001.50000000  .00000000  00000-0  00000-0 0  9990');
    secondLine = fixChecksum('2 99999  97.1234 123.4567 0012345  10.0000 350.0000 15.00000000123450');
    daily = fullfile(testCase.TestData.Temp,'raw','daily','2026','01');
    metadata = fullfile(testCase.TestData.Temp,'synthetic-metadata');
    mkdir(daily); mkdir(metadata);
    planetephem.writeBytes(fullfile(daily,'planet_mc_20260101.tle'), ...
        unicode2native(char("Flock 4q-1 1234"+newline+string(first)+newline+string(secondLine)+newline),'UTF-8'));
    planetephem.writeBytes(fullfile(daily,'planet_20260101.states'), ...
        unicode2native(char("1234 820540869.184 7000000 0 0 0 7500 0 40 inf"+newline),'UTF-8'));
    planetephem.writeBytes(fullfile(metadata,'index.html'),uint8('Synthetic test metadata'));
    catalog = "1234  Flock 4q-1 1234  SYNTH  99999  0.1  1  YES  YES  99999  99999";
    planetephem.writeBytes(fullfile(metadata,'18SPCS_matches_v1.txt'), ...
        unicode2native(char(catalog+newline),'UTF-8'));
    a = downloadPlanetEphemerides('2026-01-01','2026-01-01', ...
        'ID','1234','OutputDirectory',testCase.TestData.Temp, ...
        'MetadataDirectory',metadata,'CacheOnly',true,'Verbose',false);
    verifyEqual(testCase,height(a.TLE),1);
    verifyEqual(testCase,height(a.States),1);
    verifyEqual(testCase,a.TLE.HWID,"1234");
    verifyEqual(testCase,a.States.HWID,"1234");
    verifyTrue(testCase,a.Availability.HasBoth);
    verifyLessThan(testCase,abs(seconds(a.TLE.EpochUTC-a.States.EpochUTC)),2e-6);
    verifyTrue(testCase,all(a.Manifest.FromCache));
    verifyTrue(testCase,a.Summary.Complete);
end

function testPrimeFlocksWithoutFixtures(testCase)
    verifyEqual(testCase,planetephem.flockFromName("Flock 4e'-7 1234"),"4e'");
    verifyEqual(testCase,planetephem.flockFromName("FLOCK 4BE 7 2409"),"4be");
end

function testJ2000TTOrigin(testCase)
    s = planetephem.readStates("24bd 0 7000000 0 0 0 7500 0 40 inf");
    expected = datetime(2000,1,1,11,58,55.816,'TimeZone','UTCLeapSeconds');
    verifyLessThan(testCase,abs(seconds(s.EpochUTC-expected)),1e-8);
end

function testLeadingZeroHWID(testCase)
    s = planetephem.readStates("0711 841560375.184000 7000000 0 0 0 7500 0 40 inf");
    verifyEqual(testCase,s.HWID,"0711");
end

function testLeapSecond(testCase)
    s = planetephem.readStates("24bd 536500868.184000 7000000 0 0 0 7500 0 40 inf");
    verifyEqual(testCase,year(s.EpochUTC),2016);
    verifyEqual(testCase,month(s.EpochUTC),12);
    verifyEqual(testCase,day(s.EpochUTC),31);
    verifyEqual(testCase,second(s.EpochUTC),60,'AbsTol',2e-6);
end

function testRejectInvalidState(testCase)
    verifyError(testCase,@() planetephem.readStates( ...
        "24bd 841560375.184 NaN 0 0 0 7500 0 40 inf"), ...
        'planetephem:StateFormat');
    verifyError(testCase,@() planetephem.readStates("<html>error</html>"), ...
        'planetephem:StateFormat');
end

function testSHA256KnownVector(testCase)
    value = planetephem.sha256(uint8('abc'));
    verifyEqual(testCase,value, ...
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
end

function testInvalidSelectorsAndDates(testCase)
    verifyError(testCase,@() downloadPlanetEphemerides("2026-09-03", ...
        "2026-09-01"),'planetephem:DateOrder');
    verifyError(testCase,@() downloadPlanetEphemerides("2026-02-30", ...
        "2026-03-01"),'planetephem:InvalidDate');
    verifyError(testCase,@() downloadPlanetEphemerides("2026-09-01", ...
        "2026-09-01","ID","58320"),'planetephem:InvalidSelector');
    verifyError(testCase,@() downloadPlanetEphemerides("2026-09-01", ...
        "2026-09-01","Flock",["all","4q"]),'planetephem:InvalidSelector');
end

function testRetryAndNoErrorBodyCached(testCase)
    calls = 0;
    options = fetchOptions();
    options.Transport = @transport;
    target = fullfile(testCase.TestData.Temp,'test.txt');
    [bytes,r] = planetephem.fetch("https://example.invalid/test",target,options);
    verifyEqual(testCase,calls,2);
    verifyEqual(testCase,r.Attempts,2);
    verifyEqual(testCase,r.Status,"downloaded");
    verifyEqual(testCase,char(bytes.'),'good');
    function [status,bytes,retryAfter] = transport(~,~)
        calls = calls+1;
        status = 503;
        bytes = uint8('temporary server error');
        retryAfter = "0";
        if calls==2
            status = 200;
            bytes = uint8('good');
        end
    end
end

function test404IsNotRetried(testCase)
    options = fetchOptions();
    options.Transport = @(~,~) deal(404,uint8('not found'),"");
    target = fullfile(testCase.TestData.Temp,'missing.tle');
    [bytes,r] = planetephem.fetch("https://example.invalid/file",target,options);
    verifyEmpty(testCase,bytes);
    verifyEqual(testCase,r.Status,"missing");
    verifyEqual(testCase,r.Attempts,1);
    verifyFalse(testCase,isfile(target));
end

function testInvalid200BodyIsNotCached(testCase)
    options = fetchOptions();
    options.Transport = @(~,~) deal(200,uint8('<html>bad gateway</html>'),"");
    options.Validator = @planetephem.readTLE;
    target = fullfile(testCase.TestData.Temp,'invalid.tle');
    [bytes,r] = planetephem.fetch("https://example.invalid/file",target,options);
    verifyEmpty(testCase,bytes);
    verifyEqual(testCase,r.Status,"invalid-content");
    verifyFalse(testCase,isfile(target));
end

function testCacheIntegrity(testCase)
    options = fetchOptions();
    options.Transport = @(~,~) deal(200,uint8('original'),"");
    target = fullfile(testCase.TestData.Temp,'cached.txt');
    planetephem.fetch("https://example.invalid/file",target,options);
    planetephem.writeBytes(target,uint8('changed'));
    options.CacheOnly = true;
    [bytes,r] = planetephem.fetch("https://example.invalid/file",target,options);
    verifyEmpty(testCase,bytes);
    verifyEqual(testCase,r.Status,"cache-invalid");
end

function testForcedRefreshPreservesVersion(testCase)
    options = fetchOptions();
    options.Transport = @(~,~) deal(200,uint8('original'),"");
    target = fullfile(testCase.TestData.Temp,'versioned.txt');
    planetephem.fetch("https://example.invalid/file",target,options);
    options.UseCache = false;
    options.Transport = @(~,~) deal(200,uint8('updated'),"");
    planetephem.fetch("https://example.invalid/file",target,options);
    original = fullfile(testCase.TestData.Temp,'.versions', ...
        planetephem.sha256(uint8('original')),'versioned.txt');
    verifyTrue(testCase,isfile(original));
    verifyEqual(testCase,char(planetephem.readBytes(original).'),'original');
end

function options = fetchOptions()
    options = struct('UseCache',true,'CacheOnly',false,'MaxAttempts',3, ...
        'Timeout',1,'RetryPause',0);
end

function line = fixChecksum(line)
    prefix = line(1:68);
    digits = prefix>='0' & prefix<='9';
    value = mod(sum(double(prefix(digits))-double('0'))+sum(prefix=='-'),10);
    line(69) = char(double('0')+value);
end
