function R = run_evaluation(cfg, seeds, out_dir)
%RUN_EVALUATION Compare the handover algorithms across scenarios and seeds.
%
%   R = run_evaluation(cfg)                    seeds 101-120, no files
%   R = run_evaluation(cfg, seeds, out_dir)    also writes CSV and figures
%
%   For every scenario level and every seed, one network and one set of
%   links are generated, and ALL algorithms run on exactly those links
%   (common random numbers). Metrics come from evaluate_performance.
%   Differences are paired by seed: diff = intelligent - baseline, reported
%   as mean +- 95 % confidence half-width over seeds.
%
%   Algorithms:
%     baseline   strongest SNR, HYS 3 dB, TTT 2 s
%     smoothed   baseline on 3-sample averaged measurements (isolates the
%                effect of filtering)
%     matched    baseline retuned (cfg.ho_matched) to the proposed method's
%                handover rate on calibration seeds: the fair comparison
%     proposed   multi-criteria score (handover_intelligent)
%
%   Output R.(group): levels, labels, metric names and
%   data(level, algorithm, seed, metric).

if nargin < 2 || isempty(seeds), seeds = 101:120; end
if nargin < 3, out_dir = ''; end

groups = { ...
    'default',  {'default'},             'Default scenario'; ...
    'speed',    {10, 20, 30, 40},        'User speed (m/s)'; ...
    'min_elev', {15, 25, 35, 45},        'Minimum elevation (deg)'; ...
    'fluct',    {0.5, 1, 1.5, 2},        'Fluctuation scale (x default)'; ...
    'coverage', {'none', 'sparse', 'default', 'full'}, 'Terrestrial coverage'};
alg_names = {'Baseline', 'Baseline + smoothing', 'Baseline (matched rate)', 'Proposed'};
metrics = {'n_handovers', 'ho_per_min', 'n_unnecessary', 'n_ping_pong', 'n_forced', ...
           'n_failures', 'outage_s', 'n_rlf', 'mean_snr_db', 'mean_se_eff', ...
           'interruption_s', 'time_on_sat_frac'};

R.alg_names = alg_names;
R.matched = cfg.ho_matched;
R.metrics = metrics;
R.seeds = seeds;
for g = 1:size(groups, 1)
    name = groups{g, 1}; levels = groups{g, 2};
    D = nan(numel(levels), numel(alg_names), numel(seeds), numel(metrics));
    for l = 1:numel(levels)
        for s = 1:numel(seeds)
            c = scenario_config(cfg, name, levels{l});
            c.seed = seeds(s);
            net = generate_network(c);
            links = simulate_links(c, net, simulate_mobility(c));
            cs = c; cs.ho.filter_window = cfg.intel.level_window;
            cm = c; cm.ho.hysteresis_db = cfg.ho_matched.hysteresis_db;
            cm.ho.ttt_s = cfg.ho_matched.ttt_s;
            res = {handover_baseline(c, net, links), ...
                   handover_baseline(cs, net, links), ...
                   handover_baseline(cm, net, links), ...
                   handover_intelligent(c, net, links)};
            res{3}.name = alg_names{3};
            for a = 1:numel(res)
                m = evaluate_performance(c, net, links, res{a});
                for q = 1:numel(metrics)
                    D(l, a, s, q) = m.(metrics{q});
                end
            end
        end
    end
    R.(name).levels = levels;
    R.(name).label = groups{g, 3};
    R.(name).data = D;
    print_group(R, name);
end

if ~isempty(out_dir)
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    write_csv(R, groups(:, 1), fullfile(out_dir, 'evaluation_summary.csv'));
    for g = 2:size(groups, 1)
        plot_group(R, groups{g, 1}, out_dir);
    end
end
end

%% ---------------------------------------------------------------------
function print_group(R, name)
G = R.(name);
q = @(m) find(strcmp(R.metrics, m));
show = {'n_handovers', 'n_unnecessary', 'n_ping_pong', 'n_forced', 'outage_s', 'mean_se_eff'};
heads = {'Handovers', 'Unnecessary', 'Ping-pong', 'Forced', 'Outage s', 'SE b/s/Hz'};
fprintf('\n=== %s (%d seeds) ===\n', G.label, numel(R.seeds));
fprintf('%-10s %-22s', 'Level', 'Algorithm');
fprintf('%14s', heads{:}); fprintf('\n');
for l = 1:numel(G.levels)
    for a = 1:numel(R.alg_names)
        fprintf('%-10s %-22s', level_str(G.levels{l}), R.alg_names{a});
        for i = 1:numel(show)
            x = squeeze(G.data(l, a, :, q(show{i})));
            [mu, hw] = ci95(x(:));
            if strcmp(show{i}, 'mean_se_eff'), fprintf('%8.3f±%5.3f', mu, hw);
            else, fprintf('%8.1f±%5.1f', mu, hw); end
        end
        fprintf('\n');
    end
    ref = [1 3]; lab = {'Proposed - Baseline', 'Proposed - Matched'};
    for j = 1:2
        fprintf('%-10s %-22s', '', lab{j});
        for i = 1:numel(show)
            d = squeeze(G.data(l, 4, :, q(show{i})) - G.data(l, ref(j), :, q(show{i})));
            [mu, hw] = ci95(d(:));
            if strcmp(show{i}, 'mean_se_eff'), fprintf('%+8.3f±%5.3f', mu, hw);
            else, fprintf('%+8.1f±%5.1f', mu, hw); end
        end
        fprintf('\n');
    end
end
end

function write_csv(R, names, file)
fid = fopen(file, 'w');
fprintf(fid, 'group,level,algorithm,metric,mean,ci95_halfwidth,diff_vs_baseline_mean,diff_vs_baseline_ci95,diff_vs_matched_mean,diff_vs_matched_ci95\n');
for g = 1:numel(names)
    G = R.(names{g});
    for l = 1:numel(G.levels)
        for a = 1:numel(R.alg_names)
            for q = 1:numel(R.metrics)
                x = squeeze(G.data(l, a, :, q));
                d = squeeze(G.data(l, a, :, q) - G.data(l, 1, :, q));
                e = squeeze(G.data(l, a, :, q) - G.data(l, 3, :, q));
                [mu, hw] = ci95(x(:));
                [dm, dh] = ci95(d(:));
                [em, eh] = ci95(e(:));
                fprintf(fid, '%s,%s,%s,%s,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n', names{g}, level_str(G.levels{l}), ...
                    R.alg_names{a}, R.metrics{q}, mu, hw, dm, dh, em, eh);
            end
        end
    end
end
fclose(fid);
end

function plot_group(R, name, out_dir)
G = R.(name);
show = {'n_handovers', 'n_unnecessary', 'n_forced', 'outage_s', 'mean_se_eff', 'n_ping_pong'};
titles = {'Handovers', 'Unnecessary handovers', 'Forced handovers', 'Outage time (s)', ...
          'Effective SE (b/s/Hz)', 'Ping-pongs'};
cols = [0.45 0.45 0.45; 0.75 0.60 0.20; 0.35 0.65 0.35; 0.00 0.45 0.74];
mk = {'s-', '^-', 'd-', 'o-'};
x = 1:numel(G.levels);
labels = cellfun(@level_str, G.levels, 'UniformOutput', false);
fig = figure('Name', ['Evaluation: ' G.label]);
for i = 1:numel(show)
    subplot(2, 3, i); hold on; grid on;
    q = find(strcmp(R.metrics, show{i}));
    for a = 1:numel(R.alg_names)
        [mu, hw] = ci95(squeeze(G.data(:, a, :, q)), 2);
        h = errorbar(x + (a - 2.5) * 0.06, mu(:)', hw(:)', mk{a});
        set(h, 'Color', cols(a, :), 'MarkerFaceColor', cols(a, :), 'LineWidth', 1.2);
    end
    set(gca, 'XTick', x, 'XTickLabel', labels);
    xlim([0.5, numel(x) + 0.5]);
    if i > 3, xlabel(G.label); end
    title(titles{i});
    if i == 1, legend(R.alg_names, 'Location', 'best'); end
end
saveas(fig, fullfile(out_dir, ['evaluation_' name '.png']));
end

function s = level_str(v)
if ischar(v), s = v; else, s = sprintf('%g', v); end
end
