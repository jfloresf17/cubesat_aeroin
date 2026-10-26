function bytes = readBytes(path)
%READBYTES Read a file without changing encoding, spaces, or line endings.
% SPDX-License-Identifier: MIT
    fid = fopen(path, 'rb');
    if fid < 0
        error('planetephem:FileRead', 'Cannot read %s.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    bytes = fread(fid, Inf, '*uint8');
end
