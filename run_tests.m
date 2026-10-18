%RUN_TESTS Run every check in the tests folder and report the outcome.
%   In the MATLAB Command Window, from the project folder:  run_tests

project_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, fullfile(project_dir, 'src'), fullfile(project_dir, 'tests'));

fprintf('\nNetwork and mobility model\n');
r = test_network_model();

fprintf('\nBaseline handover\n');
r = [r, test_handover_baseline()];

fprintf('\nIntelligent handover\n');
r = [r, test_handover_intelligent()];

fprintf('\nPerformance metrics\n');
r = [r, test_evaluate_performance()];

fprintf('\nEdge cases\n');
r = [r, test_edge_cases()];

n_fail = sum(~[r.passed]);
fprintf('\n%d of %d checks passed.\n', numel(r) - n_fail, numel(r));
if n_fail > 0
    error('run_tests:failed', '%d check(s) failed.', n_fail);
end
