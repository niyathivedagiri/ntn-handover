function m = evaluate_performance(cfg, net, links, res)
%EVALUATE_PERFORMANCE Metrics for one handover run, from TRUE link quality.
%
%   m = evaluate_performance(cfg, net, links, res)
%
%   Algorithms decide from measured SNR; every metric here uses the true
%   SNR (links.snr_true_db), so measurement noise cannot hide a bad
%   decision. The same definitions are applied to every algorithm.
%
%   Definitions (dt = time step, thr = cfg.eval.outage_snr_db):
%   Spectral efficiency (SE) of a node at step k:
%       SE = min(log2(1 + 10^(S/10)), eta_max)  with S its true SNR,
%       and 0 if the node is not visible. A Shannon bound with a cap that
%       stands in for the highest modulation and coding scheme; it gives
%       b/s/Hz, so different satellite and terrestrial bandwidths do not
%       enter the comparison.
%   Outage at step k: no serving node, or serving true SNR < thr.
%       outage_prob = outage steps / all steps; outage_s = outage steps*dt.
%   Handover: an executed 'a3', 'score' or 'forced' event.
%   Ping-pong: A->B then B->A within cfg.ho.ping_pong_window_s.
%   Unnecessary handover: a triggered handover (not forced) A->B at step k
%       such that, over the next unnecessary_window_s,
%         (a) the source A stayed usable (visible and true SNR >= thr) at
%             every step, and
%         (b) mean SE of B <= (1 + unnecessary_gain) * mean SE of A.
%       In words: staying would have worked for the whole window, and
%       moving gained less than 10 % capacity. The window (30 s) is long
%       enough that a planned handover away from a satellite that sets
%       within it is not counted as unnecessary.
%   Handover failure: the target's true SNR is below thr (or the target is
%       not visible) at any step within failure_window_s after execution.
%       failure_rate = failures / handovers.
%   Interruption: each handover interrupts service for a fixed time that
%       depends on the node types (cfg.eval.interruption_s); the SE lost is
%       interruption * SE of the new link at that step.
%   mean_se_eff = (sum of SE over time - SE lost to interruptions) / duration.

E = cfg.eval;
dt = cfg.sim.dt_s;
S = links.snr_true_db;
[T, N] = size(S);
serv = res.serving(:);
duration = T * dt;
thr = E.outage_snr_db;

se_all = min(log2(1 + 10.^(S / 10)), E.max_se_bps_hz);
se_all(isnan(S)) = 0;
usable = ~isnan(S) & S >= thr;

k_on = find(serv > 0);
s_serv = nan(T, 1);
s_serv(k_on) = S(sub2ind([T N], k_on, serv(k_on)));
outage = isnan(s_serv) | s_serv < thr;
se = zeros(T, 1);
se(~outage) = min(log2(1 + 10.^(s_serv(~outage) / 10)), E.max_se_bps_hz);

ev = res.events;
types = {ev.type};
is_ho = is_handover_event(types);
ho = ev(is_ho);
nH = numel(ho);

Wu = max(1, round(E.unnecessary_window_s / dt));
Wf = round(E.failure_window_s / dt);
unnecessary = false(1, nH);
failed = false(1, nH);
lost = 0;
interruption = 0;
by_link = struct('SAT_SAT', 0, 'SAT_BS', 0, 'BS_SAT', 0, 'BS_BS', 0);
kind = {'BS', 'SAT'};
for i = 1:nH
    k = ho(i).step; a = ho(i).from; b = ho(i).to;
    fa = kind{net.is_sat(a) + 1}; fb = kind{net.is_sat(b) + 1};
    by_link.([fa '_' fb]) = by_link.([fa '_' fb]) + 1;

    if strcmp(fa, fb)
        d = E.interruption_s.([fa '_' fb]);
    else
        d = E.interruption_s.inter;
    end
    interruption = interruption + d;
    lost = lost + d * se(k);

    kw = k:min(k + Wf, T);
    failed(i) = any(~usable(kw, b));

    if ~strcmp(ho(i).type, 'forced')
        kw = k:min(k + Wu - 1, T);
        if all(usable(kw, a)) && mean(se_all(kw, b)) <= (1 + E.unnecessary_gain) * mean(se_all(kw, a))
            unnecessary(i) = true;
        end
    end
end

% outage periods (separate interruptions of service)
d_out = diff([0; outage(:); 0]);

m.algorithm      = res.name;
m.n_handovers    = nH;
m.ho_per_min     = nH / (duration / 60);
m.n_triggered    = sum(ismember(types, {'a3', 'score'}));
m.n_forced       = sum(strcmp(types, 'forced'));
m.n_ping_pong    = count_ping_pongs(ev, cfg.ho.ping_pong_window_s);
m.n_unnecessary  = sum(unnecessary);
m.frac_unnecessary = sum(unnecessary) / max(nH, 1);
m.n_failures     = sum(failed);
m.failure_rate   = sum(failed) / max(nH, 1);
m.n_rlf          = sum(strcmp(types, 'rlf'));
m.outage_s       = sum(outage) * dt;
m.outage_prob    = mean(outage);
m.n_outage_periods = sum(d_out == 1);
m.mean_snr_db    = mean(s_serv(~outage));
m.mean_se        = mean(se);
m.interruption_s = interruption;
m.mean_se_eff    = (sum(se) * dt - lost) / duration;
m.time_on_sat_frac = mean(serv > 0 & ismember(serv, find(net.is_sat)));
m.by_link        = by_link;
m.unnecessary_mask = unnecessary;
m.failed_mask    = failed;
end
