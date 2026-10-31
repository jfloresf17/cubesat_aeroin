function ok=checksumTLE(line)
%CHECKSUMTLE NORAD modulo-10: digits contribute value; '-' contributes one.
c=char(line);ok=false;if numel(c)<69,return;end
if ~isstrprop(c(69),'digit'),return;end
a=c(1:68);digit=a>='0'&a<='9';
check=mod(sum(double(a(digit))-double('0'))+sum(a=='-'),10);
ok=check==str2double(c(69));
end
