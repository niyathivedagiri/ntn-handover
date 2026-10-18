function res = handover_baseline(cfg, net, links)
%HANDOVER_BASELINE Strongest-signal handover with hysteresis and time-to-trigger.
%
%   res = handover_baseline(cfg, net, links)
%
%   Inputs used: links.snr_meas_db, links.available, links.t_s, net.is_sat,
%   cfg.ho.hysteresis_db, cfg.ho.ttt_s, cfg.sim.dt_s. The algorithm sees
%   only measured SNR; true SNR is kept for evaluation. If
%   cfg.ho.filter_window > 1, a moving average of that many samples is
%   applied to the measurements first (used only as a comparison case).
%
%   Decision rules at every time step k:
%     1. No serving node: connect to the strongest available node, if any
%        ('initial' the first time, 'reestablish' after a link loss).
%     2. Serving node no longer available: switch at once to the strongest
%        available node ('forced'). If none is available the connection is
%        lost ('rlf') and the user waits for rule 1.
%     3. Otherwise, for every available neighbour n, check the entering
%        condition
%            M_n(k) > M_s(k) + H
%        where M is measured SNR (dB), s the serving node and H the
%        hysteresis. A per-neighbour counter records how many consecutive
%        steps the condition has held. When it has held for the whole
%        time-to-trigger, i.e. for round(TTT/dt)+1 consecutive samples,
%        the user hands over ('a3'). If several neighbours qualify, the
%        strongest is chosen. All counters reset after a handover.
%
%   Output struct res (shared by every handover algorithm in the project):
%     res.name        algorithm label
%     res.serving     T-by-1 serving node index, 0 = no connection
%     res.events      struct array: step, t_s, from, to, type
%     res.n_handovers number of 'a3' + 'forced' events
%     res.params      parameters used

T = size(links.snr_meas_db, 1);
N = size(links.snr_meas_db, 2);
M = links.snr_meas_db;
A = links.available;
L = 1;
if isfield(cfg.ho, 'filter_window'), L = cfg.ho.filter_window; end
if L > 1
    % optional moving average of the measurements (same filter as the
    % intelligent algorithm's level term); off by default
    M = window_stats(M, A, L, L, cfg.sim.dt_s);
end
H = cfg.ho.hysteresis_db;
n_ttt = round(cfg.ho.ttt_s / cfg.sim.dt_s);

serving = zeros(T, 1);
events = empty_events();
s = 0;                      % current serving node (0 = none)
ever_connected = false;
timer = zeros(1, N);        % consecutive steps the entering condition held

for k = 1:T
    t = links.t_s(k);

    % Rule 2: serving node lost
    if s > 0 && ~A(k, s)
        best = strongest_available(M(k, :), A(k, :));
        if best > 0
            events = add_event(events, k, t, s, best, 'forced');
            s = best;
        else
            events = add_event(events, k, t, s, 0, 'rlf');
            s = 0;
        end
        timer(:) = 0;
    end

    % Rule 1: no serving node
    if s == 0
        best = strongest_available(M(k, :), A(k, :));
        if best > 0
            if ever_connected
                events = add_event(events, k, t, 0, best, 'reestablish');
            else
                events = add_event(events, k, t, 0, best, 'initial');
            end
            s = best;
            ever_connected = true;
            timer(:) = 0;
        end
        serving(k) = s;
        continue;
    end

    % Rule 3: hysteresis and time-to-trigger
    entering = A(k, :) & (M(k, :) > M(k, s) + H);
    entering(s) = false;
    timer(entering) = timer(entering) + 1;
    timer(~entering) = 0;

    ready = timer >= n_ttt + 1;
    if any(ready)
        cand = find(ready);
        [~, j] = max(M(k, cand));
        target = cand(j);
        events = add_event(events, k, t, s, target, 'a3');
        s = target;
        timer(:) = 0;
    end
    serving(k) = s;
end

res.name = 'Baseline (strongest SNR + HYS + TTT)';
if L > 1, res.name = sprintf('Baseline + %d-sample smoothing', L); end
res.serving = serving;
res.events = events;
res.n_handovers = sum(is_handover_event({events.type}));
res.params = struct('hysteresis_db', H, 'ttt_s', cfg.ho.ttt_s);
end

%% ---------------------------------------------------------------------
function best = strongest_available(m_row, a_row)
best = 0;
if any(a_row)
    m = m_row;
    m(~a_row) = -Inf;
    [~, best] = max(m);
end
end

function ev = empty_events()
ev = struct('step', {}, 't_s', {}, 'from', {}, 'to', {}, 'type', {});
end

function ev = add_event(ev, k, t, from, to, type)
ev(end+1) = struct('step', k, 't_s', t, 'from', from, 'to', to, 'type', type);
end
