function root = startup_consistency()
%STARTUP_CONSISTENCY Add only project entry points and package parent to path.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'config'),fullfile(root,'scripts'),fullfile(root,'utils'));
end
