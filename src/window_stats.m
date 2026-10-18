function [level, slope, count, slope_se] = window_stats(M, A, L, W, dt)
%WINDOW_STATS Sliding-window level and trend of measured SNR, per node.
%
%   [level, slope, count] = window_stats(M, A, L, W, dt)
%   M     : T-by-N measured SNR (dB), NaN where the node is unavailable
%   A     : T-by-N availability
%   L     : samples in the level window (mean of available samples in
%           steps k-L+1..k)
%   W     : samples in the trend window (least-squares line through the
%           available samples in steps k-W+1..k)
%   dt    : time step (s)
%   level : T-by-N, NaN where the node is unavailable at step k
%   slope : T-by-N trend in dB/s; 0 when fewer than 3 samples are in the
%           window; NaN where the node is unavailable at step k
%   count : T-by-N number of available samples in the trend window
%   slope_se : T-by-N standard error of the slope (dB/s); Inf when fewer
%           than 3 samples are in the window
%
%   Only past and present samples are used (causal).

[T, N] = size(M);
m = double(A);
y = M; y(~A) = 0;
x = repmat((1:T)' * dt, 1, N) .* m;   % sample time, zero where unavailable

% windowed sums via cumulative sums
wsum = @(Z, n) Z - [zeros(n, N); Z(1:end-n, :)];
cs = @(Z) cumsum(Z, 1);

nL = wsum(cs(m), min(L, T));
sL = wsum(cs(y), min(L, T));
level = sL ./ max(nL, 1);
level(~A) = NaN;

Cm = cs(m); Cx = cs(x); Cy = cs(y); Cxx = cs(x.^2); Cxy = cs(x .* y); Cyy = cs(y.^2);
Wn = min(W, T);
n   = wsum(Cm, Wn);
Sx  = wsum(Cx, Wn);
Sy  = wsum(Cy, Wn);
Sxx = wsum(Cxx, Wn);
Sxy = wsum(Cxy, Wn);
Syy = wsum(Cyy, Wn);
den = n .* Sxx - Sx.^2;
slope = zeros(T, N);
ok = n >= 3 & den > 1e-9;
slope(ok) = (n(ok) .* Sxy(ok) - Sx(ok) .* Sy(ok)) ./ den(ok);
slope(~A) = NaN;
count = n;

% standard error of the slope: sqrt( residual variance / centred Sxx )
slope_se = inf(T, N);
ok3 = ok & n >= 3;
Sxx_c = Sxx(ok3) - Sx(ok3).^2 ./ n(ok3);
Syy_c = Syy(ok3) - Sy(ok3).^2 ./ n(ok3);
sse = max(Syy_c - slope(ok3).^2 .* Sxx_c, 0);
dof = max(n(ok3) - 2, 1);
slope_se(ok3) = sqrt((sse ./ dof) ./ Sxx_c);
end
