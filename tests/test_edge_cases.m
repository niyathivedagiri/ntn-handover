function results = test_edge_cases()
%TEST_EDGE_CASES Full-pipeline runs on unusual scenarios.
%
%   Every algorithm must run, never serve an unavailable node, and produce
%   metrics consistent with its events, when the scenario is degenerate.

checks = { ...
    @check_no_base_stations, ...
    @check_coverage_gaps_cause_link_loss, ...
    @check_stationary_user, ...
    @check_long_run_with_anchored_passes, ...
    @check_no_node_ever_available };

results = struct('name', {}, 'passed', {}, 'message', {});
for k = 1:numel(checks)
    name = func2str(checks{k});
    try
        checks{k}();
        results(end+1) = struct('name', name, 'passed', true, 'message', ''); %#ok<AGROW>
        fprintf('  PASS  %s\n', name);
    catch err
        results(end+1) = struct('name', name, 'passed', false, 'message', err.message); %#ok<AGROW>
        fprintf('  FAIL  %s\n        %s\n', name, err.message);
    end
end
end

%% ---------------------------------------------------------------------
function check_no_base_stations()
cfg = scenario_config(config(), 'coverage', 'none');
[net, links, R, M] = run_all(cfg);
assert(net.n_bs == 0, 'Expected no base stations');
for i = 1:numel(R)
    assert(all(R{i}.serving <= net.n_sat), 'A non-satellite node was served');
    assert(M{i}.by_link.BS_BS + M{i}.by_link.SAT_BS + M{i}.by_link.BS_SAT == 0, 'BS handovers counted');
end
end

function check_coverage_gaps_cause_link_loss()
% Minimum elevation 45 deg leaves periods with no satellite in the rural
% gap: both algorithms must lose and re-establish the link, and the
% outage must be identical (no algorithm can serve a node that is not there).
cfg = scenario_config(config(), 'min_elev', 45);
[~, links, R, M] = run_all(cfg);
none = ~any(links.available, 2);
assert(any(none), 'Test set-up: expected periods with no available node');
for i = 1:numel(R)
    assert(all(R{i}.serving(none) == 0), 'Served while nothing was available');
    assert(M{i}.n_rlf > 0, 'Expected link losses');
    assert(M{i}.outage_s >= sum(none) * cfg.sim.dt_s, 'Outage shorter than the no-coverage time');
end
end

function check_stationary_user()
cfg = config();
cfg.mobility.speed_mps = 0;
[~, ~, R, M] = run_all(cfg);
for i = 1:numel(R)
    assert(M{i}.n_handovers >= 0 && isfinite(M{i}.mean_se_eff), 'Invalid metrics for a stationary user');
end
end

function check_long_run_with_anchored_passes()
cfg = scenario_config(config(), 'speed', 10);
[net, links, ~, M] = run_all(cfg);
assert(cfg.sim.duration_s > 4000, 'Speed scenario should lengthen the run');
assert(mean(any(links.available(:, net.is_sat), 2)) > 0.95, 'Anchored passes should keep satellites in view');
assert(all(cellfun(@(m) isfinite(m.mean_se_eff), M)), 'Invalid metrics on a long run');
end

function check_no_node_ever_available()
cfg = config();
cfg.sim.duration_s = 60;
net = generate_network(cfg);
links = simulate_links(cfg, net, simulate_mobility(cfg));
links.available(:) = false;
links.snr_meas_db(:) = NaN;
links.snr_true_db(:) = NaN;
links.visible(:) = false;
rb = handover_baseline(cfg, net, links);
ri = handover_intelligent(cfg, net, links);
assert(all(rb.serving == 0) && all(ri.serving == 0), 'Served with nothing available');
assert(isempty(rb.events) && isempty(ri.events), 'Events logged with nothing available');
m = evaluate_performance(cfg, net, links, ri);
assert(m.outage_prob == 1 && m.mean_se_eff == 0, 'Expected full outage');
end

%% ---------------------------------------------------------------------
function [net, links, R, M] = run_all(cfg)
net = generate_network(cfg);
links = simulate_links(cfg, net, simulate_mobility(cfg));
R = {handover_baseline(cfg, net, links), handover_intelligent(cfg, net, links)};
M = cell(size(R));
for i = 1:numel(R)
    k = find(R{i}.serving > 0);
    ok = links.available(sub2ind(size(links.available), k, R{i}.serving(k)));
    assert(all(ok), '%s served an unavailable node', R{i}.name);
    M{i} = evaluate_performance(cfg, net, links, R{i});
    assert(M{i}.n_handovers == R{i}.n_handovers, 'Metric and algorithm disagree on handovers');
end
end
