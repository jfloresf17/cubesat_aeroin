function id=catalogNumber(token)
%CATALOGNUMBER Decode a numeric/Alpha-5 identifier; keep normalized decimal text.
c=upper(strtrim(char(token)));
if all(isstrprop(c,'digit'))
 id=string(str2double(c));return;
end
alpha='ABCDEFGHJKLMNPQRSTUVWXYZ';
j=find(alpha==c(1),1);
assert(numel(c)==5&&~isempty(j)&&all(isstrprop(c(2:5),'digit')), ...
 'poc:parse:Catalog','Unsupported catalogue token %s.',c);
id=string((j+9)*10000+str2double(c(2:5)));
end
