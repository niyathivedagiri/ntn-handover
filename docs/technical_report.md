# Intelligent Handover for Integrated LEO Satellite and Terrestrial Networks — Technical Report

## Summary

**Answer to the research question: partly.** The multi-criteria rule cuts handovers by 58 % against a standard strongest-signal baseline. A baseline retuned to the same handover rate matches most of that. The lasting gain is 27–53 % fewer forced handovers, obtained by leaving LEO satellites before they set.

- **Setup.** One user, 45 km, 12 LEO satellites at 600 km and 11 base stations. Every algorithm runs on identical links. Results use 20 held-out seeds and five scenario groups, with paired 95 % confidence intervals.
- **Versus the default baseline** (HYS 3 dB, TTT 2 s): handovers 47.2 → 19.6, unnecessary handovers 22.2 → 4.4, ping-pongs 13.3 → 0.5, effective SE 5.185 → 5.095 b/s/Hz (−1.7 %).
- **Versus a baseline retuned to the same rate** (HYS 3 dB, TTT 5 s): forced handovers are significantly lower in 11 of 14 scenario levels, for example 3.3 → 2.4 in the default case and 5.9 → 2.8 at 10 m/s. Handovers, ping-pongs and outage are statistically equal in most levels. SE is equal or up to 0.05 b/s/Hz (1 %) lower.
- **Trade-off.** Over the full handover-versus-capacity curve, a tuned baseline is 0.02–0.03 b/s/Hz better at each handover rate. The proposed rule is not a better way to buy fewer handovers. Its value lies in planning satellite handovers ahead of time.
- **Negative result reported.** Calibration gave the SNR-trend prediction term zero weight. Under 8 dB shadowing, short-window trends are mostly noise. Useful prediction came from satellite ephemeris instead.

## Problem and research question

A user served by both LEO satellites and terrestrial base stations has to choose its serving node continuously. A satellite stays visible for only a few minutes. Terrestrial cells fluctuate strongly because of shadowing. Switching on every small change in signal strength produces frequent and often useless handovers. Switching too rarely leaves the user on a link that is about to fail.

**Research question.** Can an adaptive, multi-criteria handover algorithm improve communication continuity and network performance compared with conventional strongest-signal handover in an integrated LEO satellite and terrestrial network?

The study answers this in simulation. Both algorithms run on identical link data, and the evaluation uses metrics defined before the comparison. The model is simplified and is not 3GPP-compliant. Where a parameter or a rule resembles a 3GPP concept, the report says so, and it does not claim conformance.

## System model

One user drives 45 km at 25 m/s for 1800 s, through town A (base stations at 0 to 10 km), an 18 km rural gap with no terrestrial cells, and town B (32 to 45 km). Twelve LEO satellites at 600 km pass overhead in three orbital planes. Every node is compared on downlink SNR in dB, and the simulation steps once per second, with one measurement report per step.

**Satellites.** The model uses a spherical Earth that rotates at the sidereal rate, and circular orbits. Each plane is defined by how far its ground track passes from the study area, its direction of travel, its first pass time and the spacing between satellites. A satellite is visible when its elevation is at least 25 degrees. Elevation and slant range come from the inertial positions of the satellite and the user.

```
SNR_sat = EIRP_MHz + G/T - FSPL(d) - L_misc - 10 log10(k) - 60 + X_sat
FSPL(d) = 20 log10(4 pi d f / c)
```

X_sat is log-normal shadowing with a 3 dB standard deviation, correlated in time by exp(−Δt / 10 s).

**Base stations.** Sites alternate between the two sides of the road, 800 m from it, with 300 m of random placement error. A cell is measured within 5 km.

```
SNR_bs = P_t + G_t - (128.1 + 37.6 log10(d_km)) - (-174 + 10 log10(B) + NF) + X_bs
```

X_bs is log-normal shadowing with an 8 dB standard deviation, correlated over distance by exp(−Δd / 50 m) (Gudmundson model).

**Measurements and availability.** Measured SNR is the true SNR plus Gaussian error with a 1 dB standard deviation. A node is available only when it is visible and its measured SNR is at least −6 dB. Unavailable nodes carry no measurement, so no algorithm can select them. Algorithms decide from measured SNR. Every metric is computed from true SNR.

| Parameter | Value | Note |
| --- | --- | --- |
| Satellite altitude, minimum elevation | 600 km, 25° | 12 satellites in 3 planes |
| Satellite EIRP density, UE G/T | 34 dBW/MHz, −31.6 dB/K | same order as TR 38.821 S-band LEO-600 values |
| Carrier frequency | 2 GHz | FSPL only |
| Satellite shadowing | 3 dB, 10 s correlation | time-correlated |
| BS power, antenna gain | 46 dBm, 15 dBi | macro cell |
| BS bandwidth, UE noise figure | 20 MHz, 7 dB | noise floor −94 dBm |
| BS path loss | 128.1 + 37.6 log10(d km) | TR 36.814-style macro model |
| BS shadowing | 8 dB, 50 m decorrelation | distance-correlated |
| Measurement error | 1 dB | after layer-3 filtering |
| Access / outage threshold | −6 dB | true SNR for outage |

Random streams are seeded per module (layout, shadowing, measurement error) from one master seed, so both algorithms always see identical data. Figures: `results/scenario_map.png`, `results/link_model.png`, `results/node_availability.png`.

## Baseline handover

The baseline switches to the strongest neighbour once it has beaten the serving node by a hysteresis margin for a whole time-to-trigger. It resembles the 3GPP A3 event, but it is not an implementation of the standard procedure. Defaults: HYS = 3 dB, TTT = 2 s.

1. With no serving node, connect to the strongest available node.
2. If the serving node becomes unavailable, switch at once to the strongest available node. This is a forced handover, with no time-to-trigger. If no node is available, the link is lost until one returns.
3. Otherwise, neighbour n meets the entering condition when the inequality below holds. A per-neighbour counter must reach round(TTT/dt) + 1 consecutive samples. The strongest qualifying neighbour is chosen, and all counters reset after a handover.

```
M_n(k) > M_s(k) + HYS
```

Shadowing and measurement error make two similar nodes swap rank many times a minute. Hysteresis requires a clear margin, and time-to-trigger requires that margin to last, so short-lived crossings are filtered out. The price is a slower reaction to a link that really has become worse. On the default scenario, raising HYS/TTT from 0 dB/0 s to 3 dB/2 s cuts handovers from 366 to 42 and ping-pongs from 217 to 9, while mean measured serving SNR falls from 22.2 to 21.0 dB (`results/baseline_parameter_sweep.png`).

A comparison case, "baseline + smoothing", applies the same 3-sample moving average that the proposed method uses. This separates the benefit of the decision rule from the benefit of simple filtering.

## Proposed multi-criteria handover

The proposed method gives every available node a score between 0 and 1. It switches only when another node's score beats the serving node's by more than the cost of switching, and only if that lead lasts. It uses the same measurements as the baseline, plus satellite ephemeris, which an NTN terminal can know.

```
U_n(k) = w_q q(M̄_n(k)) + w_p q(M̄_n(k) + ŝ_n(k) h) + w_r min(T_rem_n(k), T_cap) / T_cap
q(S)   = min(log2(1 + 10^(S/10)), eta_max) / eta_max,   q(S) = 0 for S < -6 dB
```

| Term | Meaning | How it is computed |
| --- | --- | --- |
| Quality q(M̄) | Capacity the link offers now | M̄ = mean of the last 3 measurements. Saturates at eta_max = 6 b/s/Hz (about 18 dB), so 25 dB vs 40 dB counts as equal. |
| Predicted quality q(M̄ + ŝh) | Capacity expected h = 5 s ahead | ŝ = least-squares slope over the last 20 samples. Set to 0 unless \|ŝ\| ≥ 2 standard errors, and limited to ±3 dB/s. |
| Remaining time T_rem | How long the node will stay usable | Satellites: time until elevation drops below 25°, from the orbit. Base stations: time until the gated trend reaches −6 dB. Capped at 60 s. |

All three terms lie in [0, 1] and the weights sum to 1, so scores of satellites and base stations are directly comparable. The serving node s is never charged a cost. Any other node n is charged a cost that depends on what kind of switch it would be:

```
c_n = c_sw + c_sys [type(n) ≠ type(s)] + c_ret [n was left < 10 s ago]
G_n = U_n - c_n - U_s
```

1. With no serving node, connect to the highest-scoring available node.
2. If the serving node becomes unavailable, switch at once to the highest-scoring available node (a forced handover).
3. Otherwise, let n* = argmax G_n. Switch when G_n* > margin for round(confirm/dt) + 1 consecutive steps with the same n*.

Two design choices do most of the work. First, the capped quality term stops the algorithm from chasing SNR it cannot use: between two links that both exceed 18 dB, the gain is exactly zero. Second, the remaining-time term lowers a satellite's score in the last minute of its pass. The user then moves in a planned handover instead of waiting to be forced off. `results/decision_explanation.png` shows one such decision, term by term.

**Weight selection.** Weights and decision parameters come from a grid of 1008 configurations, evaluated on calibration seeds 1–10. The evaluation uses seeds 101–120, which the calibration never saw. The rule was fixed before calibration: among configurations whose mean effective spectral efficiency is within 0.10 b/s/Hz (about 2 %) of the baseline, and whose outage is at most 0.5 s higher, choose the one with the fewest handovers. 400 configurations qualified.

| Parameter | Selected | Grid |
| --- | --- | --- |
| w_q, w_p, w_r | 0.8, 0.0, 0.2 | simplex, step 0.1, w_r ≥ 0.1 |
| Trend window | 20 samples | 10, 20 |
| Confirmation time | 2 s | 1, 2, 3 s |
| Margin | 0.10 | 0.05, 0.10 |
| c_sw, c_sys | 0.15, 0.05 | {0.05, 0.10, 0.15}, {0, 0.05} |
| c_ret, return window | 0.10, 10 s | fixed |

Calibration gave the prediction term zero weight. The best qualifying configurations with w_p = 0.1 and 0.2 needed 23.1 and 23.5 handovers, against 22.2. In this model, 8 dB shadowing that decorrelates every 50 m hides the real path-loss trend of a moving user, which is about 0.2 dB/s. A 10–20 s SNR trend therefore adds noise rather than foresight. The term remains in the code, and the sensitivity study examines it. Prediction that works here comes from the ephemeris, through the remaining-time term.

**Development note.** The first version, with 10-sample trends and no significance gate, made about 2.5 times more handovers than the baseline. Diagnosis showed that the base-station remaining-time term swung by about 0.12 per second, driven by trend noise of 1.3 dB/s. The significance gate and the longer window were the response. The switching costs were not simply raised to hide the problem.

## Evaluation method

Every comparison runs all algorithms on the same generated links. Results use 20 evaluation seeds (101–120) that the calibration never saw, and differences are paired by seed: mean ± 95 % confidence half-width, using a Student-t quantile. Metrics use the true SNR, while algorithms only see the measured SNR.

**Algorithms compared.**

- **Baseline:** strongest SNR with HYS 3 dB and TTT 2 s.
- **Baseline + smoothing:** the same rule on 3-sample averaged measurements, to isolate the effect of filtering.
- **Baseline (matched rate):** the strongest-signal rule retuned to HYS 3 dB and TTT 5 s. The setting was chosen on the calibration seeds by a fixed rule: no more handovers than the proposed method, with the highest effective SE among the 70 (HYS, TTT) pairs tried. This is the fair comparison, because any rule can trade handovers for capacity.
- **Proposed:** the multi-criteria score.

| Metric | Definition |
| --- | --- |
| Handovers | Executed handovers: triggered plus forced. Connection, loss and re-establishment events are not handovers. |
| Unnecessary handover | A triggered handover A→B where A stayed usable (visible, true SNR ≥ −6 dB) for the next 30 s, and B's mean SE over those 30 s was at most 10 % above A's. |
| Ping-pong | A→B followed by B→A within 10 s. |
| Forced handover | Switch made because the serving node became unavailable. |
| Handover failure | The target's true SNR falls below −6 dB within 1 s of execution. |
| Outage | A step with no serving node, or with serving true SNR below −6 dB. |
| Spectral efficiency (SE) | min(log2(1 + SNR), 6) b/s/Hz from true SNR; 0 in outage. Using b/s/Hz keeps the different satellite and terrestrial bandwidths out of the comparison. |
| Effective SE | Mean SE minus the SE lost to handover interruptions: 0.05 s BS↔BS, 0.08 s SAT↔SAT, 0.25 s between systems (assumed values). |

**Scenarios.** Each group changes one factor from the default, and each level runs 20 seeds.

| Group | Levels | What changes |
| --- | --- | --- |
| User speed | 10, 20, 30, 40 m/s | The same 45 km road. Duration = road length / speed, and satellite passes repeat with the same geometry. |
| Satellite visibility | Minimum elevation 15°, 25°, 35°, 45° | Pass length; 35° and above leaves gaps with no satellite. |
| Signal fluctuation | 0.5×, 1×, 1.5×, 2× | Satellite and terrestrial shadowing and measurement error, all scaled together. |
| Terrestrial coverage | None, sparse (4 km spacing), default (2.5 km), full road | Base-station deployment. |

Network load is not modelled, so there is no load scenario and no congestion term in the score.

**Validating the metrics.** Ten hand-built cases check each definition against values worked out by hand: outage counting, the SE cap, interruption loss, the three unnecessary-handover conditions, failure inside and outside the execution window, and ping-pong timing. A first version of the unnecessary-handover rule used a 10 s window. It counted a planned move off a satellite that set 25 s later as "unnecessary", even though a handover was coming anyway. The window was lengthened to 30 s for both algorithms, before the final comparison.

## Results

Against the default baseline, the proposed method cuts handovers by 58 % and ping-pongs by 96 %, at 1.7 % lower effective SE. Against a baseline retuned to the same handover rate, almost all of that advantage disappears. What remains is consistently fewer forced handovers.

| Default scenario, 20 seeds | Handovers | Unnecessary | Ping-pongs | Forced | Outage (s) | Effective SE (b/s/Hz) |
| --- | --- | --- | --- | --- | --- | --- |
| Baseline (HYS 3 dB, TTT 2 s) | 47.2 ± 2.6 | 22.2 ± 2.0 | 13.3 ± 1.9 | 2.5 ± 0.4 | 0.0 | 5.185 ± 0.027 |
| Baseline + smoothing | 51.5 ± 2.9 | 24.9 ± 2.6 | 16.4 ± 2.1 | 2.6 ± 0.4 | 0.0 | 5.156 ± 0.028 |
| Baseline, matched rate (HYS 3 dB, TTT 5 s) | 18.9 ± 1.3 | 3.8 ± 1.0 | 0.8 ± 0.3 | 3.3 ± 0.5 | 0.0 | 5.104 ± 0.025 |
| Proposed | 19.6 ± 0.8 | 4.4 ± 0.8 | 0.5 ± 0.4 | 2.4 ± 0.6 | 0.1 ± 0.1 | 5.095 ± 0.024 |

Values are means ± 95 % confidence half-widths over seeds 101–120. Smoothing alone makes the baseline slightly worse: the 3-sample average adds lag without removing the shadowing that drives the extra handovers.

Proposed minus matched baseline, paired over 20 seeds (mean ± 95 % CI):

| Scenario | Forced handovers | Effective SE (b/s/Hz) | Handovers |
| --- | --- | --- | --- |
| Default | −0.95 ± 0.62 | −0.009 ± 0.016 | +0.75 ± 1.32 |
| Speed 10 m/s | −3.15 ± 0.55 | −0.041 ± 0.009 | −5.35 ± 2.71 |
| Speed 20 m/s | −1.00 ± 0.50 | −0.048 ± 0.020 | +0.05 ± 1.66 |
| Speed 30 m/s | −0.65 ± 0.55 | −0.033 ± 0.014 | +0.45 ± 0.88 |
| Speed 40 m/s | −0.80 ± 0.54 | −0.014 ± 0.022 | −1.10 ± 1.14 |
| Minimum elevation 15° | −0.50 ± 0.36 | −0.024 ± 0.018 | +0.15 ± 1.56 |
| Minimum elevation 35° | −1.00 ± 0.63 | −0.006 ± 0.013 | +1.05 ± 1.06 |
| Minimum elevation 45° | −0.50 ± 0.32 | −0.002 ± 0.013 | +1.30 ± 0.89 |
| Fluctuation 0.5× | −0.65 ± 0.28 | −0.052 ± 0.015 | +0.00 ± 0.15 |
| Fluctuation 1.5× | +0.35 ± 1.62 | −0.021 ± 0.014 | +6.25 ± 2.42 |
| Fluctuation 2× | −0.80 ± 2.11 | −0.015 ± 0.018 | +2.80 ± 2.87 |
| No terrestrial cells | −1.40 ± 0.41 | +0.010 ± 0.007 | −1.30 ± 1.03 |
| Sparse cells (4 km) | −1.20 ± 0.58 | −0.008 ± 0.019 | +1.80 ± 1.40 |
| Full terrestrial coverage | +0.00 ± 0.57 | −0.030 ± 0.019 | +1.95 ± 1.33 |

The full per-scenario tables are in `results/evaluation_summary.csv`, with plots in `results/evaluation_*.png`.

- **Forced handovers.** Significantly fewer in 11 of 14 scenario levels. The largest cuts are at 10 m/s (5.9 → 2.75, −53 %) and with no terrestrial cells (3.3 → 1.9, −42 %). The cause is the ephemeris-based remaining-time term: the user leaves a satellite before it sets, instead of being pushed off. Raising HYS or TTT does the opposite, because a sticky rule holds on to a setting satellite longer.
- **Handovers, unnecessary handovers, ping-pongs and outage.** Mostly no significant difference. Two exceptions: at 10 m/s the proposed method makes 5.4 fewer handovers, and at 1.5× fluctuation it makes 6.2 more.
- **Effective SE.** Equal in 6 levels, higher in 1 (no terrestrial cells, +0.010 b/s/Hz), and lower in 7, by 0.02–0.05 b/s/Hz (at most 1 %). The losses appear where links are steady (0.5× fluctuation) or terrestrial coverage is dense. In those cases the switching cost keeps the user on an adequate link a little longer than the retuned baseline would.
- **Handover failures.** Zero for every algorithm and scenario. In this model a target that passes the access check almost never drops below −6 dB within 1 s, so the metric does not discriminate.

The forced-handover gain does not show up in SE or outage, because the model charges a forced handover the same interruption as a planned one. In a real network, a forced handover happens after the serving link is already lost, without preparation, and usually costs much more. The benefit measured here is therefore real but unpriced.

## Sensitivity and ablation

As a handover-versus-capacity trade-off, the proposed method's curve lies slightly below a tuned baseline's (`results/tradeoff.png`). Its decision rule is not a better way to buy fewer handovers. What it adds is a different kind of decision: leaving satellites before they set.

Every point on the proposed curve, except the most aggressive one, has a baseline setting with no more handovers, no more outage and 0.02–0.03 b/s/Hz more effective SE. The two curves are close, and within this model neither rule improves on the other's capacity at a given rate.

| Variant (default scenario, 20 seeds) | Handovers | Unnecessary | Forced | Outage (s) | Effective SE (b/s/Hz) |
| --- | --- | --- | --- | --- | --- |
| Full method (as calibrated) | 19.6 | 4.4 | 2.4 | 0.10 | 5.095 |
| With prediction (w_p = 0.2) | 20.8 | 5.5 | 2.2 | 0.10 | 5.095 |
| No remaining time (w_r = 0) | 21.1 | 5.0 | 2.7 | 0.05 | 5.101 |
| No saturation (eta_max = 20) | 15.8 | 1.6 | 4.2 | 0.05 | 5.033 |
| No switching costs | 39.2 | 16.9 | 2.0 | 0.05 | 5.143 |
| No trend gate | 20.1 | 4.8 | 2.4 | 0.10 | 5.095 |

- **Switching costs** carry most of the handover reduction. Without them, handovers double.
- **Saturation** of the quality term matters for capacity. Without it, the score is dominated by raw SNR differences between strong links. The method then holds on to satellites, forced handovers almost double, and SE drops by 0.06 b/s/Hz.
- **Remaining time** lowers forced handovers by 0.3 per run at w_r = 0.2, and by 0.6 at w_r = 0.3. Above 0.3, it starts to cost handovers and SE.
- **Prediction** brings no measurable gain. A weight of 0.2 adds 1.2 handovers and removes 0.2 forced ones. The trend gate changes almost nothing once w_p = 0, because it now acts only on the base-station remaining-time estimate.

One-at-a-time sensitivity, every other parameter as calibrated (`results/sensitivity.png`):

| Parameter | Range | Handovers | Forced | Effective SE (b/s/Hz) |
| --- | --- | --- | --- | --- |
| Switching cost c_sw | 0 → 0.3 | 36.2 → 15.4 | 2.1 → 4.5 | 5.134 → 4.998 |
| Margin | 0 → 0.15 | 28.1 → 17.6 | 2.0 → 2.7 | 5.121 → 5.068 |
| Confirmation time | 0 → 5 s | 32.2 → 15.2 | 1.3 → 4.5 | 5.160 → 4.964 |
| Remaining-time weight w_r | 0 → 0.5 | 21.1 → 20.9 (min 19.1 at 0.3) | 2.7 → 2.4 (min 2.1 at 0.3) | 5.101 → 5.026 |
| Prediction weight w_p | 0 → 0.3 | 19.6 → 21.1 | 2.4 → 2.2 | 5.095 → 5.099 |
| Remaining-time cap T_cap | 20 → 240 s | 18.5 → 20.3 | 2.9 → 2.2 | 5.073 → 5.103 |

The usual tension appears in every knob: anything that makes the rule stickier (cost, margin, confirmation time) cuts handovers but raises forced handovers and lowers SE. The calibrated point sits in the middle of each range, not at an edge, so the selection did not run against a grid boundary.

## Limitations and future work

The results hold for a simplified model, so the size of every effect depends on its assumptions. The main simplifications, in order of likely impact:

- **Forced handovers cost the same as planned ones.** A real forced handover follows a radio link failure, with re-establishment taking hundreds of milliseconds to seconds. Modelling that cost is the most direct way to price the method's main benefit.
- **No interference.** Terrestrial SNR near a site reaches 50 dB or more. With co-channel interference, cell-edge SINR would be lower and the terrestrial handover problem harder.
- **No load or congestion.** The score has no resource term, so the study cannot show load-aware selection. A per-cell load model with an admission threshold would be the next term to add.
- **Handover signalling is not modelled.** There are no measurement-report delays, preparation, RACH, Doppler or propagation delay. Interruption times are assumed constants, not derived values.
- **Simplified satellite geometry and beams.** Circular orbits on a spherical Earth, no beam pattern and no beam-level handover. The speed scenarios also repeat pass geometry to cover long runs.
- **One user, one road, one carrier frequency per system.** Shadowing parameters are generic macro and LEO values, not calibrated against measurements.
- **Satellite remaining time uses the geometric visibility of the actual trajectory.** This is the ephemeris prediction a terminal could make. The user's own movement over the prediction window changes elevation by less than 0.1°.

It is not a 3GPP-compliant model. The baseline resembles the A3 event, the remaining-time idea resembles the time- and location-based triggers studied for NTN conditional handover, and some link-budget numbers are of the same order as TR 38.821 and TR 36.814 values. No procedure, timer or message flow is implemented as specified.

**Future work.** In order:

1. Charge forced handovers a radio-link-failure penalty, and re-run the comparison.
2. Add interference and a load term.
3. Replace the fixed costs with an expected-utility rule: switch when the predicted capacity gain over the remaining service time exceeds the interruption cost.
4. Try a learned policy only if this rule shows a limitation that a learned policy could address. The present results do not show one.

## Reproducing the results

The project needs only base MATLAB (R2021a or later, including MATLAB Online), with no toolboxes. Every number in this report comes from one run of `main` with the default configuration. The checks and results were also run in GNU Octave 8.4.

1. `cd` into the project folder in MATLAB.
2. Run `run_tests`. It should report 43 of 43 checks passed.
3. Run `main`, which takes a few minutes. It prints every table in this report and writes the figures plus `evaluation_summary.csv` to `results/`.
4. Optional: `addpath('src'); calibrate_intelligent(config(), 1:10, 'results/calibration.csv')` repeats the 1008-configuration grid, which takes 10–15 minutes.
