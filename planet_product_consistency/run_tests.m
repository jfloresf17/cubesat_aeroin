function results = run_tests()
%RUN_TESTS Base-MATLAB utility tests and conditional Aerospace smoke tests.
root = startup_consistency();
addpath(fullfile(root,'utils'));
results = runtests(fullfile(root,'tests'),'IncludeSubfolders',true);
disp(table(results));
assert(~any([results.Failed]),'poc:test:Failure','At least one test failed.');
end
