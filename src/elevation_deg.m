function [el, range_m] = elevation_deg(sat_pos, user_pos)
%ELEVATION_DEG Elevation angle of a satellite seen from a user (spherical Earth).
%   [el, range_m] = elevation_deg(sat_pos, user_pos)
%   Both inputs are T-by-3 in the same frame. The local vertical is the
%   radial direction of the user.
rel = sat_pos - user_pos;
range_m = sqrt(sum(rel.^2, 2));
up = user_pos ./ sqrt(sum(user_pos.^2, 2));
el = asind(sum(rel .* up, 2) ./ range_m);
end
