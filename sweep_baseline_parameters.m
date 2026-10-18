function sweep = sweep_baseline_parameters(cfg, net, links, hys_db, ttt_s, save_dir)
%SWEEP_BASELINE_PARAMETERS Effect of hysteresis and time-to-trigger on the baseline.
%
%   sweep = sweep_baseline_parameters(cfg, net, links, hys_db, ttt_s)
%   sweep = sweep_baseline_parameters(..., save_dir)   also saves a PNG
%
%   Runs the baseline for every (hysteresis, TTT) pair on the SAME links,
%   and records handovers, ping-pongs, link losses and mean serving SNR.
%   Each output field is numel(hys_db)-by-numel(ttt_s).

if nargin < 6, save_dir = ''; end
nh = numel(hys_db); nt = numel(ttt_s);
sweep.hys_db = hys_db;
sweep.ttt_s = ttt_s;
sweep.n_handovers = zeros(nh, nt);
sweep.n_ping_pong = zeros(nh, nt);
sweep.n_forced    = zeros(nh, nt);
sweep.n_rlf       = zeros(nh, nt);
sweep.mean_snr_db = zeros(nh, nt);

for i = 1:nh
    for j = 1:nt
        c = cfg;
        c.ho.hysteresis_db = hys_db(i);
        c.ho.ttt_s = ttt_s(j);
        r = handover_baseline(c, net, links);
        H = summarise_handover(c, net, links, r, false);
        sweep.n_handovers(i, j) = H.n_handovers;
        sweep.n_ping_pong(i, j) = H.n_ping_pong;
        sweep.n_forced(i, j)    = H.n_forced;
        sweep.n_rlf(i, j)       = H.n_rlf;
        sweep.mean_snr_db(i, j) = H.mean_serving_meas_snr_db;
    end
end

fprintf('\n=== Baseline: hysteresis / time-to-trigger sweep ===\n');
fprintf('%8s %7s %10s %11s %8s %6s %14s\n', 'HYS dB', 'TTT s', 'Handovers', 'Ping-pongs', 'Forced', 'RLF', 'Mean SNR dB');
for i = 1:nh
    for j = 1:nt
        fprintf('%8.1f %7.1f %10d %11d %8d %6d %14.1f\n', hys_db(i), ttt_s(j), ...
            sweep.n_handovers(i,j), sweep.n_ping_pong(i,j), sweep.n_forced(i,j), ...
            sweep.n_rlf(i,j), sweep.mean_snr_db(i,j));
    end
end

fig = figure('Name', 'Baseline parameter sweep');
subplot(1, 2, 1); hold on; grid on;
for j = 1:nt
    plot(hys_db, sweep.n_handovers(:, j), 'o-', 'LineWidth', 1.2);
end
xlabel('Hysteresis (dB)'); ylabel('Handovers');
title('Handovers vs hysteresis');
legend(arrayfun(@(x) sprintf('TTT %g s', x), ttt_s, 'UniformOutput', false), 'Location', 'northeast');
subplot(1, 2, 2); hold on; grid on;
for j = 1:nt
    plot(hys_db, sweep.mean_snr_db(:, j), 'o-', 'LineWidth', 1.2);
end
xlabel('Hysteresis (dB)'); ylabel('Mean serving SNR (dB)');
title('Serving link quality vs hysteresis');
if ~isempty(save_dir)
    if ~exist(save_dir, 'dir'), mkdir(save_dir); end
    saveas(fig, fullfile(save_dir, 'baseline_parameter_sweep.png'));
end
end
