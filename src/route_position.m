function [xy, heading_deg] = route_position(waypoints_m, s_m)
%ROUTE_POSITION Point on a polyline route at a given distance along it.
%
%   [xy, heading_deg] = route_position(waypoints_m, s_m)
%   waypoints_m : K-by-2 [east north] vertices of the route (m)
%   s_m         : vector of distances along the route (m); clipped to
%                 [0, route length]
%   xy          : numel(s_m)-by-2 positions (m)
%   heading_deg : direction of travel (0 = north, 90 = east)

seg = diff(waypoints_m, 1, 1);
seg_len = sqrt(sum(seg.^2, 2));
cum = [0; cumsum(seg_len)];
s = min(max(s_m(:), 0), cum(end));

% index of the segment containing each s
idx = zeros(numel(s), 1);
for k = 1:numel(s)
    j = find(cum <= s(k), 1, 'last');
    idx(k) = min(j, numel(seg_len));
end

frac = (s - cum(idx)) ./ seg_len(idx);
xy = waypoints_m(idx, :) + frac .* seg(idx, :);
heading_deg = mod(atan2d(seg(idx, 1), seg(idx, 2)), 360);
end
