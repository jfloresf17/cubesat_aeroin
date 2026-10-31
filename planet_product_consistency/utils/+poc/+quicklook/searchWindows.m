function windows=searchWindows(states,opts)
%SEARCHWINDOWS Union of acquisition windows around usable local states.
% A one-millisecond right margin makes the inclusive tolerance safe when
% expressed as Planet's exclusive upper date boundary. The matcher applies
% the exact requested tolerance after results return.
start=dateshift(opts.StartUTC,'start','day');
finish=dateshift(opts.EndUTC,'start','day')+caldays(1);
states=states(states.Status=="OK" & ~isnat(states.EpochUTC),:);
if isempty(states)
 windows=NaT(0,2,'TimeZone','UTC');return;
end
t=states.EpochUTC;
lo=t-seconds(opts.TimeToleranceSeconds);
hi=t+seconds(opts.TimeToleranceSeconds)+milliseconds(1);
lo(lo<start)=start;hi(hi>finish)=finish;
valid=hi>lo;lo=lo(valid);hi=hi(valid);
if isempty(lo),windows=NaT(0,2,'TimeZone','UTC');return;end
windows=sortrows([lo,hi],1);
merged=NaT(0,2,'TimeZone','UTC');
for k=1:size(windows,1)
 if isempty(merged)||windows(k,1)>merged(end,2)
  merged(end+1,:)=windows(k,:); %#ok<AGROW>
 elseif windows(k,2)>merged(end,2)
  merged(end,2)=windows(k,2);
 end
end
windows=merged;
end
