function hex=hashText(text)
%HASHTEXT SHA-256 of UTF-8 bytes.
md=java.security.MessageDigest.getInstance('SHA-256');
bytes=unicode2native(char(text),'UTF-8');
md.update(typecast(uint8(bytes(:)),'int8'));
d=typecast(md.digest(),'uint8');
hex=string(lower(reshape(dec2hex(d,2).',1,[])));
end
