function value = sha256(bytes)
%SHA256 SHA-256 of bytes, as lowercase hexadecimal (requires MATLAB JVM).
% SPDX-License-Identifier: MIT
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(typecast(uint8(bytes(:)), 'int8'));
    value = lower(join(string(compose('%02x', typecast(digest.digest(), 'uint8'))), ''));
end
