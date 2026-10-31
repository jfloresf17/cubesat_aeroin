function geom = fromGeoJSON(input)
%FROMGEOJSON Convert GeoJSON Polygon/MultiPolygon to explicit WGS84 rings.
% geom.polygons is a cell array; each polygon is a cell array containing
% one outer [latitude longitude] ring followed by its hole rings. GeoJSON
% coordinates are [longitude latitude]. No centre is used or inferred.
if ischar(input) || (isstring(input) && isscalar(input))
    input = jsondecode(char(input));
end
assert(isstruct(input) && isscalar(input) && isfield(input,'type'), ...
    'poc:footprint:GeoJSON','Expected a GeoJSON geometry object.');
kind=string(input.type);
if kind=="Feature"
    assert(isfield(input,'geometry'),'poc:footprint:GeoJSON','Feature geometry is missing.');
    input=input.geometry;kind=string(input.type);
end
assert(isfield(input,'coordinates') && any(kind==["Polygon","MultiPolygon"]), ...
    'poc:footprint:GeoJSON','Only Polygon and MultiPolygon are supported.');
c=input.coordinates;
if kind=="Polygon"
    polygons={decodePolygon(c)};
elseif isnumeric(c)
    assert(ndims(c)==4 && size(c,4)>=2,'poc:footprint:GeoJSON', ...
        'Unexpected MultiPolygon coordinate shape.');
    polygons=cell(size(c,1),1);
    for j=1:size(c,1)
        rings=cell(size(c,2),1);
        for k=1:size(c,2),rings{k}=decodeRing(squeeze(c(j,k,:,:)));end
        polygons{j}=rings;
    end
elseif iscell(c)
    polygons=cell(numel(c),1);
    for j=1:numel(c),polygons{j}=decodePolygon(c{j});end
else
    error('poc:footprint:GeoJSON','Unsupported coordinate representation.');
end
lat=[];lon=[];
for j=1:numel(polygons)
    for k=1:numel(polygons{j})
        ring=polygons{j}{k};
        lat=[lat;ring(:,1);NaN];lon=[lon;ring(:,2);NaN]; %#ok<AGROW>
    end
end
geom=struct('polygons',{polygons},'lat_deg',lat,'lon_deg',lon);
end

function rings=decodePolygon(c)
if isnumeric(c)
    if ismatrix(c) && size(c,2)>=2
        rings={decodeRing(c)};
    else
        assert(ndims(c)==3 && size(c,3)>=2,'poc:footprint:GeoJSON', ...
            'Unexpected Polygon coordinate shape.');
        rings=cell(size(c,1),1);
        for k=1:size(c,1),rings{k}=decodeRing(squeeze(c(k,:,:)));end
    end
elseif iscell(c)
    rings=cell(numel(c),1);
    for k=1:numel(c),rings{k}=decodeRing(c{k});end
else
    error('poc:footprint:GeoJSON','Unsupported polygon representation.');
end
assert(~isempty(rings),'poc:footprint:GeoJSON','Polygon has no exterior ring.');
end

function ring=decodeRing(c)
if iscell(c)
    try,c=vertcat(c{:});catch,error('poc:footprint:GeoJSON','Invalid ring coordinates.');end
end
assert(isnumeric(c) && ismatrix(c) && size(c,2)>=2 && size(c,1)>=4, ...
    'poc:footprint:GeoJSON','A ring needs at least four coordinate pairs.');
ring=double(c(:,[2 1]));
assert(all(isfinite(ring),'all') && all(abs(ring(:,1))<=90) && ...
    all(abs(ring(:,2))<=180),'poc:footprint:GeoJSON','Invalid WGS84 longitude or latitude.');
assert(all(abs(ring(1,:)-ring(end,:))<1e-10), ...
    'poc:footprint:GeoJSON','GeoJSON rings must be explicitly closed.');
end
