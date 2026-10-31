function tests=test_sgp4_smoke
 tests=functiontests(localfunctions);
end
function testWrapperSmoke(t)
 root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'config'),fullfile(root,'utils'));
 assumeTrue(t,ismember(exist('propagateOrbit','file'),[2 3 6]) && ...
  ismember(exist('tleread','file'),[2 3 6]), ...
  'Aerospace Toolbox unavailable: runtime smoke test skipped, not passed.');
 path=[tempname,'.tle'];cleanup=onCleanup(@()delete(path)); %#ok<NASGU>
 text="0 FLOCK 4BE 7 2409"+newline+ ...
 "1 60481U 24149P   26221.03108796  .00000000  00000+0  34456-3 0    03"+newline+ ...
 "2 60481 097.3739 304.6256 0003992 089.3974 100.3268 15.42428719    01"+newline;
 poc.io.writeText(path,text);g=tleread(path);b=g.BStar;
 [r,v]=propagateOrbit(g.Epoch,g,PropModel="sgp4");
 verifyEqual(t,size(r),[3 1]);verifyTrue(t,all(isfinite([r;v])));
 verifyEqual(t,g.BStar,b);verifyGreaterThan(t,norm(r),6e6);
 % This is a wrapper smoke test, NOT an independent SGP4 accuracy verification.
end
