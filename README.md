# Intelligent Handover for Integrated LEO Satellite and Terrestrial Networks

MATLAB simulation study of handover decisions for a mobile user served by both low Earth orbit (LEO) satellites and terrestrial base stations. A conventional strongest-signal rule with hysteresis and time-to-trigger is compared with an interpretable multi-criteria rule, on identical simulated links, over five scenario groups and 20 held-out random seeds.

## Research question

Can an adaptive, multi-criteria handover algorithm improve communication continuity and network performance compared with conventional strongest-signal handover in an integrated LEO satellite and terrestrial network?

## Main findings

- Against the default baseline (HYS 3 dB, TTT 2 s), the proposed rule cuts handovers from 47.2 to 19.6 per run (−58 %), unnecessary handovers from 22.2 to 4.4 and ping-pongs from 13.3 to 0.5. Effective spectral efficiency falls by 1.7 %, from 5.185 to 5.095 b/s/Hz.
- A baseline retuned to the same handover rate (HYS 3 dB, TTT 5 s) matches most of that. Against it, the consistent gain is fewer forced handovers in 11 of 14 scenario levels: 27 % fewer in the default case, 42 % with no terrestrial cells and 53 % at 10 m/s. The gain comes from leaving LEO satellites before they set, using ephemeris-based remaining visibility.
- Over the full handover-versus-capacity trade-off, a tuned baseline is 0.02–0.03 b/s/Hz better at each handover rate. The proposed rule is not a better way to buy fewer handovers. Its value lies in planned satellite handovers.
- SNR-trend prediction was implemented, but calibration gave it zero weight. Under 8 dB shadowing, short-window trends are mostly noise.

All values are means over seeds 101–120. Confidence intervals, every scenario and the reasoning behind each choice are in `docs/technical_report.md`.

## Requirements

- MATLAB R2021a or later, including MATLAB Online. No toolboxes are needed.
- The code also runs in GNU Octave 8.

## Running

From the project folder:

```matlab
run_tests   % 43 checks of the model, both algorithms, the metrics and edge cases
main        % full experiment; a few minutes. Writes figures and CSV to results/
```

Set `RUN_FULL_EVALUATION = false` at the top of `main.m` to run only the single-scenario stages. To repeat the parameter calibration, which takes 10–15 minutes:

```matlab
addpath('src'); calibrate_intelligent(config(), 1:10, 'results/calibration.csv');
```

## Project layout

```
main.m                        runs the whole experiment
config.m                      every simulation, algorithm and evaluation parameter
generate_network.m            satellite orbits and base-station sites
simulate_mobility.m           user trajectory along the road
simulate_links.m              visibility, true and measured SNR, availability
handover_baseline.m           strongest signal with hysteresis and time-to-trigger
handover_intelligent.m        multi-criteria score with switching costs
evaluate_performance.m        metrics, computed from true SNR
run_evaluation.m              all algorithms x scenarios x seeds
run_tradeoff.m                handover rate vs capacity curves
run_sensitivity.m             one-at-a-time sensitivity and ablation
calibrate_intelligent.m       grid search on calibration seeds 1-10
sweep_baseline_parameters.m   baseline over a grid of hysteresis and TTT
plot_scenario.m               map, link model and availability figures
plot_handover.m               link quality, serving node and handovers for one run
plot_decision.m               one decision of the proposed rule, term by term
run_tests.m                   runs the checks in tests/
src/                          geometry, path loss, shadowing, window statistics, helpers
tests/                        model, algorithm, metric and edge-case checks
docs/technical_report.md      problem, models, algorithms, evaluation, results, limitations
```

## Model in brief

- 45 km road driven at 25 m/s for 1800 s: town A, an 18 km rural gap, then town B.
- 12 LEO satellites at 600 km in three planes, minimum elevation 25°, on a spherical rotating Earth. Satellite SNR comes from a free-space link budget with 3 dB time-correlated shadowing.
- 11 base stations, path loss 128.1 + 37.6·log10(d km), 8 dB distance-correlated shadowing, 5 km measurement range.
- Measured SNR is true SNR plus 1 dB error. A node is selectable only when visible with measured SNR ≥ −6 dB.
- Algorithms decide from measured SNR. Metrics use true SNR.
- Each module has its own seeded random stream, so all algorithms see identical data.

## Proposed rule in brief

Each available node gets a score in [0, 1]:

```
U = w_q q(level) + w_p q(level + slope * 5 s) + w_r min(T_remaining, 60 s) / 60 s
q(S) = min(log2(1 + 10^(S/10)), 6) / 6
```

The user switches when another node's score, minus a switching cost, exceeds the serving node's score by a margin for 2 s. The cost is higher for a change between satellite and terrestrial, and for returning to the node just left. For satellites, remaining time comes from the orbit. For base stations it comes from a statistically gated SNR trend. Calibrated values: w = (0.8, 0, 0.2), switching cost 0.15, system-change cost 0.05, margin 0.10.

## Simplifications

This is a simplified simulation, not a 3GPP-compliant model.

- No interference, load, handover signalling, Doppler or propagation delay.
- Forced handovers carry the same interruption as planned ones.
- Interruption times are assumed constants.
- The baseline resembles the A3 event, and some link-budget values are of the same order as TR 38.821 and TR 36.814. No procedure is implemented as specified.
