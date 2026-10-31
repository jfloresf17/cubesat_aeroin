function ns=serializationStep(token)
%SERIALIZATIONSTEP Printed decimal spacing, NOT physical timing uncertainty.
t=regexp(char(strtrim(string(token))), ...
 '^[+-]?\d+(?<frac>\.\d*)?(?<expo>[eE][+-]?\d+)?$','names','once');
assert(~isempty(t),'poc:time:Token','Invalid serialized epoch.');
% Unmatched optional named groups may not be present in MATLAB's result.
if ~isfield(t,'frac'),t.frac='';end
if ~isfield(t,'expo'),t.expo='';end
if ~isempty(t.frac),t.frac=t.frac(2:end);end
e=0;if ~isempty(t.expo),e=str2double(t.expo(2:end));end
ns=10^(9+e-length(t.frac));
end
