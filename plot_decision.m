function fig = plot_decision(cfg, net, links, res, t_range, save_dir)
%PLOT_DECISION Show why the proposed algorithm switched, term by term.
%
%   fig = plot_decision(cfg, net, links, res, t_range)
%   fig = plot_decision(cfg, net, links, res, t_range, save_dir)
%
%   For the time window t_range = [t0 t1] (s):
%   Panel 1: score of the serving node and of the best other node after
%            its switching cost, with handover instants
%   Panel 2: the three terms (quality, predicted quality, remaining time)
%            of the serving node
%   Panel 3: the same terms for the best other node
%   res must come from handover_intelligent (it carries res.features).

if nargin < 6, save_dir = ''; end
F = res.features;
P = cfg.intel;
t = links.t_s(:);
k = find(t >= t_range(1) & t <= t_range(2));
A = links.available;
U = P.w_quality * F.q_now + P.w_prediction * F.q_pred + P.w_remaining * F.r_rem;
U(~A) = NaN;

serv = res.serving(k);
Us = nan(numel(k), 1); Ub = nan(numel(k), 1); best = zeros(numel(k), 1);
terms_s = nan(numel(k), 3); terms_b = nan(numel(k), 3);
for i = 1:numel(k)
    s = serv(i); kk = k(i);
    if s == 0, continue; end
    cost = P.cost_switch + P.cost_system * (net.is_sat ~= net.is_sat(s));
    g = U(kk, :) - cost; g(s) = -Inf; g(~A(kk, :)) = -Inf;
    [gb, b] = max(g);
    Us(i) = U(kk, s);
    terms_s(i, :) = [F.q_now(kk, s), F.q_pred(kk, s), F.r_rem(kk, s)];
    if isfinite(gb)
        Ub(i) = gb; best(i) = b;
        terms_b(i, :) = [F.q_now(kk, b), F.q_pred(kk, b), F.r_rem(kk, b)];
    end
end

ev = res.events;
ev = ev(is_handover_event({ev.type}));
ev = ev([ev.t_s] >= t_range(1) & [ev.t_s] <= t_range(2));

fig = figure('Name', 'Decision explanation');
subplot(3, 1, 1); hold on; grid on;
plot(t(k), Us, 'k-', 'LineWidth', 1.5);
plot(t(k), Ub, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.2);
plot(t(k), Us + P.margin, 'k:');
for e = ev
    plot(e.t_s * [1 1], [0 1], 'r--');
    text(e.t_s, 0.95, sprintf(' %s->%s', net.names{e.from}, net.names{e.to}), 'FontSize', 7, 'Color', [0.8 0 0]);
end
ylim([0 1]); xlim(t_range);
ylabel('Score');
title('Serving score vs best other node after switching cost (dotted: switch threshold)');
legend({'Serving U_s', 'Best other U_n - c_n', 'U_s + margin'}, 'Location', 'southwest');

names = {'q(level)', 'q(predicted)', 'remaining time'};
sty = {'-', '--', '-'};
tc = [0 0.45 0.74; 0.5 0.5 0.5; 0.85 0.33 0.10];
lw = [1.3 1.0 2.0];
subplot(3, 1, 2); hold on; grid on;
for j = 1:3, plot(t(k), terms_s(:, j), sty{j}, 'Color', tc(j, :), 'LineWidth', lw(j)); end
ylim([0 1.05]); xlim(t_range); ylabel('Term value');
title('Terms of the serving node'); legend(names, 'Location', 'southwest');
subplot(3, 1, 3); hold on; grid on;
for j = 1:3, plot(t(k), terms_b(:, j), sty{j}, 'Color', tc(j, :), 'LineWidth', lw(j)); end
ylim([0 1.05]); xlim(t_range); ylabel('Term value'); xlabel('Time (s)');
title('Terms of the best other node');

if ~isempty(save_dir)
    if ~exist(save_dir, 'dir'), mkdir(save_dir); end
    saveas(fig, fullfile(save_dir, 'decision_explanation.png'));
end
end
