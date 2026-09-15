# Reproduction results and completion status

Generated: 2026-09-15 05:12:05 UTC

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

Not completed. No replicated efficiency finding is asserted.

## P009–P014: simulation operating characteristics

The simulation harness exists; the complete quick and full tables have not yet finished.

## P015–P019 and STAR block of P024: public application

Primary Dataverse reconstruction matches all 43 substantive columns of the comparison extract. The first-grade small/regular analysis yields 4,218 students with all three outcome scores. This is complete-outcome selection; some baseline covariates remain missing. Source scripts report the missingness handling and exact source-construction denominators.

Teacher IDs occur in one treatment arm only and are not effect modifiers. The quick construction shows extensive shared classrooms across trial and external sources (approximately 94–97% of trial students). Grouping trial resampling by classroom does not remove cross-source dependence when external fits are held fixed; conditional intervals therefore carry a substantive dependence limitation.

Quick-run estimates are stored separately under `paper/applications/star/results-quick/`. Full 30-repetition-per-fraction, 500-resample results should be used only after their completion and review. Rare covariate levels can make the declared prognostic-adjustment treatment interactions unidentifiable; the comparator status table records these unavailable fits.

## P020–P026: protected Greenlight application

Not run by the coding agent. The investigator-run scripts read GPS_CLEAN_DIR, require locally verified design/endpoint information, and export aggregate tables and figures to GPS_OUTPUT_DIR outside repositories. The cleaned files omit timing/interpolation metadata, so those checks require source records or an investigator attestation. No Greenlight outcome numbers are supplied here. No protected files or synthetic mimic are distributed.

## P001, P004–P008, P016, P021, P027–P028: software artifacts

The implemented API, example calls, simulation registry, application scripts, generated argument table, and source/data provenance map are listed in paper/README.md. The GitHub fork preserves upstream history. A release tag and archive identifier remain pending until final numerical results and release checks are complete.
