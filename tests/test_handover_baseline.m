function results = test_handover_baseline()
%TEST_HANDOVER_BASELINE Checks for the strongest-signal baseline.
%
%   Most checks use small synthetic link matrices where the correct
%   decision is known exactly, then one check runs on the full scenario.

checks = { ...
    @check_initial_selection_picks_strongest, ...
    @check_hysteresis_blocks_small_advantage, ...
    @check_ttt_delays_handover_exactly, ...
    @check_ttt_reset_when_condition_breaks, ...
    @check_hysteresis_and_ttt_suppress_fluctuation, ...
    @check_satellite_setting_forces_handover, ...
    @check_satellite_rising_triggers_normal_handover, ...
    @check_link_loss_and_reestablishment, ...
    @check_never_serves_unavailable_node_full_scenario };

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
function check_initial_selection_picks_strongest()
M = [5 12 8] .* ones(10, 1);
[cfg, net, links] = synthetic(M, true(size(M)), [true false false]);
r = handover_baseline(cfg, net, links);
assert(all(r.serving == 2), 'Initial selection should be node 2 and stay there');
assert(strcmp(r.events(1).type, 'initial') && numel(r.events) == 1, 'Expected one initial event');
end

function check_hysteresis_blocks_small_advantage()
% Node 2 is better by 2 dB (< 3 dB hysteresis): no handover.
% Then better by 4 dB (> hysteresis): handover after TTT.
T = 40;
M = [10 * ones(T, 1), 5 * ones(T, 1)];
M(5:19, 2) = 12;      % +2 dB
M(20:end, 2) = 14;    % +4 dB
[cfg, net, links] = synthetic(M, true(size(M)), [true true]);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 0;
r = handover_baseline(cfg, net, links);
assert(all(r.serving(1:19) == 1), 'Switched although advantage < hysteresis');
assert(r.serving(20) == 2, 'Did not switch when advantage > hysteresis (TTT = 0)');
end

function check_ttt_delays_handover_exactly()
% Entering condition starts at step 11. With TTT = 3 s and dt = 1 s it
% must hold at steps 11..14 (4 samples spanning 3 s): handover at step 14.
T = 30;
M = [10 * ones(T, 1), 5 * ones(T, 1)];
M(11:end, 2) = 20;
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 3;
r = handover_baseline(cfg, net, links);
k = find(r.serving == 2, 1);
assert(k == 14, 'Handover at step %d, expected 14', k);
end

function check_ttt_reset_when_condition_breaks()
% Condition holds for 3 samples, breaks for one, holds for 3 again:
% with TTT = 3 s (4 samples needed) there must be no handover.
T = 20;
M = [10 * ones(T, 1), 5 * ones(T, 1)];
M([5 6 7 9 10 11], 2) = 20;
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 3;
r = handover_baseline(cfg, net, links);
assert(all(r.serving == 1), 'TTT counter was not reset when the condition broke');
end

function check_hysteresis_and_ttt_suppress_fluctuation()
% Two equal-mean nodes whose measurements alternate by +-2 dB.
T = 100;
a = 10 + 2 * (-1).^(1:T)';
M = [a, 20 - a];
[cfg, net, links] = synthetic(M, true(size(M)), [false false]);
cfg.ho.hysteresis_db = 0; cfg.ho.ttt_s = 0;
r0 = handover_baseline(cfg, net, links);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 2;
r1 = handover_baseline(cfg, net, links);
assert(r0.n_handovers >= T - 2, 'Without HYS/TTT expected a handover nearly every step, got %d', r0.n_handovers);
assert(r1.n_handovers == 0, 'With HYS/TTT expected no handovers, got %d', r1.n_handovers);
end

function check_satellite_setting_forces_handover()
% Serving satellite 1 sets at step 50 while satellite 2 is available.
% The switch must happen at step 50 itself, with no unserved step and
% no time-to-trigger delay, even though satellite 2 is weaker than the
% hysteresis margin would normally require.
T = 80;
M = [15 * ones(T, 1), 9 * ones(T, 1)];
A = true(size(M));
A(50:end, 1) = false; M(50:end, 1) = NaN;
[cfg, net, links] = synthetic(M, A, [true true]);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 5;
r = handover_baseline(cfg, net, links);
assert(all(r.serving(1:49) == 1), 'Left satellite 1 early');
assert(all(r.serving(50:end) == 2), 'No immediate switch when satellite 1 set');
ev = r.events(strcmp({r.events.type}, 'forced'));
assert(numel(ev) == 1 && ev.step == 50, 'Expected one forced handover at step 50');
end

function check_satellite_rising_triggers_normal_handover()
% Satellite 2 becomes visible at step 30 with a much stronger signal.
% It cannot be selected before it is available; afterwards a normal
% triggered handover follows the TTT.
T = 60;
M = [8 * ones(T, 1), nan(T, 1)];
A = [true(T, 1), false(T, 1)];
M(30:end, 2) = 18; A(30:end, 2) = true;
[cfg, net, links] = synthetic(M, A, [true true]);
cfg.ho.hysteresis_db = 3; cfg.ho.ttt_s = 2;
r = handover_baseline(cfg, net, links);
assert(all(r.serving(1:31) == 1), 'Switched before TTT elapsed or before visibility');
assert(r.serving(32) == 2, 'Expected triggered handover at step 32');
end

function check_link_loss_and_reestablishment()
% Only node available disappears for steps 20-29; the user is unserved
% (RLF) and reconnects at step 30.
T = 40;
M = 10 * ones(T, 1);
A = true(T, 1);
A(20:29) = false; M(20:29) = NaN;
[cfg, net, links] = synthetic(M, A, true);
r = handover_baseline(cfg, net, links);
assert(all(r.serving(20:29) == 0), 'Should be unserved while no node is available');
assert(r.serving(30) == 1, 'Should re-establish at step 30');
types = {r.events.type};
assert(isequal(types, {'initial', 'rlf', 'reestablish'}), 'Unexpected event sequence: %s', strjoin(types, ','));
assert(r.n_handovers == 0, 'Link loss and re-establishment are not handovers');
end

function check_never_serves_unavailable_node_full_scenario()
cfg = config();
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
r = handover_baseline(cfg, net, links);
k = find(r.serving > 0);
ok = links.available(sub2ind(size(links.available), k, r.serving(k)));
assert(all(ok), 'Serving an unavailable node at %d steps', sum(~ok));
% each change of serving node corresponds to exactly one logged event
changes = sum(diff(r.serving) ~= 0) + (r.serving(1) > 0);
assert(changes == numel(r.events), 'Serving changes (%d) and events (%d) differ', changes, numel(r.events));
% repeated runs give identical decisions
r2 = handover_baseline(cfg, net, links);
assert(isequal(r.serving, r2.serving), 'Baseline is not deterministic');
end

%% ---------------------------------------------------------------------
function [cfg, net, links] = synthetic(M, A, is_sat)
% Minimal net/links structs for a hand-built measurement matrix.
cfg = config();
cfg.sim.dt_s = 1;
[T, N] = size(M);
M(~A) = NaN;
links.t_s = 0:T-1;
links.snr_meas_db = M;
links.available = A;
net.is_sat = logical(is_sat);
net.n_nodes = N;
net.n_sat = sum(is_sat);
net.names = arrayfun(@(k) sprintf('N%d', k), 1:N, 'UniformOutput', false);
end
