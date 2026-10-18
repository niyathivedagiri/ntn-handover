function links = simulate_links(cfg, net, mob)
%SIMULATE_LINKS Time-varying link quality for every satellite and base station.
%
%   links = simulate_links(cfg, net, mob)
%
%   Link quality is the downlink SNR in dB. All nodes are compared on the
%   same SNR scale. Interference is not modelled (see README assumptions).
%
%   Output struct links (T time steps, N = net.n_nodes, satellites first):
%     links.t_s           1-by-T
%     links.range_m       T-by-N  user-to-node distance (slant range for sats)
%     links.elev_deg      T-by-Nsat satellite elevation angle
%     links.visible       T-by-N  geometric visibility:
%                                 satellite: elevation >= min_elev_deg
%                                 base station: distance <= max_range_m
%     links.snr_mean_db   T-by-N  SNR without shadowing (path loss only)
%     links.snr_true_db   T-by-N  SNR including shadowing; NaN if not visible
%     links.snr_meas_db   T-by-N  SNR the user measures (true + measurement
%                                 error); NaN if the node is not available
%     links.available     T-by-N  visible AND measured SNR >= min_access_snr_db
%                                 Only available nodes may be selected.
%
%   Random numbers are drawn in a fixed order from seeded streams, so the
%   same cfg and seed always give identical links, and both handover
%   algorithms later see exactly the same data.

T = numel(mob.t_s);
N = net.n_nodes;
Ns = net.n_sat;
Nb = net.n_bs;
t = mob.t_s(:);

range_m  = nan(T, N);
snr_mean = nan(T, N);
elev     = nan(T, Ns);

%% Satellites: geometry and free-space link budget
user_eci = ecef_to_eci(mob.ecef_m, t, cfg.const.earth_rate_rads);
for i = 1:Ns
    r_sat = satellite_position_eci(net.sat(i), t);
    [el, d] = elevation_deg(r_sat, user_eci);
    elev(:, i) = el;
    range_m(:, i) = d;
    % C/N = EIRP density + G/T - FSPL - losses - 10log10(k) - 10log10(1 MHz)
    snr_mean(:, i) = cfg.sat.eirp_dbw_per_mhz + cfg.sat.ue_gt_dbk ...
        - fspl_db(d, cfg.sat.freq_hz, cfg.const.c_mps) ...
        - cfg.sat.misc_loss_db - cfg.const.boltzmann_dbw - 60;
end

%% Base stations: distance and macro-cell path loss
noise_dbm = -174 + 10*log10(cfg.bs.bandwidth_hz) + cfg.bs.ue_nf_db;
dh = net.bs.height_m - cfg.mobility.ue_height_m;
d2d_bs = zeros(T, Nb);
for j = 1:Nb
    d2d = sqrt(sum((mob.en_m - net.bs.en_m(j, :)).^2, 2));
    d3d = sqrt(d2d.^2 + dh^2);
    d2d_bs(:, j) = d2d;
    range_m(:, Ns + j) = d3d;
    pl = cfg.bs.pl_a_db + cfg.bs.pl_b_db * log10(max(d3d, 35) / 1000);
    snr_mean(:, Ns + j) = cfg.bs.tx_power_dbm + cfg.bs.ant_gain_dbi - pl - noise_dbm;
end

%% Shadowing (correlated in time for satellites, in distance for base stations)
rng(cfg.seed + 2);
z_sat = randn(T, Ns);
z_bs  = randn(T, Nb);
rho_sat = exp(-cfg.sim.dt_s / cfg.sat.shadow_corr_s);
step_m  = [0; diff(mob.dist_m)];
rho_bs  = exp(-step_m / cfg.bs.shadow_corr_m);
shadow = [correlated_shadowing(z_sat, rho_sat, cfg.sat.shadow_std_db), ...
          correlated_shadowing(z_bs,  rho_bs,  cfg.bs.shadow_std_db)];

%% Measurement error
rng(cfg.seed + 3);
meas_err = cfg.meas.noise_std_db * randn(T, N);

%% Visibility, availability and final SNR matrices
visible = false(T, N);
visible(:, 1:Ns) = elev >= cfg.sat.min_elev_deg;
visible(:, Ns+1:end) = d2d_bs <= cfg.bs.max_range_m;

snr_true = snr_mean + shadow;
snr_true(~visible) = NaN;
snr_meas = snr_true + meas_err;
available = visible & (snr_meas >= cfg.link.min_access_snr_db);
snr_meas(~available) = NaN;

links.t_s = mob.t_s;
links.range_m = range_m;
links.elev_deg = elev;
links.visible = visible;
links.snr_mean_db = snr_mean;
links.shadow_db = shadow;
links.snr_true_db = snr_true;
links.snr_meas_db = snr_meas;
links.available = available;
end
