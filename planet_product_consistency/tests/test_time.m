function tests=test_time
 tests=functiontests(localfunctions);
end
function setupOnce(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 c=study_config("demo");t.TestData.L=poc.time.readLeaps(c.paths.leaps,c.time.validThroughUTC);
end
function testExactDecimal(t)
 n=poc.time.decimalNs("843849976.184000");
 verifyEqual(t,n,int64(843849976)*int64(1000000000)+int64(184000000));
 verifyEqual(t,poc.time.decimalNs("-0.000000001"),int64(-1));
 verifyEqual(t,poc.time.decimalNs("1.234e2"),int64(123400000000));
 verifyEqual(t,poc.time.decimalNs("7"),int64(7000000000));
 verifyEqual(t,poc.time.decimalNs("1e-9"),int64(1));
 verifyEqual(t,poc.time.decimalNs("+12.5E+1"),int64(125000000000));
 verifyError(t,@()poc.time.decimalNs("0.0000000001"),'poc:time:SubNanosecond');
end
function testSerializationStepOptionalGroups(t)
 verifyEqual(t,poc.time.serializationStep("7"),1e9);
 verifyEqual(t,poc.time.serializationStep("1.2300"),1e5);
 verifyEqual(t,poc.time.serializationStep("1e-9"),1);
 verifyEqual(t,poc.time.serializationStep("1.2300e2"),1e7);
end
function testOrigin(t)
 u=poc.time.ttToUTC(int64(0),t.TestData.L);
 expected=datetime(2000,1,1,11,58,55.816,'TimeZone','UTC');
 verifyLessThan(t,abs(seconds(u-expected)),1e-6);
 verifyLessThanOrEqual(t,abs(poc.time.utcToTTns(u,t.TestData.L)),int64(1000));
end
function testTleIncrement(t)
 L=t.TestData.L;
 a=poc.time.tleEpoch("26060.00000000",L);b=poc.time.tleEpoch("26060.00000001",L);
 verifyEqual(t,b-a,int64(864000));
 u=poc.time.ttToUTC(a,L);verifyEqual(t,u,datetime(2026,3,1,'TimeZone','UTC'));
end
function testLeapBoundary(t)
 L=t.TestData.L;
 before=poc.time.utcToTTns(datetime(2016,12,31,23,59,59,'TimeZone','UTC'),L);
 after=poc.time.utcToTTns(datetime(2017,1,1,'TimeZone','UTC'),L);
 verifyEqual(t,after-before,int64(2000000000));
 verifyError(t,@()poc.time.ttToUTC(after-int64(500000000),L),'poc:time:LeapSecondInstant');
end
function testRoundTrip(t)
 ns=poc.time.decimalNs("843849976.184000");L=t.TestData.L;
 % Current default leap-table validity ends 2 September; extend only for this known 2017+ unit case.
 L.validThroughUTC=datetime(2026,12,31,'TimeZone','UTC');
 a=poc.time.utcToTTns(poc.time.ttToUTC(ns,L),L);
 verifyLessThanOrEqual(t,abs(a-ns),int64(10000));
end
