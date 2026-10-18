function cfg = config()
%CONFIG Simulation parameters for the integrated LEO + terrestrial handover study.
%
%   cfg = config() returns a struct holding every tunable parameter.
%   All other functions read their parameters from this struct, so a
%   scenario is fully defined by (cfg, cfg.seed).
%
%   Units are given in the field names (_s, _m, _km, _deg, _db, _dbm, ...).
%   The values are simplified, illustrative choices. Where a value is of
%   the same order as a 3GPP study item (TR 38.821, TR 36.814) this is
%   noted, but the model is NOT 3GPP-compliant.

%% Reproducibility
cfg.seed = 42;              % master random seed (each module offsets it)

%% Time
cfg.sim.dt_s       = 1;     % time step (s); one measurement report per step
cfg.sim.duration_s = 1800;  % simulated time (s) = 30 minutes

%% Earth and constants
cfg.const.earth_radius_m   = 6371e3;      % spherical Earth
cfg.const.mu_m3s2          = 3.986004418e14; % Earth gravitational parameter
cfg.const.earth_rate_rads  = 7.2921159e-5;   % Earth rotation rate
cfg.const.c_mps            = 299792458;
cfg.const.boltzmann_dbw    = -228.6;      % 10*log10(k), dBW/K/Hz

%% Study area (reference point of the local East-North frame)
cfg.area.ref_lat_deg = 55.95;   % near Edinburgh (any mid-latitude works)
cfg.area.ref_lon_deg = -3.19;

%% User mobility
% The user follows a polyline road at constant speed. Waypoints are in
% metres in the local East-North frame. If the end of the road is reached
% before the simulation ends, the user stops there.
cfg.mobility.waypoints_m = [  0e3   0.0e3;
                             12e3   1.0e3;
                             24e3  -1.0e3;
                             36e3   0.5e3;
                             45e3   0.0e3 ];   % about 45 km of road
cfg.mobility.speed_mps   = 25;   % 90 km/h
cfg.mobility.ue_height_m = 1.5;

%% LEO satellites
% A small set of satellites arranged in a few orbital planes whose ground
% tracks pass over or near the study area. Only satellites that pass
% during the simulated window are modelled (a full plane would contain
% about 16 satellites at this spacing).
%
% Each plane is defined by:
%   cross_offset_deg : Earth-central angle between the reference point and
%                      the ground track at closest approach (0 = overhead)
%   heading_deg      : direction of travel of the sub-satellite point at
%                      closest approach (0 = north, 90 = east)
%   first_pass_s     : time at which the first satellite of the plane is
%                      at closest approach to the reference point
%   spacing_s        : time between successive satellites in the plane
%   n_sats           : number of satellites in the plane
cfg.sat.altitude_m   = 600e3;
cfg.sat.anchor_each_pass = false; % see generate_network
cfg.sat.min_elev_deg = 25;        % below this the satellite is not usable
cfg.sat.planes = struct( ...
    'cross_offset_deg', {  0.0,   4.0,  -6.0 }, ...
    'heading_deg',      { -10.0, 15.0, 170.0 }, ...
    'first_pass_s',     { 150,   300,   520  }, ...
    'spacing_s',        { 420,   420,   420  }, ...
    'n_sats',           { 5,     4,     3    });

% Satellite link budget (downlink, per-MHz density; S-band, handheld UE).
% EIRP density and G/T are of the same order as TR 38.821 "set-1" LEO-600
% S-band values. They set the absolute SNR level only.
cfg.sat.freq_hz          = 2.0e9;
cfg.sat.eirp_dbw_per_mhz = 34.0;
cfg.sat.ue_gt_dbk        = -31.6;
cfg.sat.misc_loss_db     = 1.0;   % atmospheric + polarisation, lumped
cfg.sat.shadow_std_db    = 3.0;   % log-normal shadowing std
cfg.sat.shadow_corr_s    = 10;    % shadowing correlation time

%% Terrestrial base stations
% Base stations are placed along the road in clusters. Each row of
% clusters_m is [start_along_road  end_along_road  spacing] in metres.
% Between clusters there is no terrestrial coverage (rural gap).
cfg.bs.clusters_m   = [  0e3  10e3  2.5e3;      % town A
                        32e3  45e3  2.5e3 ];    % town B
cfg.bs.lateral_offset_m = 800;    % sites alternate left/right of the road
cfg.bs.position_jitter_m = 300;   % random site placement error (std)
cfg.bs.height_m     = 25;
cfg.bs.max_range_m  = 5000;       % beyond this a cell is not measured

% Terrestrial link budget. Path loss is the classic macro-cell model
% PL = 128.1 + 37.6 log10(d_km) (TR 36.814 style, ~2 GHz).
cfg.bs.tx_power_dbm   = 46;
cfg.bs.ant_gain_dbi   = 15;
cfg.bs.bandwidth_hz   = 20e6;
cfg.bs.ue_nf_db       = 7;
cfg.bs.pl_a_db        = 128.1;
cfg.bs.pl_b_db        = 37.6;
cfg.bs.shadow_std_db  = 8.0;
cfg.bs.shadow_corr_m  = 50;       % Gudmundson decorrelation distance

%% Measurements and access
cfg.meas.noise_std_db   = 1.0;    % residual error after L3 filtering
cfg.link.min_access_snr_db = -6;  % a node below this cannot be selected

%% Baseline handover (strongest signal with hysteresis and time-to-trigger)
% A neighbour triggers a handover when its measured SNR exceeds the
% serving node's measured SNR by more than hysteresis_db, continuously
% for ttt_s seconds (similar in spirit to the 3GPP A3 event). If the
% serving node becomes unavailable, the user switches at once to the
% strongest available node (a forced handover, no time-to-trigger).
cfg.ho.hysteresis_db = 3;
cfg.ho.ttt_s         = 2;
cfg.ho.ping_pong_window_s = 10;   % return to the previous node within
                                  % this time counts as a ping-pong
cfg.ho.filter_window = 1;         % moving-average length (samples) applied
                                  % to measurements; 1 = raw measurements.
                                  % Used only for the "baseline + smoothing"
                                  % comparison in the evaluation.

% Baseline retuned to the proposed method's handover rate. Selected on the
% calibration seeds 1-10 by a fixed rule: among HYS in 0..10 dB and TTT in
% 0..6 s, the setting with no more handovers than the calibrated proposed
% method and the highest effective SE. Used only in the evaluation, as the
% fairest comparison point.
cfg.ho_matched.hysteresis_db = 3;
cfg.ho_matched.ttt_s         = 5;

%% Intelligent handover (multi-criteria score)
% Score of node n at time k (every term lies in [0, 1]):
%   U_n = w_q * q(level_n) + w_p * q(level_n + slope_n * horizon)
%         + w_r * min(T_rem_n, T_cap) / T_cap
% q(S) = min(log2(1 + 10^(S/10)), eta_max) / eta_max  (capped spectral
% efficiency). A switch to n needs
%   U_n - c_n > U_s + margin
% to hold for confirm_s, where c_n is the switching cost of n.
% The weights, trend window, confirmation time, margin and switching
% costs below were selected by calibrate_intelligent.m on calibration
% seeds 1-10 (never on the evaluation seeds 101-120). The prediction
% weight came out as 0: under 8 dB shadowing, short-window SNR trends are
% mostly noise. The term stays implemented and is examined in
% run_sensitivity.
cfg.intel.w_quality    = 0.8;
cfg.intel.w_prediction = 0.0;   % calibration gave this term no weight
cfg.intel.w_remaining  = 0.2;
cfg.intel.level_window = 3;      % samples averaged for the current level
cfg.intel.trend_window = 20;     % samples used for the least-squares trend
cfg.intel.horizon_s    = 5;      % prediction horizon
cfg.intel.max_slope_db_s = 3;    % trend magnitude limit
cfg.intel.trend_t_min  = 2;      % trend used only if |slope| >= 2 std errors
cfg.intel.t_cap_s      = 60;     % remaining service time saturates here
cfg.intel.eta_max      = 6;      % b/s/Hz at which link quality saturates
cfg.intel.cost_switch  = 0.15;   % any handover
cfg.intel.cost_system  = 0.05;   % extra when changing SAT <-> BS
cfg.intel.cost_return  = 0.10;   % extra for returning to the node just left
cfg.intel.return_window_s = 10;
cfg.intel.margin       = 0.10;   % required score advantage
cfg.intel.confirm_s    = 2;      % advantage must last this long

%% Evaluation (shared by every algorithm)
cfg.eval.outage_snr_db      = -6;   % serving true SNR below this = outage
cfg.eval.max_se_bps_hz      = 6;    % spectral efficiency cap
cfg.eval.unnecessary_window_s = 30; % a handover made less than 30 s before
                                    % the source fails counts as needed
                                    % (first version used 10 s; see report)
cfg.eval.unnecessary_gain   = 0.10; % see evaluate_performance
cfg.eval.failure_window_s   = 1;    % handover execution period
% Service interruption per executed handover (s). Simplified assumptions,
% not standard values: intra-system handovers are short, a change of
% system (SAT <-> BS) also needs a new attachment.
cfg.eval.interruption_s.BS_BS   = 0.05;
cfg.eval.interruption_s.SAT_SAT = 0.08;
cfg.eval.interruption_s.inter   = 0.25;
end
