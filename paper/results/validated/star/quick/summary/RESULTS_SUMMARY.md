# Quick STAR software check

Recorded 5 completed source-construction jobs with 1 repetition(s) per q and B=20 requested bootstrap resamples.

These outputs check the software. The 30-repetition, B=500 analysis has not been completed in this run.

Recipe fits succeeded in 15 of 15 recorded attempts. The available bootstrap audits report 300 successful refits out of 300 attempted refits.

## Conditional interval widths

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

## Source construction and limitations

Across these constructions, 94.0%–97.2% of trial students share a classroom proxy with external students. Resampling trial classrooms with external data fixed leaves this cross-source dependence unresolved.

The implementation uses school-specific empirical assignment fractions because exact allocation probabilities are absent from the public extract. First-grade free-lunch groups are descriptive because pretreatment timing is unresolved. Teacher identity is used for dependence handling.

There are 5 unavailable or failed comparison-method fits. Their reasons are retained in [unavailable comparisons](unavailable_comparisons.csv); rank-deficient declared treatment interactions remain unavailable.

## Aggregate tables

- [P015 source counts](P015_source_counts.csv), [selection denominators](P015_selection_denominators.csv), and [classroom overlap](P015_classroom_overlap.csv).
- [P017 repetition-1 profile effects](P017_rep1_profiles.csv), [across-repetition summaries](P017_across_repetitions.csv), and [borrowing diagnostics](P017_borrowing_diagnostics.csv).
- [P024 repetition-1 subgroup effects](P024_rep1_subgroups.csv) and [subgroup summaries](P024_subgroup_across_repetitions.csv).
- [Fit/bootstrap counts](fit_and_bootstrap_counts.csv) and [comparator counts](comparator_fit_counts.csv).
