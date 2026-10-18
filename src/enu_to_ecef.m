function p_ecef = enu_to_ecef(en_m, height_m, ref_lat_deg, ref_lon_deg, earth_radius_m)
%ENU_TO_ECEF Local East-North positions to Earth-fixed coordinates.
%
%   p_ecef = enu_to_ecef(en_m, height_m, ref_lat_deg, ref_lon_deg, Re)
%   en_m      : N-by-2 [east north] offsets from the reference point (m)
%   height_m  : height above the spherical Earth surface (scalar or N-by-1)
%   p_ecef    : N-by-3 Earth-centred, Earth-fixed position (m)
%
%   Spherical Earth. The local offset is applied on the tangent plane and
%   the result is projected back onto the sphere, which is accurate for
%   the tens-of-kilometres study area used here.

lat = ref_lat_deg; lon = ref_lon_deg;
up    = [cosd(lat)*cosd(lon), cosd(lat)*sind(lon), sind(lat)];
east  = [-sind(lon),          cosd(lon),           0        ];
north = [-sind(lat)*cosd(lon), -sind(lat)*sind(lon), cosd(lat)];

p = earth_radius_m * up + en_m(:,1) * east + en_m(:,2) * north;
p_unit = p ./ sqrt(sum(p.^2, 2));
p_ecef = p_unit .* (earth_radius_m + height_m(:));
end
