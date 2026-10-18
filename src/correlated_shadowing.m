function x = correlated_shadowing(z, rho, sigma)
%CORRELATED_SHADOWING First-order autoregressive (Gauss-Markov) shadowing.
%
%   x = correlated_shadowing(z, rho, sigma)
%   z     : T-by-N independent standard normal draws (one column per link)
%   rho   : scalar or T-by-1 correlation between consecutive samples
%   sigma : standard deviation of the stationary process (dB)
%
%   x(1,:) = sigma*z(1,:)
%   x(k,:) = rho(k)*x(k-1,:) + sigma*sqrt(1-rho(k)^2)*z(k,:)
%
%   Every sample has variance sigma^2 and the correlation between samples
%   k and k+1 is rho(k). With rho = exp(-dt/tau) this is the standard
%   exponential correlation model (Gudmundson when tau is a distance).

[T, ~] = size(z);
if isscalar(rho), rho = rho * ones(T, 1); end
x = zeros(size(z));
x(1, :) = sigma * z(1, :);
for k = 2:T
    x(k, :) = rho(k) * x(k-1, :) + sigma * sqrt(1 - rho(k)^2) * z(k, :);
end
end
