function cal = calibrate_intelligent(cfg, seeds, save_csv)
%CALIBRATE_INTELLIGENT Grid search for the intelligent algorithm's parameters.
%
%   cal = calibrate_intelligent(cfg)               seeds 1-10
%   cal = calibrate_intelligent(cfg, seeds, csv)   also writes every row
%
%   Uses CALIBRATION seeds only. The evaluation in run_evaluation uses
%   seeds 101-120, which are never seen here, so the reported results are
%   not tuned to the data they are measured on.
%
%   Selection rule (stated before looking at the evaluation):
%     among all configurations whose mean effective spectral efficiency is
%     within se_tolerance (0.10 b/s/Hz, about 2 %) of the default baseline
%     AND whose mean outage time is no more than 0.5 s above the baseline,
%     pick the one with the fewest mean handovers; ties -> higher SE.
%   If no configuration qualifies, the one with the highest SE is chosen
%   and a warning is printed.

if nargin < 2 || isempty(seeds), seeds = 1:10; end
if nargin < 3, save_csv = ''; end
se_tolerance = 0.10;
outage_tolerance_s = 0.5;

% weight simplex (w_q, w_p, w_r), w_r >= 0.1
W = [];
for wq = 0.4:0.1:0.8
    for wp = [0 0.1 0.2]
        wr = round((1 - wq - wp) * 10) / 10;
        if wr >= 0.1 - 1e-9, W(end+1, :) = [wq wp wr]; end %#ok<AGROW>
    end
end
trend_w  = [10 20];
confirm  = [1 2 3];
margin   = [0.05 0.10];
c_switch = [0.05 0.10 0.15];
c_system = [0 0.05];

% scenarios and baseline reference
ns = numel(seeds);
scen = cell(ns, 1);
base = zeros(ns, 3);
for i = 1:ns
    c = cfg; c.seed = seeds(i);
    net = generate_network(c);
    links = simulate_links(c, net, simulate_mobility(c));
    scen{i} = struct('cfg', c, 'net', net, 'links', links);
    m = evaluate_performance(c, net, links, handover_baseline(c, net, links));
    base(i, :) = [m.n_handovers, m.mean_se_eff, m.outage_s];
end
ref = mean(base, 1);
fprintf('Calibration baseline (seeds %d-%d): %.1f handovers, SE %.3f b/s/Hz, outage %.1f s\n', ...
    seeds(1), seeds(end), ref(1), ref(2), ref(3));

rows = [];
for tw = trend_w
    F = cell(ns, 1);
    for i = 1:ns
        c = scen{i}.cfg; c.intel.trend_window = tw;
        F{i} = handover_features(c, scen{i}.net, scen{i}.links);
    end
    for a = 1:size(W, 1)
      for cf = confirm
        for mg = margin
          for cs = c_switch
            for cy = c_system
              acc = zeros(1, 4);
              for i = 1:ns
                  c = scen{i}.cfg;
                  c.intel.trend_window = tw;
                  c.intel.w_quality = W(a,1); c.intel.w_prediction = W(a,2); c.intel.w_remaining = W(a,3);
                  c.intel.confirm_s = cf; c.intel.margin = mg;
                  c.intel.cost_switch = cs; c.intel.cost_system = cy;
                  r = handover_intelligent(c, scen{i}.net, scen{i}.links, F{i});
                  m = evaluate_performance(c, scen{i}.net, scen{i}.links, r);
                  acc = acc + [m.n_handovers, m.mean_se_eff, m.outage_s, m.n_forced] / ns;
              end
              rows(end+1, :) = [W(a,:), tw, cf, mg, cs, cy, acc]; %#ok<AGROW>
            end
          end
        end
      end
    end
end

names = {'w_quality','w_prediction','w_remaining','trend_window','confirm_s', ...
         'margin','cost_switch','cost_system','handovers','se_eff','outage_s','forced'};
ok = rows(:,10) >= ref(2) - se_tolerance & rows(:,11) <= ref(3) + outage_tolerance_s;
if any(ok)
    cand = find(ok);
    [~, o] = sortrows([rows(cand, 9), -rows(cand, 10)]);
    best = cand(o(1));
else
    warning('calibrate_intelligent:none', 'No configuration met the tolerances; choosing highest SE.');
    [~, best] = max(rows(:, 10));
end

cal.names = names;
cal.rows = rows;
cal.qualifies = ok;
cal.baseline = ref;
cal.best = cell2struct(num2cell(rows(best, :)), names, 2);
cal.seeds = seeds;

fprintf('%d configurations, %d meet the tolerances.\n', size(rows, 1), sum(ok));
fprintf('Selected: w = [%.1f %.1f %.1f], trend %d, confirm %g s, margin %.2f, costs %.2f / %.2f\n', ...
    rows(best,1:3), rows(best,4), rows(best,5), rows(best,6), rows(best,7), rows(best,8));
fprintf('          %.1f handovers, SE %.3f b/s/Hz, outage %.1f s, forced %.1f\n', rows(best, 9:12));

if ~isempty(save_csv)
    fid = fopen(save_csv, 'w');
    fprintf(fid, '%s\n', strjoin(names, ','));
    fprintf(fid, [repmat('%.4f,', 1, numel(names) - 1) '%.4f\n'], rows');
    fclose(fid);
end
end
