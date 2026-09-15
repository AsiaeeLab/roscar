# Greenlight Plus: protected, author-run analysis

Only code belongs in this directory. There is no public dataset, no generated
mimic, and no committed analysis cache. These scripts have **not** been run on
protected data by the coding agent. The source implementations were inspected
without reading protected RDS files.

## Run locally

Set `GPS_CLEAN_DIR` to the directory holding
`cate_rct_cross_sectional_data.rds` and `cate_ehr_cross_sectional_data.rds`.
Set `GPS_OUTPUT_DIR` to an absolute directory outside all Git repositories.
From the package root, run:

```sh
Rscript paper/applications/gps/run.R --audit-only
```

Complete a copy of `local_config_example.R` outside the repository, save its
`config` object as an RDS file, and set `GPS_DESIGN_RDS` to it. Then run:

```sh
Rscript paper/applications/gps/run.R --quick
Rscript paper/applications/gps/run.R
```

The primary analysis is the pooled, three-center complete-case comparison
expected to contain 330 trial children and 8,867 EHR controls. A different count
stops estimation for reconciliation. One response-weighted sensitivity uses the
baseline-eligible trial population. There is no second co-primary analysis.

## Audits that the cleaned inputs cannot establish

The read-only upstream `di-gps/experiments/01-RCT_Data_Exploration.Rmd` derives
chronological age as `days / 30.44`, uses the closed 23–25-month window, takes a
single visit directly, linearly interpolates the nearest bracketing visits when
available, and otherwise takes the closest visit in the window. It does not
extrapolate. This is a source-code description; actual input construction still
requires local verification. The cross-sectional builder selects earliest trial
WFLz after sorting by time relative to randomization but drops that time column.
It also drops the visits used for the endpoint. EHR upstream filters and linkage
cannot be reconstructed from the final cross-sectional extract alone.

`audit.R` reports counts at every available filter by source/site/arm, duplicate
IDs within source, and explicitly unavailable timing, linkage, upstream filter,
and allocation audits. Equal or unequal source-local IDs do not establish source
overlap. Before estimation, the local configuration must document known treatment
probabilities, original design strata, verified baseline timing, verified endpoint
construction, and a linkage audit. The program never guesses an exclusion rule
to reconcile 860 with 900 randomized children.

## Estimation and outputs

Recipe B uses external controls, five trial folds, lasso external and treated-arm
models, and intercept/ridge/lasso control calibration. The final basis has shared
baseline main effects, site indicators, and a three-knot restricted cubic spline
of baseline WFLz. Common observed profiles nearest the within-site 10th/50th/90th
percentiles are supported by local arm counts; insufficiently supported estimates
are unavailable. No profile's underlying covariates or ID is exported.

`run.R` exports aggregate P020 filter/audit tables; P022/P024 primary profiles,
subgroup effects and paired width ratios; P023 pooled and per-site borrowing
results and 30 fixed-seed external-outcome permutations; and P025 prognostic
adjustment comparisons. Diagnostics, fitted objects, individual predictions,
individual bootstrap draws and membership files stay in memory. Full-pipeline
intervals condition on the external cohort. Subgroup effects standardize over the
observed covariate distribution within each named target.

`response_sensitivity.R` fits a cross-fitted ridge-logistic response model from
baseline covariates and treatment. It inverse-weights observed-outcome residuals,
sets missing-outcome pseudo-outcomes to zero, and fits the effect regression over
all baseline-eligible children. Outcome models also use response weights. All
trial-dependent stages are repeated in the sensitivity bootstrap. Probabilities
below 0.01 stop this analysis; they are not silently truncated. Availability of a
baseline-eligible denominator in the cleaned trial extract must be established by
the upstream filter audit. Response MAR, a suitable response model and positivity
are additional sensitivity assumptions.

Only aggregate tables and publication figures are intended for Amir to review
locally. No data-derived artifact is automatically copied, committed, uploaded,
or sent to collaborators.

After fitting, `Rscript paper/applications/gps/figures.R` reads only the aggregate
files in `GPS_OUTPUT_DIR` and generates P025/P026 effects and diagnostics, plus a
separate negative-control plot. Bins containing fewer than five records are not
exported. Profiles require both randomized arms within the same categorical
baseline pattern and a local baseline-WFLz neighborhood. An unavailable profile
stays marked unavailable in the table and figure.
