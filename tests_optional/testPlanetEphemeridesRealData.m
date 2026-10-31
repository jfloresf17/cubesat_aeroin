function tests = testPlanetEphemeridesRealData
%TESTPLANETEPHEMERIDESREALDATA Optional archived Planet fixture tests.
% Run explicitly: addpath('utilities'); results = runtests('tests_optional');
% Missing independently obtained inputs are reported as assumptions/incomplete.
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

function testRealTLE(testCase)
    t = planetephem.readTLE(source(testCase,'planet_mc_20260901.tle'));
    verifyEqual(testCase,height(t),99);
    verifyTrue(testCase,all(t.ChecksumValid));
    i = find(t.HWID=="24bd");
    verifyEqual(testCase,t.Flock(i),"4q");
    verifyEqual(testCase,t.CatalogID(i),"58320");
    verifyEqual(testCase,t.BStar_raw(i)," 38423-3");
    verifyEqual(testCase,t.BStar(i),0.00038423,'AbsTol',1e-12);
    verifyEqual(testCase,t.IdentitySource(i),"tle-name");
    verifyTrue(testCase,any(t.HWID=="s1"));
end

function testBadChecksum(testCase)
    text = char(source(testCase,'planet_mc_20260901.tle'));
    index = strfind(text,sprintf('\n1 '));
    text(index(1)+69) = '9'; % Position 69 in first element line.
    verifyError(testCase,@() planetephem.readTLE(string(text)), ...
        'planetephem:TLEChecksum');
end

function testTruncatedTLE(testCase)
    lines = splitlines(source(testCase,'planet_mc_20260901.tle'));
    verifyError(testCase,@() planetephem.readTLE(join(lines(1:2),newline)), ...
        'planetephem:TLEFormat');
end

function testTwoLineTLEAndYearPivot(testCase)
    lines = splitlines(source(testCase,'planet_mc_20260901.tle'));
    first = char(lines(2));
    first(19:32) = '57001.00000000';
    first = fixChecksum(first);
    t = planetephem.readTLE(string(first)+newline+lines(3));
    verifyEqual(testCase,t.HWID,"");
    verifyEqual(testCase,year(t.EpochUTC),1957);
    first(19:32) = '56001.00000000';
    t = planetephem.readTLE(string(fixChecksum(first))+newline+lines(3));
    verifyEqual(testCase,year(t.EpochUTC),2056);
end

function testRealStatesAndTimeScale(testCase)
    s = planetephem.readStates(source(testCase,'planet_20260901.states'));
    verifyEqual(testCase,height(s),99);
    i = find(s.HWID=="2409");
    expected = datetime(2026,9,1,18,45,6,'TimeZone','UTCLeapSeconds');
    verifyLessThan(testCase,abs(seconds(s.EpochUTC(i)-expected)),2e-6);
    verifyEqual(testCase,s.EpochTT_text(i),"841560375.184000");
    verifyEqual(testCase,s.X_m(i),-8.428380691179684e5,'RelTol',1e-14);
    verifyTrue(testCase,isinf(s.SRPBC_kg_m2(i)));
end

function testCatalogAndPrimeFlocks(testCase)
    p = fullfile(testCase.TestData.Raw,'metadata','20261025_source', ...
        '18SPCS_matches_v1.txt');
    assumeTrue(testCase,isfile(p),'Optional archived Planet catalogue fixture is unavailable.');
    c = planetephem.readCatalog(fileread(p));
    verifyEqual(testCase,c.CatalogID(c.HWID=="24bd"),"58320");
    verifyEqual(testCase,planetephem.flockFromName("Flock 4e'-7 1234"),"4e'");
    verifyEqual(testCase,planetephem.flockFromName("FLOCK 4BE 7 2409"),"4be");
end

function testOfflineRangeAndGroups(testCase)
    referencePath = fullfile(testCase.TestData.Root,'data','reference','availability.csv');
    assumeTrue(testCase,isfile(referencePath),'Optional independently derived reference CSV is unavailable.');
    seed(testCase);
    a = downloadPlanetEphemerides('2026-09-01','2026-09-03', ...
        'Flock','FLOCK 4Q','ID',{'24bd','24d1'}, ...
        'OutputDirectory',testCase.TestData.Temp,'CacheOnly',true,'Verbose',false);
    verifyEqual(testCase,height(a.TLE),6);
    verifyEqual(testCase,height(a.States),6);
    verifyEqual(testCase,height(a.Groups),2);
    verifyTrue(testCase,all(a.Availability.HasBoth));
    verifyTrue(testCase,a.Summary.Complete);
    verifyEqual(testCase,a.Config.StartDate,"2026-09-01");
    verifyTrue(testCase,isfile(fullfile(a.RunDirectory,'archive.mat')));
    verifyTrue(testCase,isfile(fullfile(a.RunDirectory,'by_flock','4q','24bd','records.tle')));
    verifyTrue(testCase,all(a.States.FlockSource=="tle-archive"));
    verifyTrue(testCase,all(a.Manifest.FromCache));
    verifyTrue(testCase,all(a.Manifest.Attempts==0));
    reference = readtable(referencePath,'TextType','string');
    actual = sortrows(a.Availability,{'HWID','ArchiveDate'});
    reference = sortrows(reference,{'HWID','ArchiveDate'});
    verifyEqual(testCase,actual.NativeEpochSeparation_s, ...
        reference.NativeEpochSeparation_s,'AbsTol',3e-6);
    % Repeated retrieval is a new run, with identical selected source bytes.
    b = downloadPlanetEphemerides("2026-09-01","2026-09-03", ...
        "ID",["24bd","24d1"],"OutputDirectory",testCase.TestData.Temp, ...
        "CacheOnly",true,"Verbose",false);
    verifyNotEqual(testCase,a.RunDirectory,b.RunDirectory);
    verifyEqual(testCase,a.TLE.Line1,b.TLE.Line1);
end

function testCATIDSelection(testCase)
    seed(testCase);
    a = downloadPlanetEphemerides("2026-09-01","2026-09-01", ...
        "ID",58320,"IDType","catid","OutputDirectory",testCase.TestData.Temp, ...
        "CacheOnly",true,"Verbose",false);
    verifyEqual(testCase,a.TLE.HWID,"24bd");
    verifyEqual(testCase,a.States.HWID,"24bd");
    verifyEqual(testCase,a.States.CatalogIDSource,"tle-archive");
end

function testDateSelectionPreservesEpoch(testCase)
    seed(testCase);
    a = downloadPlanetEphemerides("2026-09-01","2026-09-01", ...
        "ID","24bd","OutputDirectory",testCase.TestData.Temp, ...
        "CacheOnly",true,"Verbose",false);
    verifyEqual(testCase,a.TLE.EpochYYDDD,"26244.78135417");
    verifyEqual(testCase,a.TLE.Line1, ...
        "1 58320U 23174BS  26244.78135417  .00000000  00000+0  38423-3 0    04");
    verifyEqual(testCase,a.Availability.NativeEpochSeparation_s,0.000288,'AbsTol',3e-6);
end

function testMissingDayStrictSavesReport(testCase)
    seed(testCase);
    verifyError(testCase,@() downloadPlanetEphemerides("2026-09-01", ...
        "2026-09-04","ID","24bd","OutputDirectory",testCase.TestData.Temp, ...
        "CacheOnly",true,"Strict",true,"Verbose",false), ...
        'planetephem:IncompleteArchive');
    files = dir(fullfile(testCase.TestData.Temp,'runs','*','manifest.csv'));
    verifyEqual(testCase,numel(files),1);
    m = readtable(fullfile(files(1).folder,files(1).name),'TextType','string');
    verifyEqual(testCase,sum(m.Status=="cache-miss"),2);
end

function text = source(testCase,name)
    fixture = fullfile(testCase.TestData.Raw,'daily','2026','09',name);
    assumeTrue(testCase,isfile(fixture),'Optional archived Planet source fixture is unavailable.');
    text = string(fileread(fixture));
end

function seed(testCase)
    assumeTrue(testCase,isfolder(testCase.TestData.Raw), ...
        'Optional archived Planet source fixtures are unavailable.');
    for date = ["20260901","20260902","20260903"]
        for name = ["planet_mc_"+date+".tle","planet_"+date+".states"]
            fixture = fullfile(testCase.TestData.Raw,'daily','2026','09',name);
            assumeTrue(testCase,isfile(fixture),'An optional archived Planet daily fixture is unavailable.');
        end
    end
    for name = ["index.html","18SPCS_matches_v1.txt"]
        fixture = fullfile(testCase.TestData.Raw,'metadata','20261025_source',name);
        assumeTrue(testCase,isfile(fixture),'An optional archived Planet metadata fixture is unavailable.');
    end
    copyfile(testCase.TestData.Raw,fullfile(testCase.TestData.Temp,'raw'));
end

function line = fixChecksum(line)
    prefix = line(1:68);
    digits = prefix>='0' & prefix<='9';
    value = mod(sum(double(prefix(digits))-double('0'))+sum(prefix=='-'),10);
    line(69) = char(double('0')+value);
end
