# Reproduction results and completion status

Generated: 2026-09-15 05:39:14 UTC

Only completed runs are summarized. Quick-mode tables check execution; 10 replications and 20 resamples do not supply the paper's final coverage or precision evidence.

## P002–P003: teaching example

| X1 | truth | recipe_A | trial_only | recipe_A_lower | recipe_A_upper | trial_only_lower | trial_only_upper | width_ratio |
|---|---|---|---|---|---|---|---|---|
| -1 | 0.0 | 0.19469 | 0.20735 | -0.21245 | 0.60318 | -0.20328 | 0.60793 | 1.00545 |
| 0 | 0.5 | 0.72351 | 0.75192 | 0.45424 | 1.01884 | 0.46735 | 1.04441 | 0.97841 |
| 1 | 1.0 | 1.25233 | 1.29650 | 0.83804 | 1.62170 | 0.82487 | 1.69737 | 0.89817 |

The prespecified seed is 20260914, with 200 trial and 2,000 external observations and 500 conditional trial bootstrap resamples. Width ratios below one indicate narrower intervals; ratios above one indicate wider intervals. This is one illustration, not an estimate of typical performance or coverage.

| baseline | heldout_pseudo_outcome_variance |
|---|---|
| None | 16.7719 |
| Trial-only | 4.5913 |
| Uncalibrated external | 5.8197 |
| Calibrated external | 4.5076 |

## Replicated anomaly check: Scenarios 1 and 6

Source: `paper/simulations/anomaly/728cb7135d35/ANOMALY_TABLE.csv`.

| scenario | n_r | calibration | method | attempted | successful | rmse | rmse_mcse | integrated_rmse_ratio | integrated_rmse_ratio_mcse | ise_difference | ise_difference_mcse | ise_increase_frequency |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 200 | intercept | A | 200 | 200 | 0.24946 | 0.0084417 | 0.82850 | 0.020968 | -0.0284293 | 0.00408799 | 0.295 |
| 1 | 200 | lasso | A | 200 | 200 | 0.25020 | 0.0085769 | 0.83096 | 0.020083 | -0.0280594 | 0.00390251 | 0.300 |
| 1 | 200 | ridge | A | 200 | 200 | 0.25038 | 0.0084550 | 0.83157 | 0.019704 | -0.0279681 | 0.00386771 | 0.285 |
| 1 | 500 | intercept | A | 200 | 200 | 0.14940 | 0.0046343 | 0.94136 | 0.014420 | -0.0028674 | 0.00075674 | 0.425 |
| 1 | 500 | lasso | A | 200 | 200 | 0.14929 | 0.0046745 | 0.94071 | 0.013758 | -0.0028980 | 0.00072217 | 0.435 |
| 1 | 500 | ridge | A | 200 | 200 | 0.14956 | 0.0046488 | 0.94237 | 0.013298 | -0.0028195 | 0.00070106 | 0.435 |
| 6 | 250 | intercept | A | 200 | 200 | 0.30174 | 0.0083449 | 0.84059 | 0.033919 | -0.0378057 | 0.00916468 | 0.405 |
| 6 | 250 | lasso | A | 200 | 200 | 0.24748 | 0.0072646 | 0.68944 | 0.025951 | -0.0676046 | 0.00792765 | 0.285 |
| 6 | 250 | ridge | A | 200 | 200 | 0.28719 | 0.0079688 | 0.80007 | 0.031137 | -0.0463717 | 0.00865035 | 0.395 |

The comparison uses paired datasets and trial-only estimates. The ratio is the square root of mean integrated squared error for borrowing divided by that for RACER; uncertainty is Monte Carlo uncertainty across independent replications. No generators are retuned in response to these findings.


In this run, all nine paired comparisons have lower integrated RMSE with Recipe A. The gain is about 17% in Scenario 1 at n=200 and 6% at n=500; Scenario 6 gains range from 16% to 31%, with lasso calibration giving the lowest RMSE.

Borrowing nevertheless increases ISE in 28.5%–43.5% of individual replications across these settings. A worse single-replicate demo result is therefore compatible with an average gain; these runs do not assess interval coverage.

## P009–P014: simulation operating characteristics

Quick-mode execution check only: `paper/simulations/quick/d47f33665e35/performance.csv`.

| scenario | n_r | variant | rho | gamma | kappa | treated_nuisance | calibration | method | target | attempted | successful | interval_attempted | interval_successful | rmse | rmse_mcse | coverage | coverage_mcse | width_ratio | width_ratio_mcse |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.214288 | 0.0243274 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.097972 | 0.0137656 | 1.0 | 0.000000 | 0.86455 | 0.04637360 |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.285781 | 0.0457438 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122929 | 0.0245722 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.218114 | 0.0228536 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.102248 | 0.0154791 | 1.0 | 0.000000 | 0.86787 | 0.04527868 |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.285781 | 0.0457438 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122929 | 0.0245722 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.214042 | 0.0210580 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.099676 | 0.0136639 | 1.0 | 0.000000 | 0.85205 | 0.03825173 |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.285781 | 0.0457438 | NA | NA | NA | NA |
| 1 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122929 | 0.0245722 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.148166 | 0.0110518 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.082659 | 0.0165504 | 0.9 | 0.094868 | 0.96670 | 0.02690301 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.153696 | 0.0076545 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078694 | 0.0162512 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.146927 | 0.0099609 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.084904 | 0.0164425 | 0.9 | 0.094868 | 0.94901 | 0.02233417 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.153696 | 0.0076545 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078694 | 0.0162512 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.147771 | 0.0104416 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.084048 | 0.0165333 | 0.9 | 0.094868 | 0.94943 | 0.02415301 |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.153696 | 0.0076545 | NA | NA | NA | NA |
| 1 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078694 | 0.0162512 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.234959 | 0.0285206 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.176927 | 0.0341162 | 0.8 | 0.126491 | 0.86252 | 0.04701743 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.282392 | 0.0255524 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.174837 | 0.0205221 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.224333 | 0.0267354 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.171554 | 0.0311084 | 0.8 | 0.126491 | 0.89146 | 0.03109977 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.282392 | 0.0255524 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.174837 | 0.0205221 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.229651 | 0.0294009 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.179396 | 0.0338704 | 0.8 | 0.126491 | 0.86586 | 0.03831512 |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.282392 | 0.0255524 | NA | NA | NA | NA |
| 2 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.174837 | 0.0205221 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.171031 | 0.0185070 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.084440 | 0.0219027 | 0.9 | 0.094868 | 0.92631 | 0.03332671 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.165683 | 0.0142895 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078287 | 0.0193564 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.169630 | 0.0166455 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.081617 | 0.0216865 | 0.9 | 0.094868 | 0.91802 | 0.02870707 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.165683 | 0.0142895 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078287 | 0.0193564 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.168887 | 0.0175972 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.080659 | 0.0220132 | 0.9 | 0.094868 | 0.91524 | 0.02865938 |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.165683 | 0.0142895 | NA | NA | NA | NA |
| 2 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.078287 | 0.0193564 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.630909 | 0.0824208 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.440268 | 0.0722639 | 0.6 | 0.154919 | 1.67871 | 0.10475571 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.286616 | 0.0393633 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172398 | 0.0346484 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.262784 | 0.0235655 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.161553 | 0.0285737 | 0.9 | 0.094868 | 0.97402 | 0.04458930 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.286616 | 0.0393633 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172398 | 0.0346484 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.286587 | 0.0393797 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.172378 | 0.0346559 | 0.9 | 0.094868 | 0.99960 | 0.00081982 |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.286616 | 0.0393633 | NA | NA | NA | NA |
| 3 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172398 | 0.0346484 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 1.278082 | 0.2170267 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.607361 | 0.1030677 | 0.9 | 0.094868 | 3.49308 | 0.27367864 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.415919 | 0.0562261 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.169720 | 0.0433666 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.383507 | 0.0569257 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.161723 | 0.0451064 | 0.8 | 0.126491 | 1.06029 | 0.03970843 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.415919 | 0.0562261 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.169720 | 0.0433666 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.420256 | 0.0536124 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.160689 | 0.0391225 | 0.8 | 0.126491 | 1.20464 | 0.03870499 |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.415919 | 0.0562261 | NA | NA | NA | NA |
| 3 | 200 | reversed | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.169720 | 0.0433666 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.429656 | 0.0679743 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.180532 | 0.0349535 | 0.8 | 0.126491 | 2.12065 | 0.18638145 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.181481 | 0.0211818 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.116610 | 0.0207138 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.170998 | 0.0213513 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.110956 | 0.0218850 | 0.7 | 0.144914 | 0.93594 | 0.02522100 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.181481 | 0.0211818 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.116610 | 0.0207138 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.181511 | 0.0211787 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.116582 | 0.0207006 | 0.8 | 0.126491 | 0.99999 | 0.00056354 |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.181481 | 0.0211818 | NA | NA | NA | NA |
| 3 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.116610 | 0.0207138 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.662119 | 0.0875547 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.401448 | 0.1015240 | 0.8 | 0.126491 | 3.19974 | 0.25076033 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.143269 | 0.0146375 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.084077 | 0.0190487 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.135537 | 0.0178416 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.078659 | 0.0163252 | 0.9 | 0.094868 | 0.96579 | 0.01080812 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.143269 | 0.0146375 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.084077 | 0.0190487 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.141421 | 0.0158660 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.085590 | 0.0183363 | 0.8 | 0.126491 | 1.01416 | 0.02939873 |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.143269 | 0.0146375 | NA | NA | NA | NA |
| 3 | 500 | reversed | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.084077 | 0.0190487 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | C | integrated | 10 | 10 | 0 | 0 | 0.528617 | 0.0517385 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | C | profile_zero | 10 | 10 | 10 | 10 | 0.266794 | 0.0520964 | 0.8 | 0.126491 | 0.96943 | 0.04512907 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | D | integrated | 10 | 10 | 0 | 0 | 0.490761 | 0.0534060 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | D | profile_zero | 10 | 10 | 10 | 10 | 0.259775 | 0.0455814 | 0.8 | 0.126491 | 0.96215 | 0.04139796 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.490092 | 0.0561654 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.227063 | 0.0427339 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | C | integrated | 10 | 10 | 0 | 0 | 0.594211 | 0.0528845 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | C | profile_zero | 10 | 10 | 10 | 10 | 0.334699 | 0.0649326 | 0.8 | 0.126491 | 1.23777 | 0.08492792 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | D | integrated | 10 | 10 | 0 | 0 | 0.488518 | 0.0492603 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | D | profile_zero | 10 | 10 | 10 | 10 | 0.246241 | 0.0442438 | 1.0 | 0.000000 | 0.95999 | 0.02542433 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.490092 | 0.0561654 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.227063 | 0.0427339 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | C | integrated | 10 | 10 | 0 | 0 | 0.629417 | 0.0472829 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | C | profile_zero | 10 | 10 | 10 | 10 | 0.359189 | 0.0843091 | 0.9 | 0.094868 | 1.23574 | 0.07860767 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | D | integrated | 10 | 10 | 0 | 0 | 0.497421 | 0.0534503 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | D | profile_zero | 10 | 10 | 10 | 10 | 0.242816 | 0.0438521 | 0.9 | 0.094868 | 0.96806 | 0.02552753 |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.490092 | 0.0561654 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.227063 | 0.0427339 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | C | integrated | 10 | 10 | 0 | 0 | 0.401206 | 0.0330350 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | C | profile_zero | 10 | 10 | 10 | 10 | 0.252373 | 0.0500678 | 0.8 | 0.126491 | 0.89037 | 0.01684602 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | D | integrated | 10 | 10 | 0 | 0 | 0.368358 | 0.0377278 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | D | profile_zero | 10 | 10 | 10 | 10 | 0.183518 | 0.0277753 | 1.0 | 0.000000 | 0.88840 | 0.01642360 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.324111 | 0.0413639 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.200364 | 0.0382042 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | C | integrated | 10 | 10 | 0 | 0 | 0.378647 | 0.0247959 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | C | profile_zero | 10 | 10 | 10 | 10 | 0.249506 | 0.0465310 | 0.8 | 0.126491 | 1.03399 | 0.03593564 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | D | integrated | 10 | 10 | 0 | 0 | 0.325910 | 0.0324460 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | D | profile_zero | 10 | 10 | 10 | 10 | 0.179722 | 0.0290433 | 0.8 | 0.126491 | 0.88667 | 0.02464224 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.324111 | 0.0413639 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.200364 | 0.0382042 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | C | integrated | 10 | 10 | 0 | 0 | 0.439670 | 0.0289239 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | C | profile_zero | 10 | 10 | 10 | 10 | 0.252506 | 0.0405973 | 0.8 | 0.126491 | 1.07737 | 0.03826803 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | D | integrated | 10 | 10 | 0 | 0 | 0.348011 | 0.0343948 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | D | profile_zero | 10 | 10 | 10 | 10 | 0.187407 | 0.0292870 | 0.9 | 0.094868 | 0.91447 | 0.01941146 |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.324111 | 0.0413639 | NA | NA | NA | NA |
| 4 | 200 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.200364 | 0.0382042 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | C | integrated | 10 | 10 | 0 | 0 | 0.350953 | 0.0408094 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | C | profile_zero | 10 | 10 | 10 | 10 | 0.169226 | 0.0271394 | 0.8 | 0.126491 | 0.98279 | 0.03491552 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | D | integrated | 10 | 10 | 0 | 0 | 0.305251 | 0.0453128 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | D | profile_zero | 10 | 10 | 10 | 10 | 0.183824 | 0.0321815 | 0.8 | 0.126491 | 0.98267 | 0.03578358 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.271367 | 0.0302808 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172692 | 0.0266816 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | C | integrated | 10 | 10 | 0 | 0 | 0.376248 | 0.0269810 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | C | profile_zero | 10 | 10 | 10 | 10 | 0.180500 | 0.0227259 | 0.9 | 0.094868 | 1.18457 | 0.05520436 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | D | integrated | 10 | 10 | 0 | 0 | 0.279011 | 0.0341812 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | D | profile_zero | 10 | 10 | 10 | 10 | 0.171101 | 0.0275041 | 0.8 | 0.126491 | 0.95877 | 0.01564762 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.271367 | 0.0302808 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172692 | 0.0266816 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | C | integrated | 10 | 10 | 0 | 0 | 0.434030 | 0.0251152 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | C | profile_zero | 10 | 10 | 10 | 10 | 0.215113 | 0.0366710 | 0.8 | 0.126491 | 1.26601 | 0.07287180 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | D | integrated | 10 | 10 | 0 | 0 | 0.274295 | 0.0338583 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | D | profile_zero | 10 | 10 | 10 | 10 | 0.173006 | 0.0295972 | 0.8 | 0.126491 | 0.96441 | 0.01519707 |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.271367 | 0.0302808 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.172692 | 0.0266816 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | C | integrated | 10 | 10 | 0 | 0 | 0.272956 | 0.0246224 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | C | profile_zero | 10 | 10 | 10 | 10 | 0.149967 | 0.0284764 | 0.8 | 0.126491 | 0.99861 | 0.04017475 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | D | integrated | 10 | 10 | 0 | 0 | 0.230859 | 0.0294762 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | D | profile_zero | 10 | 10 | 10 | 10 | 0.097838 | 0.0200813 | 1.0 | 0.000000 | 0.99979 | 0.03689787 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.206826 | 0.0324508 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.079757 | 0.0112603 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | C | integrated | 10 | 10 | 0 | 0 | 0.304171 | 0.0183082 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | C | profile_zero | 10 | 10 | 10 | 10 | 0.176462 | 0.0331328 | 0.8 | 0.126491 | 1.28399 | 0.08046365 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | D | integrated | 10 | 10 | 0 | 0 | 0.208045 | 0.0306900 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | D | profile_zero | 10 | 10 | 10 | 10 | 0.084693 | 0.0121777 | 1.0 | 0.000000 | 0.95164 | 0.02334398 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.206826 | 0.0324508 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.079757 | 0.0112603 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | C | integrated | 10 | 10 | 0 | 0 | 0.352622 | 0.0213284 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | C | profile_zero | 10 | 10 | 10 | 10 | 0.183936 | 0.0366575 | 0.9 | 0.094868 | 1.48833 | 0.08302446 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | D | integrated | 10 | 10 | 0 | 0 | 0.208322 | 0.0298262 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | D | profile_zero | 10 | 10 | 10 | 10 | 0.083999 | 0.0124540 | 1.0 | 0.000000 | 0.96791 | 0.02639279 |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.206826 | 0.0324508 | NA | NA | NA | NA |
| 4 | 500 | nonprognostic | 0.8 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.079757 | 0.0112603 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.413582 | 0.0540158 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.200350 | 0.0383751 | 0.8 | 0.126491 | 1.33647 | 0.10610312 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.274981 | 0.0344095 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.127209 | 0.0248695 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.276425 | 0.0352128 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.109351 | 0.0194515 | 1.0 | 0.000000 | 0.99181 | 0.03516731 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.274981 | 0.0344095 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.127209 | 0.0248695 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.275071 | 0.0344035 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.127177 | 0.0248521 | 0.9 | 0.094868 | 1.00092 | 0.00061994 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.274981 | 0.0344095 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.127209 | 0.0248695 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.400765 | 0.0383662 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.201236 | 0.0368794 | 1.0 | 0.000000 | 1.26185 | 0.07903589 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.273914 | 0.0170869 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.148988 | 0.0206727 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.278269 | 0.0225261 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.162246 | 0.0266196 | 1.0 | 0.000000 | 0.98630 | 0.01804208 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.273914 | 0.0170869 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.148988 | 0.0206727 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.273918 | 0.0170849 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.148964 | 0.0206686 | 1.0 | 0.000000 | 1.00012 | 0.00014784 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.273914 | 0.0170869 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.148988 | 0.0206727 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.471568 | 0.0416863 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.225846 | 0.0297051 | 0.9 | 0.094868 | 1.32661 | 0.05058219 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.281641 | 0.0239428 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122818 | 0.0286042 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.275018 | 0.0263551 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.129558 | 0.0296296 | 1.0 | 0.000000 | 1.00048 | 0.02850855 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.281641 | 0.0239428 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122818 | 0.0286042 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.281755 | 0.0235908 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.122557 | 0.0284486 | 0.9 | 0.094868 | 1.00136 | 0.00119705 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.281641 | 0.0239428 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.122818 | 0.0286042 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.463837 | 0.0389919 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.167528 | 0.0454145 | 0.9 | 0.094868 | 1.25324 | 0.05322959 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.289012 | 0.0211796 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.120511 | 0.0214179 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.271030 | 0.0171667 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.120925 | 0.0214174 | 1.0 | 0.000000 | 0.99323 | 0.02753084 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.289012 | 0.0211796 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.120511 | 0.0214179 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.288838 | 0.0211612 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.120347 | 0.0214283 | 1.0 | 0.000000 | 0.99974 | 0.00044291 |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.289012 | 0.0211796 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.120511 | 0.0214179 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.286354 | 0.0282569 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.181830 | 0.0335526 | 0.9 | 0.094868 | 0.91145 | 0.03998055 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.298287 | 0.0288940 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.180789 | 0.0313445 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.288407 | 0.0287083 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.181564 | 0.0334509 | 0.9 | 0.094868 | 0.91387 | 0.04042882 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.298287 | 0.0288940 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.180789 | 0.0313445 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.288299 | 0.0285420 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.181290 | 0.0343548 | 0.9 | 0.094868 | 0.90536 | 0.03918249 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.298287 | 0.0288940 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.180789 | 0.0313445 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.301198 | 0.0231014 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.186484 | 0.0300051 | 0.8 | 0.126491 | 0.91807 | 0.03302788 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.323161 | 0.0254503 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.192100 | 0.0362609 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.297708 | 0.0215311 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.182929 | 0.0295590 | 0.8 | 0.126491 | 0.92177 | 0.03288255 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.323161 | 0.0254503 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.192100 | 0.0362609 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.299294 | 0.0214670 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.185648 | 0.0299889 | 0.8 | 0.126491 | 0.91886 | 0.03277512 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.323161 | 0.0254503 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.192100 | 0.0362609 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.268455 | 0.0343258 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.183019 | 0.0473924 | 0.8 | 0.126491 | 0.87952 | 0.02245711 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.286794 | 0.0323751 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.187903 | 0.0422556 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.266999 | 0.0340872 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.181338 | 0.0479588 | 0.8 | 0.126491 | 0.89549 | 0.02607657 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.286794 | 0.0323751 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.187903 | 0.0422556 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.265500 | 0.0344833 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.181128 | 0.0477505 | 0.8 | 0.126491 | 0.89224 | 0.02069189 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.286794 | 0.0323751 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.187903 | 0.0422556 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.294196 | 0.0265966 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.137428 | 0.0227339 | 1.0 | 0.000000 | 0.87568 | 0.03007430 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.329571 | 0.0388098 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.155771 | 0.0284462 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.291930 | 0.0274075 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.132360 | 0.0222526 | 1.0 | 0.000000 | 0.88981 | 0.02218031 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.329571 | 0.0388098 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.155771 | 0.0284462 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.291776 | 0.0257612 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.135373 | 0.0222370 | 1.0 | 0.000000 | 0.88470 | 0.02568770 |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.329571 | 0.0388098 | NA | NA | NA | NA |
| 5 | 200 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.155771 | 0.0284462 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.242493 | 0.0241716 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.173834 | 0.0332066 | 0.6 | 0.154919 | 1.21989 | 0.06070576 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.137045 | 0.0114013 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.075409 | 0.0109508 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.139687 | 0.0136803 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.076198 | 0.0122702 | 1.0 | 0.000000 | 0.95618 | 0.01780860 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.137045 | 0.0114013 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.075409 | 0.0109508 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.136992 | 0.0114144 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.075412 | 0.0109485 | 1.0 | 0.000000 | 0.99958 | 0.00034274 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.137045 | 0.0114013 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.075409 | 0.0109508 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.268502 | 0.0338544 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.125468 | 0.0259327 | 0.8 | 0.126491 | 1.30780 | 0.07964081 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.176536 | 0.0314772 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074337 | 0.0112353 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.175485 | 0.0314006 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.076451 | 0.0124419 | 1.0 | 0.000000 | 0.98672 | 0.02621422 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.176536 | 0.0314772 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074337 | 0.0112353 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.176614 | 0.0313892 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.074353 | 0.0112552 | 1.0 | 0.000000 | 0.99977 | 0.00030046 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.176536 | 0.0314772 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 0 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074337 | 0.0112353 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.285139 | 0.0495944 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.115438 | 0.0142525 | 0.9 | 0.094868 | 1.39157 | 0.08260534 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.181503 | 0.0130042 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.077979 | 0.0150814 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.180874 | 0.0158220 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.075919 | 0.0138852 | 1.0 | 0.000000 | 0.98117 | 0.01742495 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.181503 | 0.0130042 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.077979 | 0.0150814 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.181403 | 0.0130090 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.078016 | 0.0150890 | 0.9 | 0.094868 | 1.00018 | 0.00072556 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.181503 | 0.0130042 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.077979 | 0.0150814 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.196374 | 0.0199229 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.102948 | 0.0193019 | 1.0 | 0.000000 | 1.31225 | 0.08449643 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.185622 | 0.0163442 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.124158 | 0.0233559 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.181227 | 0.0152524 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.118195 | 0.0215119 | 0.8 | 0.126491 | 0.97638 | 0.02046483 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.185622 | 0.0163442 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.124158 | 0.0233559 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.185396 | 0.0162422 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.123831 | 0.0231789 | 0.8 | 0.126491 | 0.99977 | 0.00125256 |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.185622 | 0.0163442 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 0 | 1 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.124158 | 0.0233559 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.136842 | 0.0140183 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.049131 | 0.0069644 | 1.0 | 0.000000 | 0.93597 | 0.02633502 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.147147 | 0.0143346 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.058229 | 0.0093539 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.135521 | 0.0136727 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.049315 | 0.0072291 | 1.0 | 0.000000 | 0.94737 | 0.01835975 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.147147 | 0.0143346 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.058229 | 0.0093539 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.137998 | 0.0144718 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.049273 | 0.0074063 | 1.0 | 0.000000 | 0.94471 | 0.01945353 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.147147 | 0.0143346 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.058229 | 0.0093539 | 1.0 | 0.000000 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.197675 | 0.0237321 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.071333 | 0.0118319 | 0.9 | 0.094868 | 0.93781 | 0.02530417 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.197603 | 0.0203007 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074731 | 0.0132541 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.197438 | 0.0232701 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.073577 | 0.0126201 | 0.9 | 0.094868 | 0.94141 | 0.02566037 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.197603 | 0.0203007 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074731 | 0.0132541 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.195942 | 0.0230150 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.073305 | 0.0120829 | 0.9 | 0.094868 | 0.94663 | 0.02257686 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.197603 | 0.0203007 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 0 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.074731 | 0.0132541 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.171907 | 0.0195092 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.103427 | 0.0197912 | 0.9 | 0.094868 | 0.96124 | 0.02481265 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.190518 | 0.0179238 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.107017 | 0.0168014 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.174473 | 0.0202752 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.106733 | 0.0213188 | 0.9 | 0.094868 | 0.95421 | 0.02540962 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.190518 | 0.0179238 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.107017 | 0.0168014 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.176452 | 0.0201847 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.107087 | 0.0212204 | 0.9 | 0.094868 | 0.95443 | 0.02503593 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.190518 | 0.0179238 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | linear | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.107017 | 0.0168014 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | B | integrated | 10 | 10 | 0 | 0 | 0.159894 | 0.0204946 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | B | profile_zero | 10 | 10 | 10 | 10 | 0.092375 | 0.0164954 | 0.7 | 0.144914 | 0.91636 | 0.02450600 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.172137 | 0.0238035 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.092414 | 0.0162747 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | B | integrated | 10 | 10 | 0 | 0 | 0.159477 | 0.0205779 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | B | profile_zero | 10 | 10 | 10 | 10 | 0.091555 | 0.0158378 | 0.8 | 0.126491 | 0.92372 | 0.02578578 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.172137 | 0.0238035 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.092414 | 0.0162747 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | B | integrated | 10 | 10 | 0 | 0 | 0.160047 | 0.0203705 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | B | profile_zero | 10 | 10 | 10 | 10 | 0.091783 | 0.0162188 | 0.8 | 0.126491 | 0.92079 | 0.02534861 |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.172137 | 0.0238035 | NA | NA | NA | NA |
| 5 | 500 | nonprognostic | 0.0 | 1 | 1 | sine | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.092414 | 0.0162747 | 0.9 | 0.094868 | 1.00000 | 0.00000000 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | integrated | 10 | 10 | 0 | 0 | 0.279904 | 0.0465891 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | A | profile_zero | 10 | 10 | 10 | 10 | 0.100779 | 0.0184232 | 0.8 | 0.126491 | 0.62740 | 0.03972997 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | integrated | 10 | 10 | 0 | 0 | 0.356402 | 0.0423893 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | intercept | racer | profile_zero | 10 | 10 | 10 | 10 | 0.267622 | 0.0435168 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | integrated | 10 | 10 | 0 | 0 | 0.217194 | 0.0386682 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | A | profile_zero | 10 | 10 | 10 | 10 | 0.108505 | 0.0187452 | 0.9 | 0.094868 | 0.56466 | 0.04447720 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | integrated | 10 | 10 | 0 | 0 | 0.356402 | 0.0423893 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | lasso | racer | profile_zero | 10 | 10 | 10 | 10 | 0.267622 | 0.0435168 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | integrated | 10 | 10 | 0 | 0 | 0.248703 | 0.0417520 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | A | profile_zero | 10 | 10 | 10 | 10 | 0.094162 | 0.0191630 | 0.9 | 0.094868 | 0.61175 | 0.03794707 |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | integrated | 10 | 10 | 0 | 0 | 0.356402 | 0.0423893 | NA | NA | NA | NA |
| 6 | 250 | nonprognostic | 0.0 | 1 | 0 | dictionary | ridge | racer | profile_zero | 10 | 10 | 10 | 10 | 0.267622 | 0.0435168 | 0.8 | 0.126491 | 1.00000 | 0.00000000 |

Each scenario CSV retains the complete comparator list, attempted/successful counts, target definitions, biases, Monte Carlo errors, and unavailable methods. Coverage is conditional on successful intervals; interval failures are also counted. Interpret benefit and harm together with these denominators.

Full 500-replication point performance and the final coverage subset are pending. The quick table cannot fill the final manuscript result placeholders.

## P015–P019 and STAR block of P024: public application

Primary Dataverse reconstruction matches all 43 substantive columns of the comparison extract. The first-grade small/regular analysis yields 4,218 students with all three outcome scores. This is complete-outcome selection; some baseline covariates remain missing. Source scripts report the missingness handling and exact source-construction denominators.

Teacher IDs occur in one treatment arm only and are not effect modifiers. The quick construction shows extensive shared classrooms across trial and external sources (approximately 94–97% of trial students). Grouping trial resampling by classroom does not remove cross-source dependence when external fits are held fixed; conditional intervals therefore carry a substantive dependence limitation.

Completed public aggregate snapshots are in `paper/results/validated/`. Quick-run estimates are stored separately under `paper/applications/star/results-quick/`. Full 30-repetition-per-fraction, 500-resample results should be used only after their completion and review. Rare covariate levels can make the declared prognostic-adjustment treatment interactions unidentifiable; the comparator status table records these unavailable fits.

### Quick STAR software check

Recorded 5 completed source-construction jobs with 1 repetition(s) per q and B=20 requested bootstrap resamples.

These outputs check the software. The 30-repetition, B=500 analysis has not been completed in this run.

Recipe fits succeeded in 15 of 15 recorded attempts. The available bootstrap audits report 300 successful refits out of 300 attempted refits.

#### Conditional interval widths

Each repetition contributes its median width ratio across supported profiles. The table gives the median and empirical 10th/90th percentiles across repetitions; these percentiles are not confidence intervals.

| q | Calibration | Repetitions | Median width ratio | Empirical 10th–90th percentiles |
|---:|---|---:|---:|---:|
| 0.1 | intercept | 1 | 0.947 | 0.947–0.947 |
| 0.1 | lasso | 1 | 1.006 | 1.006–1.006 |
| 0.1 | ridge | 1 | 0.974 | 0.974–0.974 |
| 0.2 | intercept | 1 | 0.988 | 0.988–0.988 |
| 0.2 | lasso | 1 | 0.995 | 0.995–0.995 |
| 0.2 | ridge | 1 | 0.986 | 0.986–0.986 |
| 0.3 | intercept | 1 | 1.062 | 1.062–1.062 |
| 0.3 | lasso | 1 | 1.031 | 1.031–1.031 |
| 0.3 | ridge | 1 | 1.000 | 1.000–1.000 |
| 0.4 | intercept | 1 | 1.125 | 1.125–1.125 |
| 0.4 | lasso | 1 | 0.979 | 0.979–0.979 |
| 0.4 | ridge | 1 | 0.977 | 0.977–0.977 |
| 0.5 | intercept | 1 | 1.023 | 1.023–1.023 |
| 0.5 | lasso | 1 | 0.976 | 0.976–0.976 |
| 0.5 | ridge | 1 | 0.991 | 0.991–0.991 |

Ratios below one indicate narrower conditional intervals; ratios above one indicate wider intervals. Reference disagreement uses an estimated cross-fitted CATE from the full rural/inner-city cohort.

#### Source construction and limitations

Across these constructions, 94.0%–97.2% of trial students share a classroom proxy with external students. Resampling trial classrooms with external data fixed leaves this cross-source dependence unresolved.

The implementation uses school-specific empirical assignment fractions because exact allocation probabilities are absent from the public extract. First-grade free-lunch groups are descriptive because pretreatment timing is unresolved. Teacher identity is used for dependence handling.

There are 5 unavailable or failed comparison-method fits. Their reasons are retained in [unavailable comparisons](validated/star/quick/summary/unavailable_comparisons.csv); rank-deficient declared treatment interactions remain unavailable.

#### Aggregate tables

- [P015 source counts](validated/star/quick/summary/P015_source_counts.csv), [selection denominators](validated/star/quick/summary/P015_selection_denominators.csv), and [classroom overlap](validated/star/quick/summary/P015_classroom_overlap.csv).
- [P017 repetition-1 profile effects](validated/star/quick/summary/P017_rep1_profiles.csv), [across-repetition summaries](validated/star/quick/summary/P017_across_repetitions.csv), and [borrowing diagnostics](validated/star/quick/summary/P017_borrowing_diagnostics.csv).
- [P024 repetition-1 subgroup effects](validated/star/quick/summary/P024_rep1_subgroups.csv) and [subgroup summaries](validated/star/quick/summary/P024_subgroup_across_repetitions.csv).
- [Fit/bootstrap counts](validated/star/quick/summary/fit_and_bootstrap_counts.csv) and [comparator counts](validated/star/quick/summary/comparator_fit_counts.csv).

## P020–P026: protected Greenlight application

Not run. The investigator-run scripts read GPS_CLEAN_DIR, require locally verified design/endpoint information, and export aggregate tables and figures to GPS_OUTPUT_DIR outside repositories. The cleaned files omit timing/interpolation metadata, so those checks require source records or an investigator attestation. No Greenlight outcome numbers are supplied here. No protected files or synthetic mimic are distributed.

## P001, P004–P008, P016, P021, P027–P028: software artifacts

The implemented API, example calls, simulation registry, application scripts, generated argument table, and source/data provenance map are listed in paper/README.md. The GitHub fork preserves upstream history. A release tag and archive identifier remain pending until final numerical results and release checks are complete.
