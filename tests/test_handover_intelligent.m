function results = test_handover_intelligent()
%TEST_HANDOVER_INTELLIGENT Checks for the multi-criteria algorithm.
%
%   Synthetic cases show how the decision responds to link quality,
%   predicted deterioration, satellite visibility and switching penalties;
%   the last check runs on the full scenario.

checks = { ...
    @check_window_stats_on_clean_line, ...
    @check_quality_term_saturates, ...
    @check_ignores_marginal_gain_at_high_snr, ...
    @check_switches_on_clear_gain_after_confirmation, ...
    @check_switching_penalty_blocks_small_gain, ...
    @check_prediction_switches_earlier, ...
    @check_leaves_setting_satellite_before_it_sets, ...
    @check_return_penalty_discourages_ping_pong, ...
    @check_forced_handover_and_link_loss, ...
    @check_full_scenario_consistency };

results = struct('name', {}, 'passed', {}, 'message', {});
for k = 1:numel(checks)
    name = func2str(checks{k});
    try
        checks{k}();
        results(end+1) = struct('name', name, 'passed', true, 'message', ''); %#ok<AGROW>
        fprintf('  PASS  %s\n', name);
    catch err
        results(end+1) = struct('name', name, 'passed', false, 'message', err.message); %#ok<AGROW>
        fprintf('  FAIL  %s\n        %s\n', name, err.message);
    end
end
end

%% ---------------------------------------------------------------------
function check_window_stats_on_clean_line()
T = 30; t = (1:T)';
M = [10 + 0.5 * t, 20 - 2 * t];
A = true(size(M));
[level, slope, n, se] = window_stats(M, A, 3, 10, 1);
assert(max(abs(slope(10:end, 1) - 0.5)) < 1e-9, 'Slope of a clean line not recovered');
assert(max(abs(slope(10:end, 2) + 2)) < 1e-9, 'Negative slope not recovered');
assert(max(abs(level(20, :) - mean(M(18:20, :), 1))) < 1e-9, 'Level is not the 3-sample mean');
assert(all(n(10:end, 1) == 10), 'Window count wrong');
assert(max(max(se(10:end, :))) < 1e-6, 'Clean line should have ~zero slope error');
end

function check_quality_term_saturates()
% q(18 dB) is close to 1 and q(30 dB) = 1 exactly: above about 18 dB more
% SNR adds nothing, so the algorithm sees no reason to switch for it.
[cfg, net, links] = synthetic([18 30 0 -10] .* ones(5, 1), true(5, 4), false(1, 4));
F = handover_features(cfg, net, links);
q = F.q_now(5, :);
assert(q(2) == 1 && q(1) > 0.99, 'Quality term should saturate near 18 dB');
assert(q(3) > 0 && q(3) < 0.2, 'q(0 dB) should be small but positive');
assert(q(4) == 0, 'Below the access threshold q must be 0');
end

function check_ignores_marginal_gain_at_high_snr()
% Two base stations at 25 dB and 27 dB: a strongest-signal rule with
% HYS < 2 dB switches; the intelligent algorithm must not, because both
% links already give the maximum spectral efficiency.
T = 60;
M = [25 * ones(T, 1), 20 * ones(T, 1)];
M(11:end, 2) = 27;
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
r = handover_intelligent(cfg, net, links);
assert(all(r.serving == 1), 'Switched for a gain with no capacity benefit');
cfg.ho.hysteresis_db = 1; cfg.ho.ttt_s = 2;
rb = handover_baseline(cfg, net, links);
assert(rb.n_handovers == 1, 'Reference: baseline with HYS 1 dB should switch');
end

function check_switches_on_clear_gain_after_confirmation()
% Serving node falls from 15 dB to 2 dB at step 31; the other node is
% steady at 15 dB. The switch must come only after the advantage has held
% for confirm_s (2 samples at confirm_s = 1 s).
T = 60;
M = [15 * ones(T, 1), 14 * ones(T, 1)];
M(31:end, 1) = 2;
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.intel.confirm_s = 1;
r = handover_intelligent(cfg, net, links);
k = find(r.serving == 2, 1);
assert(~isempty(k), 'Never switched despite a 12 dB loss');
assert(k >= 32, 'Switched before the advantage was confirmed (step %d)', k);
assert(k <= 36, 'Switched too late (step %d)', k);
assert(r.n_handovers == 1, 'Expected exactly one handover, got %d', r.n_handovers);
end

function check_switching_penalty_blocks_small_gain()
% A modest gain (8 dB -> 10 dB on the other node) is taken when switching
% is free but blocked when the switching cost exceeds it.
T = 60;
M = [8 * ones(T, 1), 6 * ones(T, 1)];
M(11:end, 2) = 10;
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.intel.w_quality = 1; cfg.intel.w_prediction = 0; cfg.intel.w_remaining = 0;
cfg.intel.margin = 0;
cfg.intel.cost_switch = 0;
r0 = handover_intelligent(cfg, net, links);
cfg.intel.cost_switch = 0.2;
r1 = handover_intelligent(cfg, net, links);
F = handover_features(cfg, net, links);
gain = F.q_now(30, 2) - F.q_now(30, 1);
assert(gain > 0 && gain < 0.2, 'Test set-up: gain %.3f should be between 0 and the cost', gain);
assert(r0.n_handovers == 1, 'Free switching should take the gain');
assert(r1.n_handovers == 0, 'Switching cost should block a gain smaller than itself');
end

function check_prediction_switches_earlier()
% Serving node declines steadily by 1 dB/s from 16 dB; the other node is
% steady at 9 dB. With the prediction term the switch happens before the
% two current levels cross; without it, later.
T = 40; t = (1:T)';
M = [16 - max(t - 5, 0), 9 * ones(T, 1)];
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.intel.margin = 0.02; cfg.intel.cost_switch = 0.05; cfg.intel.cost_system = 0;
cfg.intel.w_quality = 0.5; cfg.intel.w_prediction = 0.5; cfg.intel.w_remaining = 0;
r_pred = handover_intelligent(cfg, net, links);
cfg.intel.w_quality = 1; cfg.intel.w_prediction = 0;
r_now = handover_intelligent(cfg, net, links);
k_pred = find(r_pred.serving == 2, 1);
k_now  = find(r_now.serving == 2, 1);
assert(~isempty(k_pred) && ~isempty(k_now), 'Both variants should eventually switch');
assert(k_pred < k_now, 'Prediction should switch earlier (pred %d, now %d)', k_pred, k_now);
end

function check_leaves_setting_satellite_before_it_sets()
% Serving satellite 1 is stronger (14 dB) but sets at step 100. Satellite 2
% is weaker (11 dB) but stays visible. The intelligent algorithm moves to
% satellite 2 before step 100 (planned handover); the baseline waits and
% is forced to switch at step 100.
T = 160;
M = [14 * ones(T, 1), 11 * ones(T, 1)];
V = true(size(M)); V(100:end, 1) = false;
[cfg, net, links] = synthetic(M, V, [true true]);
r = handover_intelligent(cfg, net, links);
types = {r.events.type};
assert(~any(strcmp(types, 'forced')), 'Intelligent algorithm was forced off the setting satellite');
k = find(r.serving == 2, 1);
assert(~isempty(k) && k < 100, 'Did not move before the satellite set');
rb = handover_baseline(cfg, net, links);
assert(any(strcmp({rb.events.type}, 'forced')), 'Reference: baseline should need a forced handover');
end

function check_return_penalty_discourages_ping_pong()
% After switching A -> B, A becomes better again for a few seconds,
% shortly after the user left it. Without the return penalty the user
% goes back and then leaves again (a ping-pong); with it the user stays.
T = 80;
M = [15 * ones(T, 1), 4 * ones(T, 1)];
M(21:end, 1) = 3;  M(21:end, 2) = 15;     % A collapses, B recovers
M(27:32, 1) = 17;  M(27:32, 2) = 9;       % A briefly better again,
                                          % within return_window_s
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.intel.w_quality = 1; cfg.intel.w_prediction = 0; cfg.intel.w_remaining = 0;
cfg.intel.cost_switch = 0.05; cfg.intel.margin = 0.02;
cfg.intel.cost_return = 0;
r0 = handover_intelligent(cfg, net, links);
cfg.intel.cost_return = 0.5;
r1 = handover_intelligent(cfg, net, links);
assert(r0.n_handovers == 3, 'Without the penalty expected A->B->A->B, got %d handovers', r0.n_handovers);
assert(r1.n_handovers == 1, 'With the penalty expected only A->B, got %d handovers', r1.n_handovers);
end

function check_forced_handover_and_link_loss()
% Node 1 disappears at step 20 -> forced handover to node 2. Node 2
% disappears at step 40 and nothing is left -> link loss, then
% re-establishment on node 1 at step 50.
T = 60;
M = [12 * ones(T, 1), 10 * ones(T, 1)];
A = true(size(M));
A(20:49, 1) = false; A(40:end, 2) = false;
[cfg, net, links] = synthetic(M, A, [false false]);
r = handover_intelligent(cfg, net, links);
assert(all(r.serving(20:39) == 2), 'Forced handover to node 2 missing');
assert(all(r.serving(40:49) == 0), 'Should be unserved with no node available');
assert(r.serving(50) == 1, 'Should re-establish on node 1');
assert(isequal({r.events.type}, {'initial', 'forced', 'rlf', 'reestablish'}), ...
    'Unexpected events: %s', strjoin({r.events.type}, ','));
end

function check_full_scenario_consistency()
cfg = config();
net = generate_network(cfg);
links = simulate_links(cfg, net, simulate_mobility(cfg));
r = handover_intelligent(cfg, net, links);
k = find(r.serving > 0);
ok = links.available(sub2ind(size(links.available), k, r.serving(k)));
assert(all(ok), 'Serving an unavailable node at %d steps', sum(~ok));
changes = sum(diff(r.serving) ~= 0) + (r.serving(1) > 0);
assert(changes == numel(r.events), 'Serving changes and events differ');
r2 = handover_intelligent(cfg, net, links);
assert(isequal(r.serving, r2.serving), 'Not deterministic');
F = r.features;
for f = {'q_now', 'q_pred', 'r_rem'}
    v = F.(f{1});
    assert(all(v(:) >= 0 & v(:) <= 1), 'Term %s outside [0, 1]', f{1});
end
end

%% ---------------------------------------------------------------------
function [cfg, net, links] = synthetic(M, A, is_sat)
% Hand-built links. For satellites A doubles as geometric visibility,
% so the remaining-time term follows it. The algorithm parameters are
% fixed here so the checks test the mechanism, not the calibrated values.
cfg = config();
cfg.sim.dt_s = 1;
cfg.intel.w_quality = 0.4; cfg.intel.w_prediction = 0.3; cfg.intel.w_remaining = 0.3;
cfg.intel.trend_window = 10; cfg.intel.confirm_s = 1; cfg.intel.margin = 0.02;
cfg.intel.cost_switch = 0.05; cfg.intel.cost_system = 0.05; cfg.intel.cost_return = 0.10;
[T, N] = size(M);
M(~A) = NaN;
links.t_s = 0:T-1;
links.snr_meas_db = M;
links.available = A;
links.visible = A;
net.is_sat = logical(is_sat);
net.n_nodes = N;
net.n_sat = sum(is_sat);
net.names = arrayfun(@(k) sprintf('N%d', k), 1:N, 'UniformOutput', false);
end
