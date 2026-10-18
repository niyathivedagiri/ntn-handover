function S = run_sensitivity(cfg, seeds, out_dir)
%RUN_SENSITIVITY Parameter sensitivity and ablation of the proposed method.
%
%   S = run_sensitivity(cfg)                    seeds 101-120
%   S = run_sensitivity(cfg, seeds, out_dir)    also saves a figure
%
%   Sensitivity: one parameter changed at a time from cfg, on the default
%   scenario. Weights are kept summing to 1 (see set_param). Ablation: one ingredient removed at a time:
%     with prediction     w_prediction = 0.2 taken from quality (the
%                         calibrated method gives prediction no weight)
%     no remaining time   w_remaining = 0 (weight moved to quality)
%     no saturation       eta_max = 20 b/s/Hz, so q no longer saturates
%                         in the SNR range seen here
%     no switching costs  cost_switch = cost_system = cost_return = 0
%     no trend gate       trend_t_min = 0 (every trend is trusted)

if nargin < 2 || isempty(seeds), seeds = 101:120; end
if nargin < 3, out_dir = ''; end
ns = numel(seeds);

sweeps = { ...
    'cost_switch', [0 0.02 0.05 0.1 0.15 0.2 0.3]; ...
    'margin',      [0 0.02 0.05 0.1 0.15]; ...
    'confirm_s',   [0 1 2 3 5]; ...
    'w_remaining', [0 0.1 0.2 0.3 0.4 0.5]; ...
    'w_prediction', [0 0.1 0.2 0.3]; ...
    't_cap_s',     [20 40 60 120 240]};
ablations = {'Full method', 'With prediction', 'No remaining time', ...
             'No saturation', 'No switching costs', 'No trend gate'};
mnames = {'n_handovers', 'n_unnecessary', 'n_forced', 'outage_s', 'mean_se_eff'};

scen = cell(ns, 1);
for s = 1:ns
    c = cfg; c.seed = seeds(s);
    net = generate_network(c);
    links = simulate_links(c, net, simulate_mobility(c));
    scen{s} = struct('cfg', c, 'net', net, 'links', links);
end

for w = 1:size(sweeps, 1)
    p = sweeps{w, 1}; vals = sweeps{w, 2};
    out = zeros(numel(vals), numel(mnames), ns);
    for i = 1:numel(vals)
        for s = 1:ns
            c = scen{s}.cfg;
            c.intel = set_param(c.intel, p, vals(i));
            out(i, :, s) = run_one(c, scen{s}, mnames);
        end
    end
    S.sweep.(p).values = vals;
    S.sweep.(p).data = out;
end

abl = zeros(numel(ablations), numel(mnames), ns);
for a = 1:numel(ablations)
    for s = 1:ns
        c = scen{s}.cfg;
        switch ablations{a}
            case 'With prediction'
                c.intel.w_quality = c.intel.w_quality + c.intel.w_prediction - 0.2;
                c.intel.w_prediction = 0.2;
            case 'No remaining time'
                c.intel.w_quality = c.intel.w_quality + c.intel.w_remaining; c.intel.w_remaining = 0;
            case 'No saturation'
                c.intel.eta_max = 20;
            case 'No switching costs'
                c.intel.cost_switch = 0; c.intel.cost_system = 0; c.intel.cost_return = 0;
            case 'No trend gate'
                c.intel.trend_t_min = 0;
        end
        abl(a, :, s) = run_one(c, scen{s}, mnames);
    end
end
S.ablation.names = ablations;
S.ablation.data = abl;
S.metrics = mnames;

% print
fprintf('\n=== Sensitivity of the proposed method (default scenario, %d seeds) ===\n', ns);
for w = 1:size(sweeps, 1)
    p = sweeps{w, 1};
    fprintf('%s\n', p);
    fprintf('  %8s %10s %12s %8s %9s %9s\n', 'value', 'Handovers', 'Unnecessary', 'Forced', 'Outage s', 'SE');
    for i = 1:numel(S.sweep.(p).values)
        mu = mean(S.sweep.(p).data(i, :, :), 3);
        fprintf('  %8g %10.1f %12.1f %8.1f %9.2f %9.3f\n', S.sweep.(p).values(i), mu);
    end
end
fprintf('\n=== Ablation (default scenario, %d seeds) ===\n', ns);
fprintf('%-20s %10s %12s %8s %9s %9s\n', 'Variant', 'Handovers', 'Unnecessary', 'Forced', 'Outage s', 'SE');
for a = 1:numel(ablations)
    mu = mean(abl(a, :, :), 3);
    fprintf('%-20s %10.1f %12.1f %8.1f %9.2f %9.3f\n', ablations{a}, mu);
end

if ~isempty(out_dir)
    fig = figure('Name', 'Sensitivity');
    for w = 1:size(sweeps, 1)
        p = sweeps{w, 1};
        subplot(2, 3, w); hold on; grid on;
        mu = mean(S.sweep.(p).data, 3);
        yyaxis_compat(S.sweep.(p).values, mu(:, 1), mu(:, 5));
        xlabel(strrep(p, '_', ' '));
        if w == 1, legend({'Handovers', 'SE x 10'}, 'Location', 'best'); end
        title(sprintf('Sensitivity: %s', strrep(p, '_', ' ')));
    end
    saveas(fig, fullfile(out_dir, 'sensitivity.png'));
end
end

%% ---------------------------------------------------------------------
function v = run_one(c, sc, mnames)
r = handover_intelligent(c, sc.net, sc.links);
m = evaluate_performance(c, sc.net, sc.links, r);
v = cellfun(@(f) m.(f), mnames);
end

function P = set_param(P, name, value)
if strcmp(name, 'w_remaining')
    % keep the weights summing to 1: scale quality and prediction together
    rest = P.w_quality + P.w_prediction;
    if rest > 0
        P.w_quality    = P.w_quality / rest * (1 - value);
        P.w_prediction = P.w_prediction / rest * (1 - value);
    else
        P.w_quality = 1 - value;
    end
elseif strcmp(name, 'w_prediction')
    % weight moved from the quality term (remaining-time weight unchanged)
    P.w_quality = P.w_quality + P.w_prediction - value;
end
P.(name) = value;
end

function yyaxis_compat(x, h, se)
% handovers and 10 x SE on one axis (avoids yyaxis, which Octave lacks)
plot(x, h, 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(x, 10 * se, 's--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
end
