function r = satellite_position_eci(sat, t_s)
%SATELLITE_POSITION_ECI Position of one circular-orbit satellite (m, ECI).
%   r = satellite_position_eci(sat, t_s) returns numel(t_s)-by-3.
%   r(t) = R * (cos(theta) a + sin(theta) b),  theta = n (t - t_pass)
theta = sat.mean_motion_rads * (t_s(:) - sat.t_pass_s);
r = sat.radius_m * (cos(theta) * sat.a + sin(theta) * sat.b);
end
