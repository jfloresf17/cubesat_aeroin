function flock = flockFromName(name)
%FLOCKFROMNAME Extract the complete flock token, including a prime suffix.
% SPDX-License-Identifier: MIT
    token = regexpi(char(name), 'FLOCK\s+([A-Z0-9'']+)(?:[ -]|$)', ...
        'tokens', 'once');
    flock = "unassigned";
    if ~isempty(token)
        flock = lower(string(token{1}));
    elseif contains(upper(string(name)), "SKYSAT")
        flock = "skysat";
    elseif contains(upper(string(name)), "RAPIDEYE")
        flock = "rapideye";
    end
end
