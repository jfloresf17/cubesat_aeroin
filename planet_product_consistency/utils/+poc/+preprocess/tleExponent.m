function x=tleExponent(field)
%TLEEXPONENT Read the implied decimal plus signed exponent, e.g. ' 34456-3'.
c=char(field);assert(numel(c)==8,'poc:parse:BStar','Expected eight characters.');
assert(ismember(c(1),[' ','+','-'])&&all(isstrprop(c(2:6),'digit')) ...
 &&ismember(c(7),['+','-'])&&isstrprop(c(8),'digit'), ...
 'poc:parse:BStar','Invalid TLE exponent field.');
s=1;if c(1)=='-',s=-1;end
x=s*str2double(c(2:6))*1e-5*10^str2double(c(7:8));
end
