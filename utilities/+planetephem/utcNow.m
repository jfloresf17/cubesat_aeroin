function value = utcNow()
%UTCNOW ISO 8601 retrieval timestamp; distinct from any orbital epoch.
% SPDX-License-Identifier: MIT
    value = string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
