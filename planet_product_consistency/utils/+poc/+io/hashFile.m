function hex=hashFile(path)
%HASHFILE Stream file bytes through SHA-256.
[fid,msg]=fopen(path,'rb');assert(fid>=0,'poc:io:Open','%s',msg);
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
 bytes=fread(fid,1024*1024,'*uint8');
 if ~isempty(bytes),md.update(typecast(bytes(:),'int8'));end
end
d=typecast(md.digest(),'uint8');
hex=string(lower(reshape(dec2hex(d,2).',1,[])));
end
