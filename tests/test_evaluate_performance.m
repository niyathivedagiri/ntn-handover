function results = test_evaluate_performance()
%TEST_EVALUATE_PERFORMANCE Metric definitions checked on hand-built cases.
%
%   Every expected value below was worked out by hand from the metric
%   definitions in evaluate_performance.

checks = { ...
    @check_outage_counts_unserved_and_weak_steps, ...
    @check_spectral_efficiency_and_cap, ...
    @check_interruption_loss, ...
    @check_unnecessary_when_staying_was_fine, ...
    @check_not_unnecessary_when_source_fails, ...
    @check_not_unnecessary_with_real_gain, ...
    @check_forced_handover_never_unnecessary, ...
    @check_handover_failure, ...
    @check_ping_pong_count, ...
    @check_baseline_and_intelligent_share_definitions };

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
function check_outage_counts_unserved_and_weak_steps()
% 100 steps: unserved for 10, served at -10 dB (below -6) for 5, else 10 dB.
S = 10 * ones(100, 1);
S(31:35) = -10;
serv = ones(100, 1); serv(1:10) = 0;
[cfg, net, links, res] = case_of(S, serv, events_from(serv), false);
m = evaluate_performance(cfg, net, links, res);
assert(m.outage_s == 15, 'Outage %g s, expected 15 s', m.outage_s);
assert(abs(m.outage_prob - 0.15) < 1e-12, 'Outage probability %g, expected 0.15', m.outage_prob);
assert(m.n_outage_periods == 2, 'Expected 2 outage periods, got %d', m.n_outage_periods);
end

function check_spectral_efficiency_and_cap()
% 10 dB -> log2(11) = 3.4594; 30 dB -> capped at 6.
S = [10 * ones(50, 1); 30 * ones(50, 1)];
serv = ones(100, 1);
[cfg, net, links, res] = case_of(S, serv, events_from(serv), false);
m = evaluate_performance(cfg, net, links, res);
expected = (50 * log2(11) + 50 * 6) / 100;
assert(abs(m.mean_se - expected) < 1e-9, 'Mean SE %.4f, expected %.4f', m.mean_se, expected);
assert(abs(m.mean_se_eff - expected) < 1e-9, 'No handover, so no interruption loss');
end

function check_interruption_loss()
% One BS->BS handover at step 51 onto a 30 dB link (SE 6): loses
% 0.05 s * 6 b/s/Hz = 0.3 b/s/Hz*s over 100 s -> 0.003 lower mean.
S = 30 * ones(100, 2);
serv = [ones(50, 1); 2 * ones(50, 1)];
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(abs(m.interruption_s - 0.05) < 1e-12, 'Interruption %g s, expected 0.05 s', m.interruption_s);
assert(abs((m.mean_se - m.mean_se_eff) - 0.003) < 1e-12, 'SE lost %.5f, expected 0.003', m.mean_se - m.mean_se_eff);
end

function check_unnecessary_when_staying_was_fine()
% A at 20 dB and B at 21 dB for the whole run: both give SE 6, A stays
% usable, so a triggered A->B handover is unnecessary.
S = [20 * ones(60, 1), 21 * ones(60, 1)];
serv = [ones(30, 1); 2 * ones(30, 1)];
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_unnecessary == 1, 'Expected 1 unnecessary handover, got %d', m.n_unnecessary);
end

function check_not_unnecessary_when_source_fails()
% Same, but A drops below the outage threshold 5 s after the handover:
% leaving A was justified.
S = [20 * ones(60, 1), 21 * ones(60, 1)];
S(36:end, 1) = -20;
serv = [ones(30, 1); 2 * ones(30, 1)];
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_unnecessary == 0, 'Handover away from a failing link marked unnecessary');
end

function check_not_unnecessary_with_real_gain()
% A at 3 dB (SE 2.0), B at 15 dB (SE 5.03): the gain exceeds 10 %.
S = [3 * ones(60, 1), 15 * ones(60, 1)];
serv = [ones(30, 1); 2 * ones(30, 1)];
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_unnecessary == 0, 'Handover with a large capacity gain marked unnecessary');
end

function check_forced_handover_never_unnecessary()
S = [20 * ones(60, 1), 21 * ones(60, 1)];
serv = [ones(30, 1); 2 * ones(30, 1)];
ev = events_from(serv);
ev(2).type = 'forced';
[cfg, net, links, res] = case_of(S, serv, ev, [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_unnecessary == 0 && m.n_forced == 1, 'Forced handovers must not count as unnecessary');
end

function check_handover_failure()
% Target B is fine at execution (step 31) but below the threshold at
% step 32, inside the 1 s execution window -> one failure.
S = [10 * ones(60, 1), 10 * ones(60, 1)];
S(32, 2) = -10;
serv = [ones(30, 1); 2 * ones(30, 1)];
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_failures == 1 && m.failure_rate == 1, 'Expected one failed handover');
S(32, 2) = 10; S(33, 2) = -10;            % outside the window
links.snr_true_db = S;
m = evaluate_performance(cfg, net, links, res);
assert(m.n_failures == 0, 'Drop after the execution window is not a failure');
end

function check_ping_pong_count()
% A->B at 21, B->A at 26 (5 s, ping-pong), A->B at 60 (34 s later, not).
S = 15 * ones(100, 2);
serv = ones(100, 1); serv(21:25) = 2; serv(60:end) = 2;
[cfg, net, links, res] = case_of(S, serv, events_from(serv), [false false]);
m = evaluate_performance(cfg, net, links, res);
assert(m.n_handovers == 3 && m.n_ping_pong == 1, 'Expected 3 handovers and 1 ping-pong, got %d and %d', ...
    m.n_handovers, m.n_ping_pong);
end

function check_baseline_and_intelligent_share_definitions()
% Both algorithms are scored by the same function on the same links, and
% the counts it reports agree with the algorithms' own event logs.
cfg = config();
net = generate_network(cfg);
links = simulate_links(cfg, net, simulate_mobility(cfg));
rb = handover_baseline(cfg, net, links);
ri = handover_intelligent(cfg, net, links);
mb = evaluate_performance(cfg, net, links, rb);
mi = evaluate_performance(cfg, net, links, ri);
assert(mb.n_handovers == rb.n_handovers && mi.n_handovers == ri.n_handovers, 'Handover counts disagree');
assert(mb.n_unnecessary <= mb.n_triggered && mi.n_unnecessary <= mi.n_triggered, 'More unnecessary than triggered');
assert(mb.mean_se_eff <= mb.mean_se && mi.mean_se_eff <= mi.mean_se, 'Interruption cannot increase SE');
end

%% ---------------------------------------------------------------------
function [cfg, net, links, res] = case_of(S, serv, ev, is_sat)
cfg = config();
cfg.sim.dt_s = 1;
[T, N] = size(S);
links.t_s = 0:T-1;
links.snr_true_db = S;
links.available = ~isnan(S);
net.is_sat = logical(is_sat);
net.n_nodes = N;
net.n_sat = sum(is_sat);
res.name = 'test';
res.serving = serv;
res.events = ev;
end

function ev = events_from(serv)
% Event log matching a serving sequence: 'initial', then 'a3' for every
% change between nodes; 'rlf' / 'reestablish' around unserved periods.
ev = struct('step', {}, 't_s', {}, 'from', {}, 'to', {}, 'type', {});
prev = 0;
for k = 1:numel(serv)
    s = serv(k);
    if s == prev, continue; end
    if prev == 0 && isempty(ev),     type = 'initial';
    elseif prev == 0,                type = 'reestablish';
    elseif s == 0,                   type = 'rlf';
    else,                            type = 'a3';
    end
    ev(end+1) = struct('step', k, 't_s', k - 1, 'from', prev, 'to', s, 'type', type); %#ok<AGROW>
    prev = s;
end
end
