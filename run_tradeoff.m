function T = run_tradeoff(cfg, seeds, out_dir)
%RUN_TRADEOFF Handover rate versus service quality for both algorithms.
%
%   T = run_tradeoff(cfg)                   seeds 101-120
%   T = run_tradeoff(cfg, seeds, out_dir)   also saves a figure
%
%   Any handover rule can trade handovers for link quality: the baseline
%   by raising HYS/TTT, the proposed method by raising its switching cost.
%   Comparing single operating points can therefore mislead. This sweeps
%   both algorithms over their main knob on the same links and compares
%   the resulting curves:
%     baseline: (HYS, TTT) in {0,1,2,3,4,6,8} dB x {0,1,2,4} s
%     proposed: cost_switch in {0, 0.02, 0.05, 0.1, 0.15, 0.2, 0.3},
%               other parameters as in cfg
%   A proposed point is said to be DOMINATED if some baseline point has no
%   more handovers, no more outage and at least the same effective SE.

if nargin < 2 || isempty(seeds), seeds = 101:120; end
if nargin < 3, out_dir = ''; end
hys = [0 1 2 3 4 6 8]; ttt = [0 1 2 4];
costs = [0 0.02 0.05 0.1 0.15 0.2 0.3];
ns = numel(seeds);

B = zeros(numel(hys) * numel(ttt), 8);  % hys ttt ho/min se_eff outage unn pp forced
P = zeros(numel(costs), 7);             % cost ho/min se_eff outage unn pp forced
B(:, 1:2) = [kron(hys(:), ones(numel(ttt), 1)), repmat(ttt(:), numel(hys), 1)];
P(:, 1) = costs(:);
for s = 1:ns
    c = cfg; c.seed = seeds(s);
    net = generate_network(c);
    links = simulate_links(c, net, simulate_mobility(c));
    F = handover_features(c, net, links);
    for i = 1:size(B, 1)
        cb = c; cb.ho.hysteresis_db = B(i, 1); cb.ho.ttt_s = B(i, 2);
        m = evaluate_performance(cb, net, links, handover_baseline(cb, net, links));
        B(i, 3:8) = B(i, 3:8) + [m.ho_per_min, m.mean_se_eff, m.outage_s, ...
            m.n_unnecessary, m.n_ping_pong, m.n_forced] / ns;
    end
    for i = 1:numel(costs)
        cp = c; cp.intel.cost_switch = costs(i);
        m = evaluate_performance(cp, net, links, handover_intelligent(cp, net, links, F));
        P(i, 2:7) = P(i, 2:7) + [m.ho_per_min, m.mean_se_eff, m.outage_s, ...
            m.n_unnecessary, m.n_ping_pong, m.n_forced] / ns;
    end
end

dominated = false(numel(costs), 1);
for i = 1:numel(costs)
    dominated(i) = any(B(:, 3) <= P(i, 2) & B(:, 4) >= P(i, 3) & B(:, 5) <= P(i, 4) + 1e-9);
end

% at matched handover rate: baseline SE interpolated on its upper envelope
env = upper_envelope(B(:, 3), B(:, 4));
gap = nan(numel(costs), 1);
for i = 1:numel(costs)
    if P(i, 2) >= min(env(:, 1)) && P(i, 2) <= max(env(:, 1))
        gap(i) = P(i, 3) - interp1(env(:, 1), env(:, 2), P(i, 2));
    end
end

T.baseline = B; T.proposed = P; T.dominated = dominated; T.se_gap_at_same_rate = gap;
T.baseline_cols = {'hys_db', 'ttt_s', 'ho_per_min', 'se_eff', 'outage_s', 'unnecessary', 'ping_pong', 'forced'};
T.proposed_cols = {'cost_switch', 'ho_per_min', 'se_eff', 'outage_s', 'unnecessary', 'ping_pong', 'forced'};

fprintf('\n=== Trade-off: handovers per minute vs effective SE (%d seeds) ===\n', ns);
fprintf('Proposed  cost  HO/min   SE      outage s  dominated  SE gap vs baseline envelope\n');
for i = 1:numel(costs)
    fprintf('          %4.2f  %6.2f  %6.3f  %8.2f  %9s  %+.3f\n', P(i, 1:4), yesno(dominated(i)), gap(i));
end
fprintf('Baseline envelope (best SE at each handover rate):\n');
for i = 1:size(env, 1)
    fprintf('          HO/min %6.2f  SE %6.3f\n', env(i, 1), env(i, 2));
end

if ~isempty(out_dir)
    fig = figure('Name', 'Trade-off');
    subplot(1, 2, 1); hold on; grid on;
    plot(B(:, 3), B(:, 4), 's', 'Color', [0.45 0.45 0.45], 'MarkerFaceColor', [0.8 0.8 0.8]);
    plot(env(:, 1), env(:, 2), '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
    plot(P(:, 2), P(:, 3), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.5);
    xlabel('Handovers per minute'); ylabel('Effective SE (b/s/Hz)');
    title('Capacity vs handover rate');
    legend({'Baseline (HYS, TTT grid)', 'Baseline best envelope', 'Proposed (cost sweep)'}, 'Location', 'southeast');
    subplot(1, 2, 2); hold on; grid on;
    plot(B(:, 3), B(:, 5), 's', 'Color', [0.45 0.45 0.45], 'MarkerFaceColor', [0.8 0.8 0.8]);
    plot(P(:, 2), P(:, 4), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.5);
    xlabel('Handovers per minute'); ylabel('Outage time (s)');
    title('Outage vs handover rate');
    saveas(fig, fullfile(out_dir, 'tradeoff.png'));
end
end

function env = upper_envelope(x, y)
% points not beaten by any point with fewer or equal handovers
[xs, o] = sort(x); ys = y(o);
keep = false(size(xs)); best = -Inf;
for i = 1:numel(xs)
    if ys(i) > best, keep(i) = true; best = ys(i); end
end
env = [xs(keep), ys(keep)];
% remove duplicate x for interp1
[~, u] = unique(env(:, 1), 'last');
env = env(sort(u), :);
end

function s = yesno(b)
if b, s = 'yes'; else, s = 'no'; end
end
