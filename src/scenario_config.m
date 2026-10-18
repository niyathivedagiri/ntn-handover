function cfg = scenario_config(cfg, group, level)
%SCENARIO_CONFIG Apply one evaluation scenario to a base configuration.
%
%   cfg = scenario_config(cfg, group, level)
%
%   group       level                       what changes
%   'default'   (ignored)                   nothing
%   'speed'     user speed (m/s)            speed; duration = road length /
%                                           speed; passes anchored so they
%                                           continue for the whole run
%   'min_elev'  minimum elevation (deg)     shorter/longer satellite passes
%   'fluct'     scale factor                satellite shadowing, terrestrial
%                                           shadowing and measurement error
%                                           all multiplied by the factor
%   'coverage'  'none' | 'sparse' |          terrestrial deployment
%               'default' | 'full'

switch group
    case 'default'
    case 'speed'
        cfg.mobility.speed_mps = level;
        wp = cfg.mobility.waypoints_m;
        road = sum(sqrt(sum(diff(wp, 1, 1).^2, 2)));
        cfg.sim.duration_s = round(road / level);
        cfg.sat.anchor_each_pass = true;
        for p = 1:numel(cfg.sat.planes)
            P = cfg.sat.planes(p);
            cfg.sat.planes(p).n_sats = max(1, ceil((cfg.sim.duration_s + 200 - P.first_pass_s) / P.spacing_s));
        end
    case 'min_elev'
        cfg.sat.min_elev_deg = level;
    case 'fluct'
        cfg.sat.shadow_std_db = cfg.sat.shadow_std_db * level;
        cfg.bs.shadow_std_db  = cfg.bs.shadow_std_db * level;
        cfg.meas.noise_std_db = cfg.meas.noise_std_db * level;
    case 'coverage'
        switch level
            case 'none',    cfg.bs.clusters_m = zeros(0, 3);
            case 'sparse',  cfg.bs.clusters_m(:, 3) = 4e3;
            case 'default'
            case 'full',    cfg.bs.clusters_m = [0 45e3 2.5e3];
            otherwise, error('scenario_config:level', 'Unknown coverage level %s', level);
        end
    otherwise
        error('scenario_config:group', 'Unknown scenario group %s', group);
end
end
