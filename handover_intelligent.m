function res = handover_intelligent(cfg, net, links, F)
%HANDOVER_INTELLIGENT Multi-criteria handover decision with switching costs.
%
%   res = handover_intelligent(cfg, net, links)
%   res = handover_intelligent(cfg, net, links, F)   F from handover_features
%
%   Uses the same inputs as the baseline (measured SNR and availability)
%   plus satellite ephemeris through F.t_rem_s. Output has the same format
%   as handover_baseline.
%
%   Score of every available node n at step k (handover_features):
%       U_n = w_q q(level_n) + w_p q(level_n + slope_n * h) + w_r r_n
%   Switching cost of a node other than the serving node s:
%       c_n = c_sw + c_sys [type(n) ~= type(s)]
%             + c_ret [n is the node left less than return_window_s ago]
%   Net gain of switching:
%       G_n = U_n - c_n - U_s
%
%   Decision rules at every step k:
%     1. No serving node: connect to the available node with the highest
%        score ('initial' or 'reestablish').
%     2. Serving node no longer available: switch at once to the available
%        node with the highest score ('forced'); none available -> 'rlf'.
%     3. Otherwise let n* = argmax G_n. If G_n* > margin for
%        round(confirm_s/dt)+1 consecutive steps with the same n*, switch
%        to n* ('score').
%
%   The serving node is never charged a cost, so the algorithm stays put
%   unless another node is better by more than the cost of moving. A
%   satellite near the end of its pass loses its remaining-time term, so
%   the algorithm moves away before the satellite sets instead of waiting
%   for a forced handover.

if nargin < 4, F = handover_features(cfg, net, links); end
P = cfg.intel;
A = links.available;
% score from the precomputed terms and the CURRENT weights (lets a weight
% sweep reuse one feature computation)
U = P.w_quality * F.q_now + P.w_prediction * F.q_pred + P.w_remaining * F.r_rem;
U(~A) = NaN;
[T, N] = size(A);
dt = cfg.sim.dt_s;
n_conf = round(P.confirm_s / dt) + 1;
is_sat = net.is_sat(:)';

serving = zeros(T, 1);
events = struct('step', {}, 't_s', {}, 'from', {}, 'to', {}, 'type', {});
s = 0;
ever_connected = false;
cand = 0; cand_count = 0;
last_left = 0; t_left = -Inf;

for k = 1:T
    t = links.t_s(k);
    u = U(k, :);

    % Rule 2: serving node lost
    if s > 0 && ~A(k, s)
        best = best_score(u, A(k, :));
        if best > 0
            events(end+1) = ev(k, t, s, best, 'forced'); %#ok<AGROW>
            last_left = s; t_left = t;
            s = best;
        else
            events(end+1) = ev(k, t, s, 0, 'rlf'); %#ok<AGROW>
            s = 0;
        end
        cand = 0; cand_count = 0;
    end

    % Rule 1: no serving node
    if s == 0
        best = best_score(u, A(k, :));
        if best > 0
            if ever_connected
                events(end+1) = ev(k, t, 0, best, 'reestablish'); %#ok<AGROW>
            else
                events(end+1) = ev(k, t, 0, best, 'initial'); %#ok<AGROW>
            end
            s = best;
            ever_connected = true;
        end
        serving(k) = s;
        continue;
    end

    % Rule 3: net gain of switching
    cost = P.cost_switch + P.cost_system * (is_sat ~= is_sat(s));
    if last_left > 0 && (t - t_left) < P.return_window_s
        cost(last_left) = cost(last_left) + P.cost_return;
    end
    gain = u - cost - u(s);
    gain(~A(k, :)) = -Inf;
    gain(s) = -Inf;
    [g, n_star] = max(gain);

    if g > P.margin
        if n_star == cand
            cand_count = cand_count + 1;
        else
            cand = n_star; cand_count = 1;
        end
        if cand_count >= n_conf
            events(end+1) = ev(k, t, s, n_star, 'score'); %#ok<AGROW>
            last_left = s; t_left = t;
            s = n_star;
            cand = 0; cand_count = 0;
        end
    else
        cand = 0; cand_count = 0;
    end
    serving(k) = s;
end

res.name = 'Intelligent (multi-criteria score)';
res.serving = serving;
res.events = events;
res.n_handovers = sum(is_handover_event({events.type}));
res.params = P;
res.features = F;
end

%% ---------------------------------------------------------------------
function best = best_score(u, a)
best = 0;
if any(a)
    v = u; v(~a) = -Inf;
    [~, best] = max(v);
end
end

function e = ev(k, t, from, to, type)
e = struct('step', k, 't_s', t, 'from', from, 'to', to, 'type', type);
end
