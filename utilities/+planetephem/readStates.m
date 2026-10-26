function records = readStates(text)
%READSTATES Parse Planet .states in native SI units and J2000-TT seconds.
% Inf is valid for unfit ballistic coefficients, including the SRP column.
% EpochTT_text and RawLine retain the source precision and representation.
% SPDX-License-Identifier: MIT
    names = {'HWID','Flock','FlockSource','EpochUTC','EpochTT_s','EpochTT_text', ...
        'X_m','Y_m','Z_m','VX_m_s','VY_m_s','VZ_m_s', ...
        'DragBC_kg_m2','SRPBC_kg_m2','RawLine','SourceLine'};
    types = [{'string','string','string','datetime','double','string'}, ...
        repmat({'double'},1,8), {'string','double'}];
    records = table('Size',[0 numel(names)],'VariableTypes',types, ...
        'VariableNames',names);
    records.EpochUTC.TimeZone = 'UTCLeapSeconds';
    records.EpochUTC.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSSSSS''Z''';
    lines = splitlines(string(text));
    for k = 1:numel(lines)
        line = strtrim(lines(k));
        if strlength(line) == 0 || startsWith(line, '#')
            continue
        end
        fields = split(line);
        if numel(fields) ~= 10 || isempty(regexpi(char(fields(1)), ...
                '^(?:[0-9a-f]{4}|s[0-9]+)$','once'))
            error('planetephem:StateFormat', 'Invalid state at line %d.', k);
        end
        values = str2double(fields(2:10));
        if any(~isfinite(values(1:7))) || any(isnan(values(8:9))) || ...
                any(values(8:9) <= 0) || abs(values(1)) > 9e9
            error('planetephem:StateFormat', 'Invalid state numbers at line %d.', k);
        end
        % MathWorks TT2000 is nanoseconds since 2000-01-01 12:00:00 TT.
        % A UTC noon origin or a fixed present-day TT-UTC offset is incorrect.
        tt2000 = int64(round(values(1) * 1e9));
        epoch = datetime(tt2000,'ConvertFrom','tt2000','TimeZone','UTCLeapSeconds');
        records(end+1,:) = [{lower(fields(1)), "unassigned", "unresolved", ...
            epoch, values(1), fields(2)}, num2cell(values(2:9).'), ...
            {lines(k), k}];
    end
    if isempty(records) && strlength(strtrim(string(text)))>0
        error('planetephem:StateFormat','Nonempty source has no state records.');
    end
end
