function fig = plot_handover(cfg, net, links, res, save_dir, file_tag)
%PLOT_HANDOVER Link quality, serving node and handover events for one run.
%
%   fig = plot_handover(cfg, net, links, res)
%   fig = plot_handover(cfg, net, links, res, save_dir, file_tag)
%       also saves <save_dir>/<file_tag>.png
%
%   Panel 1: measured SNR of every available node (thin) and of the
%            serving node (thick), with handover instants marked
%   Panel 2: serving node over time (satellites blue, base stations orange)
%   Panel 3: cumulative number of handovers, split by trigger type

if nargin < 5, save_dir = ''; end
if nargin < 6, file_tag = 'handover'; end
t = links.t_s(:);
T = numel(t);
Ns = net.n_sat;
c_sat = [0.00 0.45 0.74];
c_bs  = [0.85 0.33 0.10];
c_bg  = [0.70 0.70 0.70];

serv = res.serving;
k_on = find(serv > 0);
serv_snr = nan(T, 1);
serv_snr(k_on) = links.snr_meas_db(sub2ind(size(links.snr_meas_db), k_on, serv(k_on)));

ev = res.events;
types = {ev.type};
is_a3 = ismember(types, {'a3', 'score'});
is_forced = strcmp(types, 'forced');
is_rlf = strcmp(types, 'rlf');

fig = figure('Name', res.name);

%% Panel 1: SNR
subplot(3, 1, 1); hold on; grid on;
plot(t, links.snr_meas_db, '-', 'Color', c_bg, 'LineWidth', 0.5);
h1 = plot(t, serv_snr, 'k-', 'LineWidth', 1.4);
h = h1; lab = {'Serving node'};
if any(is_a3)
    k = [ev(is_a3).step];
    h(end+1) = plot(t(k), serv_snr(k), 'v', 'MarkerFaceColor', [0.2 0.6 0.3], ...
        'MarkerEdgeColor', 'k', 'MarkerSize', 6);
    lab{end+1} = 'Triggered handover';
end
if any(is_forced)
    k = [ev(is_forced).step];
    h(end+1) = plot(t(k), serv_snr(k), 's', 'MarkerFaceColor', [0.85 0.1 0.1], ...
        'MarkerEdgeColor', 'k', 'MarkerSize', 6);
    lab{end+1} = 'Forced handover';
end
plot(t([1 end]), cfg.link.min_access_snr_db * [1 1], 'k--');
xlim(t([1 end]));
ylabel('Measured SNR (dB)');
title(sprintf('%s: HYS %.1f dB, TTT %.1f s', res.name, cfg.ho.hysteresis_db, cfg.ho.ttt_s));
legend(h, lab, 'Location', 'best');

%% Panel 2: serving node
subplot(3, 1, 2); hold on; grid on;
y_sat = nan(T, 1); y_bs = nan(T, 1);
on_sat = serv > 0 & ismember(serv, 1:Ns);
on_bs  = serv > Ns;
y_sat(on_sat) = serv(on_sat);
y_bs(on_bs)   = serv(on_bs);
plot(t, y_sat, '.', 'Color', c_sat, 'MarkerSize', 6);
plot(t, y_bs,  '.', 'Color', c_bs,  'MarkerSize', 6);
if any(serv == 0)
    k0 = find(serv == 0);
    plot(t(k0), zeros(size(k0)), 'rx', 'MarkerSize', 6);
end
plot(t([1 end]), (Ns + 0.5) * [1 1], 'k:');
ylim([0 net.n_nodes + 1]); xlim(t([1 end]));
step = max(1, ceil(net.n_nodes / 8));
ticks = 1:step:net.n_nodes;
set(gca, 'YTick', ticks, 'YTickLabel', net.names(ticks), 'FontSize', 7);
ylabel('Serving node');
title('Serving node (blue: satellite, orange: base station, red x: no connection)');

%% Panel 3: cumulative handovers
subplot(3, 1, 3); hold on; grid on;
cum_a3 = zeros(T, 1); cum_f = zeros(T, 1);
if any(is_a3), cum_a3([ev(is_a3).step]) = 1; end
if any(is_forced), cum_f([ev(is_forced).step]) = 1; end
stairs(t, cumsum(cum_a3 + cum_f), 'k', 'LineWidth', 1.4);
stairs(t, cumsum(cum_a3), 'Color', [0.2 0.6 0.3], 'LineWidth', 1.0);
stairs(t, cumsum(cum_f), 'Color', [0.85 0.1 0.1], 'LineWidth', 1.0);
if any(is_rlf)
    k = [ev(is_rlf).step];
    plot(t(k), zeros(size(k)), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
end
xlim(t([1 end]));
xlabel('Time (s)'); ylabel('Count');
title('Cumulative handovers');
legend({'All', 'Triggered', 'Forced'}, 'Location', 'northwest');

if ~isempty(save_dir)
    if ~exist(save_dir, 'dir'), mkdir(save_dir); end
    saveas(fig, fullfile(save_dir, [file_tag '.png']));
end
end
