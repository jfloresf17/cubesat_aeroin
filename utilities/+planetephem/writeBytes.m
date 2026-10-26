function writeBytes(path, bytes)
%WRITEBYTES Stage bytes beside the destination, then rename into place.
% SPDX-License-Identifier: MIT
    parent = fileparts(path);
    if ~isfolder(parent)
        mkdir(parent);
    end
    stage = string(tempname(parent));
    removeStage = onCleanup(@() removeIfPresent(stage));
    fid = fopen(stage, 'wb');
    if fid < 0
        error('planetephem:FileWrite', 'Cannot write %s.', stage);
    end
    closeFile = onCleanup(@() fclose(fid));
    count = fwrite(fid, uint8(bytes), 'uint8');
    if count ~= numel(bytes)
        error('planetephem:FileWrite', 'Incomplete write to %s.', stage);
    end
    clear closeFile
    [ok, message] = movefile(stage, path, 'f');
    if ~ok
        error('planetephem:FileWrite', '%s', message);
    end
end

function removeIfPresent(path)
    if isfile(path)
        delete(path);
    end
end
