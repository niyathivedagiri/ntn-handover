function p_eci = ecef_to_eci(p_ecef, t_s, earth_rate_rads)
%ECEF_TO_ECI Rotate Earth-fixed positions into the inertial frame.
%   p_eci = ecef_to_eci(p_ecef, t_s, we): p_ecef is T-by-3, t_s is T-by-1.
%   The two frames coincide at t = 0; the Earth rotates about z.
ang = earth_rate_rads * t_s(:);
c = cos(ang); s = sin(ang);
p_eci = [c .* p_ecef(:,1) - s .* p_ecef(:,2), ...
         s .* p_ecef(:,1) + c .* p_ecef(:,2), ...
         p_ecef(:,3)];
end
