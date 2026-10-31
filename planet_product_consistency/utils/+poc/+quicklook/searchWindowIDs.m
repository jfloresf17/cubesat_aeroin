function windowIDs=searchWindowIDs(windows,states,opts)
%SEARCHWINDOWIDS IDs whose state intervals overlap each merged search window.
% This conservative selection preserves every scene/state match within the
% inclusive tolerance while reducing unrelated catalogue candidates. The
% same one-millisecond exclusive-end margin as searchWindows is used.
windowIDs=cell(size(windows,1),1);
usable=states.Status=="OK" & ~isnat(states.EpochUTC);
states=states(usable,:);
lo=states.EpochUTC-seconds(opts.TimeToleranceSeconds);
hi=states.EpochUTC+seconds(opts.TimeToleranceSeconds)+milliseconds(1);
for k=1:size(windows,1)
 overlap=lo<windows(k,2) & hi>windows(k,1);
 windowIDs{k}=unique(lower(states.HWID(overlap)),'stable');
end
end
