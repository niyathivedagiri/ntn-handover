%MAIN Intelligent handover for integrated LEO satellite and terrestrial networks.
%
%   Run from the project folder:  main
%
%   Stages:
%     1. Network and mobility model: build the default scenario, summarise
%        it, run sanity checks and draw the scenario plots.
%     2. Baseline handover: strongest SNR with hysteresis and
%        time-to-trigger, plus a sweep over both parameters.
%     3. Proposed handover: multi-criteria score, with a plot that explains
%        one decision term by term.
%     4. Evaluation: both algorithms on identical links over 20 evaluation
%        seeds and five scenario groups, a handover-rate vs capacity
%        trade-off, and a sensitivity / ablation study.
%   Figures and CSV files are written to the results folder.
%
%   Stage 4 takes a few minutes. Set RUN_FULL_EVALUATION = false to skip it.
%   The parameter calibration (calibrate_intelligent) is not repeated here;
%   its selected values are stored in config.m.

clear; close all; clc;
RUN_FULL_EVALUATION = true;
EVAL_SEEDS = 101:120;          % never used for calibration (seeds 1-10)

project_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, fullfile(project_dir, 'src'));
results_dir = fullfile(project_dir, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

%% Configuration
cfg = config();

%% 1. Network, mobility and links
net   = generate_network(cfg);
mob   = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
S = summarise_scenario(cfg, net, mob, links);

fprintf('\n=== Sanity checks ===\n');
never_visible = net.names(net.is_sat & S.visible_s == 0);
if isempty(never_visible)
    fprintf('OK    every configured satellite becomes visible at least once\n');
else
    fprintf('NOTE  satellites never visible (consider removing): %s\n', strjoin(never_visible, ', '));
end
if any(any(links.available & ~links.visible))
    fprintf('ERROR a node is available without being visible\n');
else
    fprintf('OK    available nodes are always visible\n');
end
if all(isnan(links.snr_meas_db(~links.available)))
    fprintf('OK    unavailable nodes carry no measurement (cannot be selected)\n');
else
    fprintf('ERROR an unavailable node carries a measurement\n');
end
fprintf('OK    satellite SNR range when visible: %.1f to %.1f dB\n', ...
    min(min(links.snr_true_db(:, net.is_sat))), max(max(links.snr_true_db(:, net.is_sat))));
fprintf('OK    base-station SNR range when visible: %.1f to %.1f dB\n', ...
    min(min(links.snr_true_db(:, ~net.is_sat))), max(max(links.snr_true_db(:, ~net.is_sat))));
plot_scenario(cfg, net, mob, links, results_dir);

%% 2. Baseline handover
res_base = handover_baseline(cfg, net, links);
summarise_handover(cfg, net, links, res_base);
plot_handover(cfg, net, links, res_base, results_dir, 'baseline_handover');
sweep_baseline_parameters(cfg, net, links, [0 1 2 3 4 6], [0 1 2 4], results_dir);

%% 3. Proposed handover
res_prop = handover_intelligent(cfg, net, links);
summarise_handover(cfg, net, links, res_prop);
plot_handover(cfg, net, links, res_prop, results_dir, 'proposed_handover');
% explain one planned satellite handover (the first 'score' SAT->SAT event)
ev = res_prop.events;
k = find(strcmp({ev.type}, 'score') & net.is_sat(max([ev.from], 1)) & net.is_sat(max([ev.to], 1)), 1);
if isempty(k), k = find(strcmp({ev.type}, 'score'), 1); end
if ~isempty(k)
    plot_decision(cfg, net, links, res_prop, ev(k).t_s + [-90 30], results_dir);
end

% one-scenario comparison with the shared metric definitions
cm = cfg; cm.ho.hysteresis_db = cfg.ho_matched.hysteresis_db; cm.ho.ttt_s = cfg.ho_matched.ttt_s;
mb = evaluate_performance(cfg, net, links, res_base);
mm = evaluate_performance(cfg, net, links, handover_baseline(cm, net, links));
mp = evaluate_performance(cfg, net, links, res_prop);
fprintf('\n=== Default scenario, seed %d: same links, same metrics ===\n', cfg.seed);
fprintf('%-26s %10s %10s %10s\n', 'Metric', 'Baseline', 'Matched', 'Proposed');
rows = {'n_handovers', 'Handovers'; 'n_unnecessary', 'Unnecessary'; 'n_ping_pong', 'Ping-pongs'; ...
        'n_forced', 'Forced'; 'n_failures', 'Failures'; 'outage_s', 'Outage (s)'; ...
        'mean_se_eff', 'Effective SE (b/s/Hz)'; 'interruption_s', 'Interruption (s)'};
for i = 1:size(rows, 1)
    fprintf('%-26s %10.3g %10.3g %10.3g\n', rows{i, 2}, mb.(rows{i, 1}), mm.(rows{i, 1}), mp.(rows{i, 1}));
end

%% 4. Evaluation over seeds and scenarios
if RUN_FULL_EVALUATION
    fprintf('\nRunning the full evaluation (%d seeds per scenario)...\n', numel(EVAL_SEEDS));
    R = run_evaluation(cfg, EVAL_SEEDS, results_dir);
    T = run_tradeoff(cfg, EVAL_SEEDS, results_dir);
    Sens = run_sensitivity(cfg, EVAL_SEEDS, results_dir);
    save(fullfile(results_dir, 'evaluation_results.mat'), 'R', 'T', 'Sens');
end
fprintf('\nFigures and tables saved to %s\n', results_dir);
