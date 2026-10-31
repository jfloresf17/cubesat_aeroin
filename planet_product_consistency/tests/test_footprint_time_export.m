function tests=test_footprint_time_export
tests=functiontests(localfunctions);
end

function testFractionalUTCIsVisibleAndOffsetsReproduce(t)
startup_consistency();
state=datetime(2026,3,1,20,46,16,'TimeZone','UTC');
scene=state+seconds(0.484205);
% Values just below the exact microsecond occur in real datetime arithmetic;
% truncating the display would make the CSV disagree with the stored offset.
tle=state-seconds(0.000256000001);
input=table(scene,state,tle,seconds(scene-state),seconds(scene-tle), ...
 'VariableNames',{'AcquiredUTC','StateEpochUTC','TLEEpochUTC','SceneMinusState_s','SceneMinusTLE_s'});
file=[tempname,'.csv'];cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
writetable(poc.footprint.formatTimeForCSV(input),file);
text=string(fileread(file));
verifyTrue(t,contains(text,"2026-03-01T20:46:16.484205Z"));
verifyTrue(t,contains(text,"2026-03-01T20:46:16.000000Z"));
verifyTrue(t,contains(text,"2026-03-01T20:46:15.999744Z"));
verifyEqual(t,seconds(scene-tle),0.484461,'AbsTol',1e-6);
end
