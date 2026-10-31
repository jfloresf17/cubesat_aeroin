function t=formatTimeForCSV(t)
%FORMATTIMEFORCSV Preserve subsecond UTC display in exported tables.
% Keep native datetime and int64 TT-nanosecond values in the MAT file as the
% authoritative inputs. Six decimal places make microsecond differences
% readable without implying that the source time is accurate to that level.
for k=1:width(t)
 name=t.Properties.VariableNames{k};v=t.(name);
 if ~isdatetime(v),continue;end
 suffix="";
 if ~isempty(v.TimeZone),v.TimeZone='UTC';suffix="Z";end
 whole=dateshift(v,'start','second');microseconds=round(seconds(v-whole)*1e6);
 rollover=microseconds>=1e6;whole=whole+seconds(rollover);
 microseconds(rollover)=microseconds(rollover)-1e6;
 formatted=strings(size(v));valid=~isnat(v);
 formatted(valid)=string(whole(valid),'yyyy-MM-dd''T''HH:mm:ss')+"."+ ...
  compose('%06d',microseconds(valid))+suffix;
 t.(name)=formatted;
end
end
