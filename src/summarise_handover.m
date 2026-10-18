function H = summarise_handover(cfg, net, links, res, verbose)
%SUMMARISE_HANDOVER Descriptive counts for one handover run.
%
%   H = summarise_handover(cfg, net, links, res)          prints and returns
%   H = summarise_handover(cfg, net, links, res, false)   returns only
%
%   These are diagnostics for checking an algorithm's behaviour. The full
%   performance metrics, with explicit definitions, are computed later in
%   evaluate_performance.
%
%   Handover types are labelled by the node types at each end:
%   SAT->SAT, SAT->BS, BS->SAT, BS->BS.

if nargin < 5, verbose = true; end
ev = res.events;
types = {ev.type};
ho = ev(is_handover_event(types));

H.n_handovers   = numel(ho);
H.n_a3          = sum(ismember(types, {'a3', 'score'}));   % triggered
H.n_forced      = sum(strcmp(types, 'forced'));
H.n_rlf         = sum(strcmp(types, 'rlf'));
H.n_reestablish = sum(strcmp(types, 'reestablish'));
H.n_ping_pong   = count_ping_pongs(ev, cfg.ho.ping_pong_window_s);
H.time_unserved_s = sum(res.serving == 0) * cfg.sim.dt_s;
H.time_on_sat_s   = sum(res.serving > 0 & ismember(res.serving, find(net.is_sat))) * cfg.sim.dt_s;
H.time_on_bs_s    = sum(res.serving > 0 & ~ismember(res.serving, find(net.is_sat))) * cfg.sim.dt_s;

kind = {'BS', 'SAT'};
H.by_link = struct('SAT_SAT', 0, 'SAT_BS', 0, 'BS_SAT', 0, 'BS_BS', 0);
for i = 1:numel(ho)
    f = kind{net.is_sat(ho(i).from) + 1};
    t = kind{net.is_sat(ho(i).to) + 1};
    key = [f '_' t];
    H.by_link.(key) = H.by_link.(key) + 1;
end

% mean measured SNR of the serving node while connected
k = find(res.serving > 0);
idx = sub2ind(size(links.snr_meas_db), k, res.serving(k));
H.mean_serving_meas_snr_db = mean(links.snr_meas_db(idx));

if ~verbose, return; end
fprintf('\n=== %s ===\n', res.name);
fprintf('Handovers            : %d  (triggered %d, forced %d)\n', H.n_handovers, H.n_a3, H.n_forced);
fprintf('  SAT->SAT %d, SAT->BS %d, BS->SAT %d, BS->BS %d\n', ...
    H.by_link.SAT_SAT, H.by_link.SAT_BS, H.by_link.BS_SAT, H.by_link.BS_BS);
fprintf('Ping-pongs (<= %g s)  : %d\n', cfg.ho.ping_pong_window_s, H.n_ping_pong);
fprintf('Link losses          : %d  (re-established %d)\n', H.n_rlf, H.n_reestablish);
fprintf('Time unserved        : %.0f s\n', H.time_unserved_s);
fprintf('Time on SAT / on BS  : %.0f s / %.0f s\n', H.time_on_sat_s, H.time_on_bs_s);
fprintf('Mean serving SNR     : %.1f dB (measured)\n', H.mean_serving_meas_snr_db);
end
