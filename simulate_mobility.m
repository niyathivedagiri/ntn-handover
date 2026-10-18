function mob = simulate_mobility(cfg)
%SIMULATE_MOBILITY User trajectory along the configured road.
%
%   mob = simulate_mobility(cfg)
%
%   Output struct mob:
%     mob.t_s          1-by-T time vector (s)
%     mob.en_m         T-by-2 position in the local East-North frame (m)
%     mob.ecef_m       T-by-3 Earth-fixed position (m)
%     mob.heading_deg  T-by-1 direction of travel
%     mob.speed_mps    T-by-1 speed (0 once the end of the road is reached)
%     mob.dist_m       T-by-1 distance travelled
%
%   The user moves at constant speed along the waypoint polyline and stops
%   at the end of the road.

dt = cfg.sim.dt_s;
t = 0:dt:cfg.sim.duration_s;
wp = cfg.mobility.waypoints_m;
road_len = sum(sqrt(sum(diff(wp, 1, 1).^2, 2)));

s = min(cfg.mobility.speed_mps * t(:), road_len);
[en, hd] = route_position(wp, s);

speed = [diff(s) / dt; 0];
speed(end) = speed(max(end-1, 1));

mob.t_s = t;
mob.en_m = en;
mob.ecef_m = enu_to_ecef(en, cfg.mobility.ue_height_m, ...
    cfg.area.ref_lat_deg, cfg.area.ref_lon_deg, cfg.const.earth_radius_m);
mob.heading_deg = hd;
mob.speed_mps = speed;
mob.dist_m = s;
mob.road_length_m = road_len;
end
