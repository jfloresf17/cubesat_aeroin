function ns = decimalNs(token)
%DECIMALNS Parse decimal seconds exactly into int64 nanoseconds.
% No large-double multiplication: source sub-millisecond precision is retained.
t=regexp(char(strtrim(string(token))), ...
 '^(?<sign>[+-]?)(?<whole>\d+)(?<frac>\.\d*)?(?<expo>[eE][+-]?\d+)?$', ...
 'names','once');
assert(~isempty(t),'poc:time:Token','Invalid decimal seconds: %s',token);
% MATLAB can omit named fields for optional groups that did not match.
if ~isfield(t,'sign'),t.sign='';end
if ~isfield(t,'frac'),t.frac='';end
if ~isfield(t,'expo'),t.expo='';end
if ~isempty(t.frac),t.frac=t.frac(2:end);end
e=0;if ~isempty(t.expo),e=str2double(t.expo(2:end));end
assert(abs(e)<=20,'poc:time:Range','Exponent outside supported range.');
d=[t.whole,t.frac];shift=9+e-length(t.frac);
if shift<0
 n=-shift;
 assert(n<=length(d)&&all(d(end-n+1:end)=='0'), ...
   'poc:time:SubNanosecond','Nonzero precision finer than one nanosecond.');
 d=d(1:end-n);
else
 d=[d,repmat('0',1,shift)];
end
ns=int64(0);
for k=1:length(d)
 digit=int64(double(d(k))-double('0'));
 assert(ns<=idivide(intmax('int64')-digit,int64(10),'floor'), ...
   'poc:time:Range','Timestamp overflows int64.');
 ns=ns*int64(10)+digit;
end
if strcmp(t.sign,'-'),ns=-ns;end
end
