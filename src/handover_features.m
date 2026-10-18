function F = handover_features(cfg, net, links)
%HANDOVER_FEATURES Per-node decision inputs for the intelligent algorithm.
%
%   F = handover_features(cfg, net, links)
%
%   All fields are T-by-N and use only information available to the user
%   at time k: past and present measurements, plus satellite ephemeris.
%
%   F.level_db   current level: mean of the last level_window measurements
%   F.slope_dbs  least-squares trend over the last trend_window samples,
%                set to 0 unless |slope| >= trend_t_min standard errors,
%                then limited to +-max_slope_db_s
%   F.pred_db    predicted level after horizon_s: level + slope * horizon
%   F.t_rem_s    expected remaining service time (s):
%                  satellites   time until the elevation falls below the
%                               minimum, from the orbit (ephemeris); the
%                               user's displacement over that time changes
%                               the elevation by a negligible amount
%                  base stations time until the trend line reaches the
%                               access threshold (no trend or rising:
%                               t_cap_s)
%   F.q_now      quality term   q(level)          in [0, 1]
%   F.q_pred     prediction term q(pred)          in [0, 1]
%   F.r_rem      service-time term min(t_rem, t_cap) / t_cap in [0, 1]
%   F.score      w_q q_now + w_p q_pred + w_r r_rem; NaN where unavailable
%
%   q(S) = min(log2(1 + 10^(S/10)), eta_max) / eta_max, and q = 0 below the
%   access threshold. Using capped spectral efficiency rather than dB means
%   that a gain from 25 to 40 dB counts for nothing, while a gain from 0 to
%   10 dB counts for a lot.

P = cfg.intel;
dt = cfg.sim.dt_s;
A = links.available;
[T, N] = size(A);

[level, slope, ~, slope_se] = window_stats(links.snr_meas_db, A, P.level_window, P.trend_window, dt);
% Significance gate: a trend is used only when |slope| / se >= trend_t_min.
% Shadowing makes most short-window trends pure noise; acting on them
% makes the score jump and causes unnecessary handovers.
insignificant = abs(slope) < P.trend_t_min * slope_se;
slope(insignificant & ~isnan(slope)) = 0;
slope = max(min(slope, P.max_slope_db_s), -P.max_slope_db_s);
pred = level + slope * P.horizon_s;

% remaining service time
t_rem = P.t_cap_s * ones(T, N);
sat = find(net.is_sat);
if ~isempty(sat)
    V = links.visible(:, sat);
    run = zeros(T, numel(sat));          % consecutive visible steps from k on
    run(T, :) = V(T, :);
    for k = T-1:-1:1
        run(k, :) = V(k, :) .* (run(k+1, :) + 1);
    end
    t_rem(:, sat) = run * dt;
end
bs = find(~net.is_sat);
if ~isempty(bs)
    s = slope(:, bs);
    headroom = level(:, bs) - cfg.link.min_access_snr_db;
    tb = P.t_cap_s * ones(T, numel(bs));
    falling = s < -1e-3;
    tb(falling) = max(headroom(falling), 0) ./ (-s(falling));
    t_rem(:, bs) = tb;
end
t_rem = min(t_rem, P.t_cap_s);

q = @(S) quality_term(S, P.eta_max, cfg.link.min_access_snr_db);
F.level_db  = level;
F.slope_dbs = slope;
F.pred_db   = pred;
F.t_rem_s   = t_rem;
F.q_now  = q(level);
F.q_pred = q(pred);
F.r_rem  = t_rem / P.t_cap_s;
F.score  = P.w_quality * F.q_now + P.w_prediction * F.q_pred + P.w_remaining * F.r_rem;
F.score(~A) = NaN;
end

function v = quality_term(S, eta_max, s_min)
v = min(log2(1 + 10.^(S / 10)), eta_max) / eta_max;
v(S < s_min | isnan(S)) = 0;
end
