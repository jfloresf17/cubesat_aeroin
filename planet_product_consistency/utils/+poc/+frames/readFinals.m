function E=readFinals(path)
%READFINALS Parse IERS/USNO finals2000A Bulletin-A columns, preserving flags.
% Units: xp/yp arcseconds, dX/dY milliarcseconds, UT1-UTC seconds.
% Column specification: https://maia.usno.navy.mil/ser7/readme.finals2000A
assert(isfile(path),'poc:frame:EOPFile','Missing frozen finals2000A file: %s',path);
lines=splitlines(string(fileread(path)));a=nan(numel(lines),6);flags=strings(numel(lines),1);
for k=1:numel(lines)
 s=char(lines(k));if numel(s)<125,continue;end
 a(k,:)=[str2double(s(8:15)),str2double(s(59:68)), ...
  str2double(s(19:27)),str2double(s(38:46)), ...
  str2double(s(98:106)),str2double(s(117:125))];
 flags(k)=string([s(17),s(58),s(96)]);
end
ok=all(isfinite(a),2);a=a(ok,:);flags=flags(ok);
E=array2table(a,'VariableNames',{'MJD','DUT1_s','xp_arcsec','yp_arcsec','dX_mas','dY_mas'});
E.Flags=flags;E=sortrows(E,'MJD');
assert(height(E)>1&&all(diff(E.MJD)>0),'poc:frame:EOPData','Insufficient/non-unique EOP records.');
end
