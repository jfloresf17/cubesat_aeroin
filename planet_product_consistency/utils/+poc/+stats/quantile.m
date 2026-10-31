function q=quantile(x,p,w)
%QUANTILE Type-7 empirical quantile with optional integer replication weights.
% h=1+(N-1)*p. No Statistics Toolbox needed. This convention is documented.
x=x(:);if nargin<3,w=ones(size(x));else,w=w(:);end
assert(numel(w)==numel(x)&&all(w>=0)&all(w==floor(w)), ...
 'poc:stats:Weights','Quantile weights must be nonnegative integer counts.');
ok=w>0; x=x(ok);w=w(ok);
if isempty(x),q=NaN;return;end
assert(all(isfinite(x)),'poc:stats:Finite','Nonfinite retained quantile input.');
assert(isscalar(p)&&p>=0&&p<=1,'poc:stats:Quantile','p must be in [0,1].');
[x,j]=sort(x);w=w(j);cum=cumsum(w);n=sum(w);
h=1+(n-1)*p;lo=floor(h);hi=ceil(h);
a=x(find(cum>=lo,1));b=x(find(cum>=hi,1));
q=a+(h-lo)*(b-a);
end
