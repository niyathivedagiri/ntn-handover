function net = generate_network(cfg)
%GENERATE_NETWORK Build the satellite constellation and terrestrial sites.
%
%   net = generate_network(cfg)
%
%   Output struct net:
%     net.sat(i)     satellite i: orbit vectors a, b (unit, ECI), radius_m,
%                    mean_motion_rads, t_pass_s, plane, name
%     net.bs.en_m    Nbs-by-2 site positions in the local East-North frame
%     net.bs.height_m
%     net.n_sat, net.n_bs, net.n_nodes
%     net.is_sat     1-by-N logical, true for satellite nodes
%     net.names      1-by-N cell of node names
%
%   Node ordering everywhere in the project is [satellites, base stations].
%
%   Satellite orbits are circular. The ECI frame coincides with the ECEF
%   frame at t = 0, and the Earth rotates about the z axis. For each plane
%   the orbit is constructed so that, at the plane's first pass time, the
%   orbit's closest point to the reference location lies at an Earth-central
%   angle cross_offset_deg from it, with the satellite moving along
%   heading_deg. Later satellites of the same plane follow the same orbit,
%   spaced in time by spacing_s, so Earth rotation shifts their ground
%   tracks slightly, as it would in reality.
%
%   Option cfg.sat.anchor_each_pass (default false): every satellite's pass
%   is constructed at its own pass time, so passes repeat with the same
%   geometry however long the simulation runs. This stands for a larger
%   constellation in which another plane takes over the same track, and
%   is used only for the speed scenarios, which need long simulations.

Re = cfg.const.earth_radius_m;
R  = Re + cfg.sat.altitude_m;
n_mean = sqrt(cfg.const.mu_m3s2 / R^3);     % rad/s
we = cfg.const.earth_rate_rads;

lat = cfg.area.ref_lat_deg; lon = cfg.area.ref_lon_deg;
up0    = [cosd(lat)*cosd(lon), cosd(lat)*sind(lon), sind(lat)];
east0  = [-sind(lon), cosd(lon), 0];
north0 = [-sind(lat)*cosd(lon), -sind(lat)*sind(lon), cosd(lat)];

%% Satellites
anchor_each = isfield(cfg.sat, 'anchor_each_pass') && cfg.sat.anchor_each_pass;
sat = struct('name', {}, 'plane', {}, 'a', {}, 'b', {}, 'radius_m', {}, ...
             'mean_motion_rads', {}, 't_pass_s', {});
planes = cfg.sat.planes;
for p = 1:numel(planes)
    t_ref = planes(p).first_pass_s;
    Rz = rot_z(we * t_ref);
    u = (Rz * up0')';  e = (Rz * east0')';  nn = (Rz * north0')';

    h = planes(p).heading_deg;
    d = cosd(h) * nn + sind(h) * e;          % direction of travel
    c = cross(u, d);                          % cross-track direction
    delta = planes(p).cross_offset_deg;
    a = cosd(delta) * u + sind(delta) * c;    % closest-approach direction
    b = d;                                    % orthogonal to a, in-plane

    for k = 1:planes(p).n_sats
        if anchor_each
            % recompute the geometry at this satellite's own pass time, so
            % every pass of the plane has the same closest approach
            t_k = t_ref + (k - 1) * planes(p).spacing_s;
            Rz = rot_z(we * t_k);
            u = (Rz * up0')';  e = (Rz * east0')';  nn = (Rz * north0')';
            d = cosd(h) * nn + sind(h) * e;
            c = cross(u, d);
            a = cosd(delta) * u + sind(delta) * c;
            b = d;
            t_pass = t_k;
        else
            t_pass = t_ref + (k - 1) * planes(p).spacing_s;
        end
        i = numel(sat) + 1;
        sat(i).name = sprintf('SAT-%d.%d', p, k);
        sat(i).plane = p;
        sat(i).a = a / norm(a);
        sat(i).b = b / norm(b);
        sat(i).radius_m = R;
        sat(i).mean_motion_rads = n_mean;
        sat(i).t_pass_s = t_pass;
    end
end

%% Terrestrial base stations
rng(cfg.seed + 1);   % network layout has its own random stream
en = zeros(0, 2);
side = 1;
for r = 1:size(cfg.bs.clusters_m, 1)
    s_sites = cfg.bs.clusters_m(r,1):cfg.bs.clusters_m(r,3):cfg.bs.clusters_m(r,2);
    for s = s_sites
        [xy, hd] = route_position(cfg.mobility.waypoints_m, s);
        left = [-cosd(hd), sind(hd)];        % unit normal to the road
        pos = xy + side * cfg.bs.lateral_offset_m * left ...
              + cfg.bs.position_jitter_m * randn(1, 2);
        en(end+1, :) = pos; %#ok<AGROW>
        side = -side;
    end
end

net.sat = sat;
net.bs.en_m = en;
net.bs.height_m = cfg.bs.height_m;
net.n_sat = numel(sat);
net.n_bs = size(en, 1);
net.n_nodes = net.n_sat + net.n_bs;
net.is_sat = [true(1, net.n_sat), false(1, net.n_bs)];
bs_names = arrayfun(@(k) sprintf('BS-%02d', k), 1:net.n_bs, 'UniformOutput', false);
net.names = [{sat.name}, bs_names];
end

function R = rot_z(theta)
R = [cos(theta) -sin(theta) 0;
     sin(theta)  cos(theta) 0;
     0           0          1];
end
