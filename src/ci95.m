function [mu, hw] = ci95(x, dim)
%CI95 Mean and half-width of a 95 % confidence interval (Student t).
%   [mu, hw] = ci95(x)       along the first non-singleton dimension
%   [mu, hw] = ci95(x, dim)
%   The t quantile comes from a small table, so no toolbox is needed.
if nargin < 2
    dim = find(size(x) > 1, 1);
    if isempty(dim), dim = 1; end
end
n = size(x, dim);
mu = mean(x, dim);
if n < 2, hw = nan(size(mu)); return; end
t_tab = [12.706 4.303 3.182 2.776 2.571 2.447 2.365 2.306 2.262 2.228 ...
         2.201 2.179 2.160 2.145 2.131 2.120 2.110 2.101 2.093 2.086 ...
         2.080 2.074 2.069 2.064 2.060 2.056 2.052 2.048 2.045 2.042];
dof = n - 1;
if dof <= numel(t_tab), tq = t_tab(dof); else, tq = 1.96; end
hw = tq * std(x, 0, dim) / sqrt(n);
end
