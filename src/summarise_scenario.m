function S = summarise_scenario(cfg, net, mob, links, verbose)
%SUMMARISE_SCENARIO Key numbers describing a generated scenario.
%
%   S = summarise_scenario(cfg, net, mob, links)       prints and returns
%   S = summarise_scenario(cfg, net, mob, links, false) returns only
%
%   S.visible_s(n)      seconds node n is geometrically visible
%   S.available_s(n)    seconds node n is available for selection
%   S.max_elev_deg(i)   peak elevation of satellite i
%   S.frac_any_sat      fraction of time with >= 1 available satellite
%   S.frac_any_bs       fraction of time with >= 1 available base station
%   S.frac_any_node     fraction of time with >= 1 available node
%   S.frac_no_node      fraction of time with no available node at all

if nargin < 5, verbose = true; end
dt = cfg.sim.dt_s;
Ns = net.n_sat;
A = links.available;

S.visible_s   = sum(links.visible, 1) * dt;
S.available_s = sum(A, 1) * dt;
S.max_elev_deg = max(links.elev_deg, [], 1);
S.frac_any_sat  = mean(any(A(:, 1:Ns), 2));
S.frac_any_bs   = mean(any(A(:, Ns+1:end), 2));
S.frac_any_node = mean(any(A, 2));
S.frac_no_node  = 1 - S.frac_any_node;
S.mean_available_nodes = mean(sum(A, 2));

if ~verbose, return; end

fprintf('\n=== Scenario summary (seed %d) ===\n', cfg.seed);
fprintf('Duration %.0f s, step %.1f s, user speed %.1f m/s, distance %.1f km\n', ...
    cfg.sim.duration_s, dt, cfg.mobility.speed_mps, mob.dist_m(end)/1e3);
fprintf('Nodes: %d satellites, %d base stations\n\n', Ns, net.n_bs);

fprintf('%-9s %8s %10s %12s %14s\n', 'Node', 'Type', 'Visible s', 'Available s', 'Peak elev deg');
for n = 1:net.n_nodes
    if net.is_sat(n)
        fprintf('%-9s %8s %10.0f %12.0f %14.1f\n', net.names{n}, 'SAT', ...
            S.visible_s(n), S.available_s(n), S.max_elev_deg(n));
    else
        fprintf('%-9s %8s %10.0f %12.0f %14s\n', net.names{n}, 'BS', ...
            S.visible_s(n), S.available_s(n), '-');
    end
end

fprintf('\nTime with >= 1 available satellite     : %5.1f %%\n', 100*S.frac_any_sat);
fprintf('Time with >= 1 available base station  : %5.1f %%\n', 100*S.frac_any_bs);
fprintf('Time with >= 1 available node (any)    : %5.1f %%\n', 100*S.frac_any_node);
fprintf('Mean number of available nodes         : %5.2f\n', S.mean_available_nodes);
end
