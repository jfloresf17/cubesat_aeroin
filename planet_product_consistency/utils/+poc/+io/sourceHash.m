function hash=sourceHash(root)
%SOURCEHASH Hash project MATLAB source independently of file traversal order.
f=dir(fullfile(root,'**','*.m'));
lines=strings(numel(f),1);
for k=1:numel(f)
 p=fullfile(f(k).folder,f(k).name);
 rel=erase(string(p),string(root)+filesep);
 lines(k)=rel+" "+poc.io.hashFile(p);
end
hash=poc.io.hashText(strjoin(sort(lines),newline));
end
