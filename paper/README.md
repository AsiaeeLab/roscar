# Reproducing the tutorial

The package contains the four calibrated-prediction recipes and the public
reproduction scripts for *Borrow Predictions, Not Causal Effects*. The main
branch is a development version. Final simulation results, protected-data
results, and a versioned paper release have separate completion requirements.

## Run the public analyses

Install the package's Imports and Suggests from CRAN, including `pkgload` for
running this source checkout. Use R 4.1 or later. Run from the repository root:

```sh
Rscript paper/tests/run.R
Rscript paper/make.R --quick --workers=48
Rscript paper/make.R --steps=anomaly,summary --workers=48
Rscript paper/make.R --steps=teaching,simulations,star,summary --workers=48
```

Quick mode uses 10 replications and 20 bootstrap resamples. Review its failure
tables before starting full mode. The separate anomaly analysis uses 200
replications in Scenarios 1 and 6 and compares intercept, ridge, and lasso
calibration on paired data. Full mode uses 500 point-performance replications
per setting and 200 bootstrap resamples on the first 200 replications. If the
measured parallel runtime would exceed 48 hours, `--bootstrap-reps=100` reduces
the inference subset as allowed by the study specification. It does not reduce
the 500 point-performance replications or the 200 resamples per inference fit.

The default full command also runs the anomaly analysis before the main
simulation. Simulation settings, per-job seeds, actual method definitions,
source snapshots, package versions, and resampling counts are recorded in each
run directory. Completed jobs can be reused with an identical configuration and
source fingerprint. See `simulations/README.md` for the output schema.

### Current full run

The analysis launched on September 15, 2026 uses 80 workers, 500 point
replications, and B=200 on the first 100 replications in each of 87 settings.
The measured projection was 69.88 hours with 200 inference replications and
37.01 hours with 100. The runtime inputs and calculation are in
`results/validated/runtime/`. The latter design uses the study's allowed first
compute reduction. Its complete results remain pending.

The durable equivalent of this simulation stage is:

```sh
Rscript paper/simulations/long-run.R --workers=80 --bootstrap-reps=100 --projected-original-hours=69.8838967013889
```

The driver records its PID and state in `simulations/full/driver_status.dcf`,
resumes checkpoints on an identical restart, and writes figures and summaries
at completion. The 200-replication anomaly check is complete; its tables and
Monte Carlo errors are in `results/validated/simulations/anomaly/`.

STAR has its own source and data fingerprints and checkpoints. Full mode uses
30 source constructions at each of five trial fractions and 500 bootstrap
resamples, with intercept, ridge, and lasso calibration. See
`applications/star/README.md` for reconstruction, missing covariates, observed
profile support, and classroom dependence. The primary data are CC0; the
unlicensed comparison extract is downloaded only for verification and is not
redistributed.

Greenlight is run separately by the investigator using
`applications/gps/README.md`. Its protected inputs and all outputs remain
outside repositories. The public entrypoint never loads those inputs. A
verified local design/endpoint record is required because cross-sectional
analysis files alone cannot establish baseline timing or endpoint interpolation.

## Manuscript artifact map

The audit's revised scope governs the following entries: no synthetic
Greenlight mimic, a complete-case primary analysis plus response sensitivity,
six simulation scenarios, MR-OSCAR with an offset for Recipe C, and pooled
outcome-supervised PLS for Recipe D.

| Placeholder | Source and generated artifact |
|---|---|
| P001 | `recipes.R::run_recipe_examples()` and `borrow_cate()` |
| P002 | `teaching/run.R::run_teaching()`; `teaching/output/call.R` and `heldout_first_six.csv` |
| P003 | `teaching/output/cate_profiles.csv`, `pseudo_outcome_variances.csv`, and `paste_ready.txt`; 500 resamples completed |
| P004 | `recipes.R`, Recipe A; identity transport with both external arms |
| P005 | `recipes.R`, Recipe B; protected application call in `applications/gps/run.R` |
| P006 | `recipes.R`, Recipe C; `transport(method = "impute")` and final offset |
| P007 | `recipes.R`, Recipe D; `transport(method = "embed")` and external dimension validation |
| P008 | `simulations/harness.R::simulation_registry()`; each run's `method_registry.csv` |
| P009 | Scenarios 1–3 performance CSVs and `results/RESULTS_SUMMARY.md` |
| P010 | Scenario 4 performance and mapping validation CSVs |
| P011 | Scenario 5 performance and paired one-arm diagnostics |
| P012 | Each simulation run's `performance.csv` and `scenario1.csv`–`scenario6.csv` |
| P013 | `simulations/figures.R::write_simulation_figures()`; Figure 4 scenario/calibration plates |
| P014 | Same figure function; Scenario 5 Figure 5 plates |
| P015 | `applications/star/download_preprocess.R` and `construction.R`; reconstruction and cohort audits |
| P016 | `applications/star/run.R::star_run()` |
| P017 | STAR `profile_results.csv`, subgroup CSVs, diagnostic objects, and fit-status tables |
| P018 | `applications/star/figures.R::star_figures()`; `P018_STAR_effects.pdf` |
| P019 | `applications/star/figures.R::star_diagnostic_figures()`; `P019_STAR_diagnostics_q*.pdf` |
| P020 | `applications/gps/audit.R`; investigator-generated aggregate filter/design audit |
| P021 | `applications/gps/run.R`; no public mimic under the revised specification |
| P022 | Same script and `response_sensitivity.R`; separate primary and response-adjusted targets |
| P023 | GPS pooled/site diagnostics and 30 outcome-permutation negative controls |
| P024 | `results/combine_applications.R`; investigator-run aggregate-only combination |
| P025 | `applications/gps/figures.R`; protected effect figures written outside repositories |
| P026 | Same script; protected diagnostic figures written outside repositories |
| P027 | `results/arguments.R::write_argument_table()` generates `results/ARGUMENT_TABLE.md` from package Rd documentation |
| P028 | Source fork, primary-data URL below, and the eventual versioned release; protected-data access wording requires data-holder approval |

## Public sources and release status

- Package and code: <https://github.com/AsiaeeLab/roscar>.
- Primary STAR record:
  <https://dataverse.harvard.edu/dataset.xhtml?persistentId=hdl:1902.1/10766>.
- Preserved upstream history: <https://github.com/couthcommander/ROSCAR>.
- Frozen JMLR implementation: <https://github.com/AsiaeeLab/r-oscar>.

`results/RESULTS_SUMMARY.md` distinguishes completed numerical analyses from
pending runs. Quick outputs establish execution only. A `v0.1.0` tag and archival
identifier must be added after paper numbers are final; neither is asserted by
this development checkout. No protected-data access procedure is invented here.
