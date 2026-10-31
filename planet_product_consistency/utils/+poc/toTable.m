function T=toTable(rows,kind)
%TOTABLE Preserve column types even for zero-row outputs.
if isempty(rows),T=poc.schema(kind,true);else,T=struct2table(rows);end
end
