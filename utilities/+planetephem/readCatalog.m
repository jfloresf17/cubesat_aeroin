function catalog = readCatalog(text)
%READCATALOG Parse Planet's fixed-column matching report using column gaps.
% Names contain single spaces; columns are separated by at least two spaces.
% This snapshot is supporting metadata, not a historical identity authority.
% SPDX-License-Identifier: MIT
    names = {'HWID','Flock','PlanetName','SPCSName','CatalogID', ...
        'RMS_km_raw','Matches_raw','CorrectName_raw','Catalogued_raw', ...
        'TemporaryCatalogID','SupplementalCatalogID'};
    catalog = table('Size', [0 numel(names)], ...
        'VariableTypes', repmat({'string'}, 1, numel(names)), ...
        'VariableNames', names);
    lines = splitlines(string(text));
    for k = 1:numel(lines)
        line = strtrim(lines(k));
        if strlength(line) == 0 || startsWith(line, '#')
            continue
        end
        fields = string(regexp(char(line), '\s{2,}', 'split'));
        if numel(fields) ~= 10
            error('planetephem:CatalogFormat', ...
                'Matching report line %d has %d columns; expected 10.', ...
                k, numel(fields));
        end
        if isempty(regexpi(char(fields(1)), ...
                '^(?:[0-9a-f]{4}|s[0-9]+)$', 'once'))
            error('planetephem:CatalogFormat', 'Invalid HWID at line %d.', k);
        end
        catalog(end+1,:) = [{lower(fields(1)), ...
            planetephem.flockFromName(fields(2))}, num2cell(fields(2:10))];
    end
    if isempty(catalog) || numel(unique(catalog.HWID)) ~= height(catalog)
        error('planetephem:CatalogFormat', 'Empty report or duplicate HWIDs.');
    end
end
