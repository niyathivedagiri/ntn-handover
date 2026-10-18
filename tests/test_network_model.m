function results = test_network_model()
%TEST_NETWORK_MODEL Checks for the network, mobility and link model.
%
%   results = test_network_model() runs every check, prints PASS/FAIL for
%   each and returns a struct array with fields name, passed, message.
%   Reference values were computed independently of the project code.

checks = { ...
    @check_fspl_reference, ...
    @check_overhead_pass_geometry, ...
    @check_slant_range_formula, ...
    @check_pass_duration, ...
    @check_terrestrial_link_budget, ...
    @check_visibility_and_availability_rules, ...
    @check_reproducibility, ...
    @check_mobility, ...
    @check_shadowing_statistics };

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
function check_fspl_reference()
% 600 km at 2 GHz: 20*log10(4*pi*600e3*2e9/c) = 154.0314 dB
L = fspl_db(600e3, 2e9);
assert(abs(L - 154.0314) < 1e-3, 'FSPL %.4f dB, expected 154.0314 dB', L);
end

function check_overhead_pass_geometry()
% A satellite whose ground track passes over a stationary user must reach
% (almost) 90 deg elevation at its pass time, at a range equal to altitude.
cfg = single_satellite_cfg();
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
k = find(mob.t_s == cfg.sat.planes(1).first_pass_s);
el = links.elev_deg(k, 1);
d = links.range_m(k, 1);
assert(el > 89.9, 'Peak elevation %.3f deg, expected ~90 deg', el);
assert(abs(d - (cfg.sat.altitude_m - cfg.mobility.ue_height_m)) < 5, ...
    'Range at zenith %.1f m, expected altitude', d);
end

function check_slant_range_formula()
% Geometry identity for a spherical Earth:
%   d = sqrt(R^2 - r^2 cos^2(el)) - r sin(el),  r = user radius, R = orbit radius
cfg = single_satellite_cfg();
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
r = cfg.const.earth_radius_m + cfg.mobility.ue_height_m;
R = net.sat(1).radius_m;
el = links.elev_deg(:, 1);
mask = el > 0;
d_formula = sqrt(R^2 - r^2 * cosd(el(mask)).^2) - r * sind(el(mask));
err = max(abs(d_formula - links.range_m(mask, 1)));
assert(err < 1, 'Slant range differs from formula by %.3f m', err);
end

function check_pass_duration()
% With Earth rotation switched off, an overhead pass is visible for
%   2*lambda/n,  lambda = acos(r cos(el_min) / R) - el_min
cfg = single_satellite_cfg();
cfg.const.earth_rate_rads = 0;
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
r = cfg.const.earth_radius_m + cfg.mobility.ue_height_m;
R = net.sat(1).radius_m;
emin = cfg.sat.min_elev_deg;
lambda = acos(r * cosd(emin) / R) - deg2rad(emin);
expected = 2 * lambda / net.sat(1).mean_motion_rads;
measured = sum(links.visible(:, 1)) * cfg.sim.dt_s;
assert(abs(measured - expected) <= 2 * cfg.sim.dt_s, ...
    'Visible for %.0f s, expected %.1f s', measured, expected);
end

function check_terrestrial_link_budget()
% 1 km horizontal distance, 23.5 m height difference:
%   SNR = 46 + 15 - (128.1 + 37.6 log10(1.000276)) - (-93.9897) = 26.885 dB
cfg = config();
cfg.mobility.waypoints_m = [0 0; 10 0];
cfg.mobility.speed_mps = 0;
cfg.sim.duration_s = 5;
cfg.sat.planes = cfg.sat.planes(1);
cfg.sat.planes.n_sats = 1;
net = generate_network(cfg);
net.bs.en_m = [1000 0; 7000 0];   % one in range, one beyond max range
net.n_bs = 2;
net.n_nodes = net.n_sat + 2;
net.is_sat = [true(1, net.n_sat), false, false];
net.names = [{net.sat.name}, {'BS-01', 'BS-02'}];
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
snr = links.snr_mean_db(1, net.n_sat + 1);
assert(abs(snr - 26.8852) < 1e-3, 'BS SNR %.4f dB, expected 26.8852 dB', snr);
assert(all(links.visible(:, net.n_sat + 1)), 'BS at 1 km should be visible');
assert(~any(links.visible(:, net.n_sat + 2)), 'BS at 7 km is beyond max range');
assert(~any(links.available(:, net.n_sat + 2)), 'Out-of-range BS must not be available');
end

function check_visibility_and_availability_rules()
cfg = config();
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
Ns = net.n_sat;
below = links.elev_deg < cfg.sat.min_elev_deg;
assert(~any(any(links.visible(:, 1:Ns) & below)), 'Satellite visible below minimum elevation');
assert(~any(any(links.available & ~links.visible)), 'Node available while not visible');
assert(all(isfinite(links.snr_meas_db(links.available))), 'Available node without a measurement');
assert(all(isnan(links.snr_meas_db(~links.available))), 'Unavailable node has a measurement');
assert(all(links.snr_meas_db(links.available) >= cfg.link.min_access_snr_db), ...
    'Available node below access SNR');
assert(all(isfinite(links.snr_true_db(links.visible))), 'Visible node without true SNR');
assert(all(isnan(links.snr_true_db(~links.visible))), 'Invisible node has true SNR');
end

function check_reproducibility()
cfg = config();
[l1, n1] = run_model(cfg);
[l2, n2] = run_model(cfg);
assert(isequaln(l1.snr_meas_db, l2.snr_meas_db), 'Same seed gave different SNR');
assert(isequal(n1.bs.en_m, n2.bs.en_m), 'Same seed gave different BS layout');
cfg.seed = cfg.seed + 100;
l3 = run_model(cfg);
assert(~isequaln(l1.snr_meas_db, l3.snr_meas_db), 'Different seeds gave identical SNR');
end

function check_mobility()
cfg = config();
mob = simulate_mobility(cfg);
expected = min(cfg.mobility.speed_mps * cfg.sim.duration_s, mob.road_length_m);
assert(abs(mob.dist_m(end) - expected) < 1e-6, 'Travelled %.1f m, expected %.1f m', ...
    mob.dist_m(end), expected);
step = sqrt(sum(diff(mob.en_m, 1, 1).^2, 2));
assert(all(step <= cfg.mobility.speed_mps * cfg.sim.dt_s + 1e-6), 'User moved faster than its speed');
cfg.mobility.speed_mps = 0;
mob0 = simulate_mobility(cfg);
assert(all(all(mob0.en_m == mob0.en_m(1, :))), 'Stationary user moved');
cfg.mobility.speed_mps = 1e4;        % reaches the end of the road quickly
mobf = simulate_mobility(cfg);
assert(norm(mobf.en_m(end, :) - cfg.mobility.waypoints_m(end, :)) < 1e-6, ...
    'User did not stop at the end of the road');
end

function check_shadowing_statistics()
rng(7);
z = randn(200000, 1);
sigma = 4; rho = 0.9;
x = correlated_shadowing(z, rho, sigma);
s = std(x);
r = corr_lag1(x);
assert(abs(s - sigma) / sigma < 0.03, 'Shadowing std %.3f, expected %.1f', s, sigma);
assert(abs(r - rho) < 0.01, 'Lag-1 correlation %.3f, expected %.2f', r, rho);
end

%% ---------------------------------------------------------------------
function cfg = single_satellite_cfg()
% One satellite passing directly over a stationary user at the reference point.
cfg = config();
cfg.sat.planes = cfg.sat.planes(1);
cfg.sat.planes.cross_offset_deg = 0;
cfg.sat.planes.first_pass_s = 400;
cfg.sat.planes.n_sats = 1;
cfg.mobility.speed_mps = 0;
cfg.sim.duration_s = 800;
end

function [links, net] = run_model(cfg)
net = generate_network(cfg);
mob = simulate_mobility(cfg);
links = simulate_links(cfg, net, mob);
end

function r = corr_lag1(x)
x = x(:) - mean(x);
r = sum(x(1:end-1) .* x(2:end)) / sum(x.^2);
end
