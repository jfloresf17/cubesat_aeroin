function writeText(path,text)
%WRITETEXT UTF-8 text, with checked fopen and reliable close.
parent=fileparts(path); if ~isempty(parent)&&~isfolder(parent),mkdir(parent);end
[fid,msg]=fopen(path,'w','n','UTF-8');
assert(fid>=0,'poc:io:Open','%s',msg);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',char(text));
end
