function figs = plot_scenario(cfg, net, mob, links, save_dir)
%PLOT_SCENARIO Plots of the network, mobility and link model.
%
%   figs = plot_scenario(cfg, net, mob, links)            display only
%   figs = plot_scenario(cfg, net, mob, links, save_dir)  also save PNGs
%
%   Figure 1: map of the road, base stations and their measurement range
%   Figure 2: satellite elevation, measured SNR and number of available nodes
%   Figure 3: availability of every node over time

if nargin < 5, save_dir = ''; end
Ns = net.n_sat;
t = links.t_s(:);
c_sat = [0.00 0.45 0.74];
c_bs  = [0.85 0.33 0.10];

%% Figure 1: map
figs(1) = figure('Name', 'Scenario map');
hold on; grid on;
ang = linspace(0, 2*pi, 100);
for j = 1:net.n_bs
    p = net.bs.en_m(j, :) / 1e3;
    r = cfg.bs.max_range_m / 1e3;
    plot(p(1) + r*cos(ang), p(2) + r*sin(ang), ':', 'Color', [0.8 0.8 0.8]);
end
h1 = plot(cfg.mobility.waypoints_m(:,1)/1e3, cfg.mobility.waypoints_m(:,2)/1e3, ...
          '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 3);
h2 = plot(mob.en_m(:,1)/1e3, mob.en_m(:,2)/1e3, 'k-', 'LineWidth', 1.5);
h3 = plot(net.bs.en_m(:,1)/1e3, net.bs.en_m(:,2)/1e3, '^', ...
          'MarkerFaceColor', c_bs, 'MarkerEdgeColor', 'k', 'MarkerSize', 8);
for j = 1:net.n_bs
    text(net.bs.en_m(j,1)/1e3, net.bs.en_m(j,2)/1e3 + 0.9, net.names{Ns + j}, ...
         'HorizontalAlignment', 'center', 'FontSize', 7);
end
h4 = plot(mob.en_m(1,1)/1e3, mob.en_m(1,2)/1e3, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
h5 = plot(mob.en_m(end,1)/1e3, mob.en_m(end,2)/1e3, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
xlabel('East (km)'); ylabel('North (km)');
all_x = [mob.en_m(:,1); net.bs.en_m(:,1)] / 1e3;
xlim([min(all_x) - 6, max(all_x) + 6]); ylim([-8 8]);
title(sprintf('Road, base stations and %.0f km measurement range', cfg.bs.max_range_m/1e3));
legend([h1 h2 h3 h4 h5], {'Road', 'User path', 'Base station', 'Start', 'End'}, ...
       'Location', 'southoutside', 'Orientation', 'horizontal');

%% Figure 2: time series
figs(2) = figure('Name', 'Link model');

subplot(3, 1, 1); hold on; grid on;
plot(t, links.elev_deg, 'Color', c_sat);
plot(t([1 end]), cfg.sat.min_elev_deg * [1 1], 'k--', 'LineWidth', 1.2);
ylim([0 90]); xlim(t([1 end]));
ylabel('Elevation (deg)');
title('Satellite elevation (dashed: minimum usable elevation)');

subplot(3, 1, 2); hold on; grid on;
hs = plot(t, links.snr_meas_db(:, 1:Ns), '-', 'Color', c_sat);
hb = plot(t, links.snr_meas_db(:, Ns+1:end), '-', 'Color', c_bs);
plot(t([1 end]), cfg.link.min_access_snr_db * [1 1], 'k--', 'LineWidth', 1.2);
xlim(t([1 end]));
ylabel('Measured SNR (dB)');
title('Measured SNR of available nodes (dashed: minimum access SNR)');
legend([hs(1) hb(1)], {'Satellites', 'Base stations'}, 'Location', 'northeast');

subplot(3, 1, 3); hold on; grid on;
n_sat_av = sum(links.available(:, 1:Ns), 2);
n_bs_av  = sum(links.available(:, Ns+1:end), 2);
stairs(t, n_sat_av, 'Color', c_sat, 'LineWidth', 1.2);
stairs(t, n_bs_av,  'Color', c_bs,  'LineWidth', 1.2);
stairs(t, n_sat_av + n_bs_av, 'k', 'LineWidth', 1.0);
xlim(t([1 end]));
xlabel('Time (s)'); ylabel('Count');
title('Number of available nodes');
legend({'Satellites', 'Base stations', 'Total'}, 'Location', 'northeast');

%% Figure 3: availability raster
figs(3) = figure('Name', 'Node availability');
code = zeros(net.n_nodes, numel(t));          % 0 not visible
code(links.visible') = 1;                     % 1 visible, below access SNR
code(links.available') = 2;                   % 2 available
imagesc(t, 1:net.n_nodes, code);
colormap([1 1 1; 0.85 0.85 0.85; 0.20 0.60 0.30]);
caxis([0 2]);
set(gca, 'YTick', 1:net.n_nodes, 'YTickLabel', net.names, 'FontSize', 7);
xlabel('Time (s)'); ylabel('Node');
title('Availability (green: available, grey: visible but below access SNR)');
hold on;
plot(t([1 end]), (Ns + 0.5) * [1 1], 'k-', 'LineWidth', 1);

%% Save
if ~isempty(save_dir)
    if ~exist(save_dir, 'dir'), mkdir(save_dir); end
    names = {'scenario_map', 'link_model', 'node_availability'};
    for k = 1:numel(figs)
        saveas(figs(k), fullfile(save_dir, [names{k} '.png']));
    end
end
end
