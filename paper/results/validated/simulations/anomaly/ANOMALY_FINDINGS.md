# Replicated anomaly check

All results below are computed from independent replications of the prespecified generators.
External and trial nuisance fits use ridge with main effects and sine/cosine of the first four predictors; discrepancy calibration varies. All fits use the same data and seeds within a setting. No generator or penalty grid is changed in response to performance.

The RMSE ratio is sqrt(mean ISE for Recipe A / mean paired ISE for RACER). Its MCSE uses paired replication summaries. These runs contain no bootstrap intervals.

- Scenario 1, n = 200, intercept calibration: 200/200 successful; integrated RMSE 0.24946 (MCSE 0.00844); ratio to RACER 0.8285 (MCSE 0.0210); mean paired ISE difference -0.02843 (MCSE 0.00409).
- Scenario 1, n = 200, lasso calibration: 200/200 successful; integrated RMSE 0.25020 (MCSE 0.00858); ratio to RACER 0.8310 (MCSE 0.0201); mean paired ISE difference -0.02806 (MCSE 0.00390).
- Scenario 1, n = 200, ridge calibration: 200/200 successful; integrated RMSE 0.25038 (MCSE 0.00846); ratio to RACER 0.8316 (MCSE 0.0197); mean paired ISE difference -0.02797 (MCSE 0.00387).
- Scenario 1, n = 500, intercept calibration: 200/200 successful; integrated RMSE 0.14940 (MCSE 0.00463); ratio to RACER 0.9414 (MCSE 0.0144); mean paired ISE difference -0.00287 (MCSE 0.00076).
- Scenario 1, n = 500, lasso calibration: 200/200 successful; integrated RMSE 0.14929 (MCSE 0.00467); ratio to RACER 0.9407 (MCSE 0.0138); mean paired ISE difference -0.00290 (MCSE 0.00072).
- Scenario 1, n = 500, ridge calibration: 200/200 successful; integrated RMSE 0.14956 (MCSE 0.00465); ratio to RACER 0.9424 (MCSE 0.0133); mean paired ISE difference -0.00282 (MCSE 0.00070).
- Scenario 6, n = 250, intercept calibration: 200/200 successful; integrated RMSE 0.30174 (MCSE 0.00834); ratio to RACER 0.8406 (MCSE 0.0339); mean paired ISE difference -0.03781 (MCSE 0.00916).
- Scenario 6, n = 250, lasso calibration: 200/200 successful; integrated RMSE 0.24748 (MCSE 0.00726); ratio to RACER 0.6894 (MCSE 0.0260); mean paired ISE difference -0.06760 (MCSE 0.00793).
- Scenario 6, n = 250, ridge calibration: 200/200 successful; integrated RMSE 0.28719 (MCSE 0.00797); ratio to RACER 0.8001 (MCSE 0.0311); mean paired ISE difference -0.04637 (MCSE 0.00865).

Ratios below one indicate lower error; ratios above one indicate higher error. Interpretation should account for the reported Monte Carlo uncertainty. These results do not establish interval coverage.

In this run, all nine paired comparisons have lower integrated RMSE with Recipe A. The gain is about 17% in Scenario 1 at n=200 and 6% at n=500; Scenario 6 gains range from 16% to 31%, with lasso calibration giving the lowest RMSE.

Borrowing nevertheless increases ISE in 28.5%–43.5% of individual replications across these settings. A worse single-replicate demo result is therefore compatible with an average gain; these runs do not assess interval coverage.
