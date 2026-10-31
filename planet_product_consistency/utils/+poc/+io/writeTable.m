function writeTable(path,T)
%WRITETABLE Preserve exact int64 epochs in MAT; CSV uses decimal strings.
parent=fileparts(path); if ~isfolder(parent),mkdir(parent);end
if width(T)==0
 poc.io.writeText(path,"Status"+newline+"NOT_REQUESTED"+newline);return;
end
C=T;
for k=1:width(C)
 name=C.Properties.VariableNames{k};
 if isa(C.(name),'int64')
  C.(name)=string(C.(name));
 elseif isdatetime(C.(name))
  C.(name).Format='yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSS''Z''';
 end
end
writetable(C,path);
end
