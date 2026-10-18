function L = fspl_db(d_m, f_hz, c_mps)
%FSPL_DB Free-space path loss in dB: 20*log10(4*pi*d*f/c).
if nargin < 3, c_mps = 299792458; end
L = 20 * log10(4 * pi * d_m .* f_hz ./ c_mps);
end
