# Public STAR reproduction

From the package root, run `Rscript paper/applications/star/download_preprocess.R`,
then `Rscript paper/applications/star/run.R --quick`. Omit `--quick` for 30
repetitions at each trial fraction and 500 bootstrap resamples. The complete run
has 450 recipe/learner combinations plus comparators and must be timed before
running at scale.

## Verified reconstruction (September 14, 2026)

The [Harvard Dataverse primary record](https://dataverse.harvard.edu/dataset.xhtml?persistentId=hdl:1902.1/10766)
records CC0 1.0. Its `PROJECT STAR.zip` file is ID 666720, MD5
`a4d06a13d807799791695c16ce1f52f8`. Its students SPSS table has 11,601 rows and
379 columns. Selecting the documented 43 columns reconstructs every substantive
value, in row order, in the
[Kallus comparison extract](https://github.com/CausalML/RemovingHiddenConfounding/blob/master/STAR_Students_for_Uri.csv).
The comparison CSV also has two empty trailing columns; these are checked and
excluded from the substantive extract. The comparison is pinned to commit `a25cf3d2524a01c8a8d821f25cdeeb312c34a9cd`;
the primary dataset is version 1.0 and a new version requires a fresh audit.
The comparison CSV is downloaded only to
a temporary directory and deleted. Outputs derive only from licensed primary data.

There are 4,509 small/regular first-grade students; requiring all three first-grade
test scores produces exactly 4,218. This is complete **outcome** data, not complete
baseline data: race is missing for 1 student, birth date for 3, first-grade lunch
for 76, and kindergarten lunch for 1,278. Birth-date missingness is handled by
outcome-free median imputation and a missingness indicator. Missing categorical
values remain explicit. The arithmetic mean of reading, mathematics, and listening
scores defines the outcome. The audit stores column equality and an MD5 checksum
of sorted complete outcomes formatted to twelve decimal places plus line breaks.

## Design limitations that must accompany the results

The [primary user guide](https://dataverse.harvard.edu/api/access/datafile/666705)
records within-school assignment, additional first-grade entrants, and reassignment
between regular and regular-with-aide classes after kindergarten. The extract does
not supply actual assignment probabilities. The runner uses within-school
small-class fractions in the full two-arm complete-outcome cohort, frozen before
source construction, and labels these as **estimated**. Thus, exact reconstruction
of the assignment mechanism remains unresolved.

All 236 first-grade teacher IDs in the outcome-complete two-arm cohort occur in
one treatment arm each. Teacher identity is excluded from the effect basis.
School:teacher is the available classroom proxy and is always used to group folds
and resampling; overlap across sources is reported for every construction.
Conditional bootstrapping with external rows fixed does not remove cross-source
classroom dependence. This limitation remains even with grouped trial resampling.

The primary basis contains sex, race, and a restricted cubic spline of birth date
with knots at its outcome-free quartiles. First-grade lunch is a descriptive
subgroup because its pretreatment timing is unresolved. Kindergarten lunch is
not automatically pretreatment for students randomized in kindergarten either.
The excluded lunch terms and teacher effect modifier differ from the original
high-dimensional source analysis and are not silently described as a replication.

The selection rule exactly follows `AsiaeeLab/r-oscar`'s
`experiments/example_star.R::CreateData`: Bernoulli sampling among rural/inner-city
students, all remaining regular-class students in the external source, and only
small-class students strictly below the pooled-geography outcome median. Each
median uses both arms and includes students subsequently sampled into the trial.
The source code's two geography pools are rural/inner city and urban/suburban,
not four separate geography-specific medians.

`run.R` maps P015–P019 to count/selection/overlap audits, effect intervals and
subgroup summaries, fit status, comparison methods, and diagnostic dashboards.
Full inferential results are not available until the runner finishes. An estimated
full-cohort reference is never treated as known CATE truth.

## Figure generation

After fitting, run `Rscript paper/applications/star/figures.R`. It creates P018
profile/width/subgroup panels and P019 calibration/variance/learner/borrowing
panels. With a nondefault result directory, source that script and pass the
same directory to `star_figures()` and `star_diagnostic_figures()`.

The source SPSS value labels identify free-lunch code 1 as free lunch and code 2
as non-free lunch; gender codes 1/2 are male/female. Geography codes 1–4 mean
inner city, suburban, rural, and urban, respectively.

## Parallel full run and restart

Set `ROSCAR_WORKERS=24` before invoking `run.R`, or call
`star_run(quick = FALSE, workers = 24)`. On Unix, independent q/repetition jobs
run in separate worker processes; Windows currently runs serially. Each job has
its own output directory. Completed attempts are reused only when the code,
primary-data checksum, seed, quick/full choice, R version, glmnet version and grf
version match. The parent merges summaries after workers finish. Per-job status
retains failed attempts; a failed method is never silently counted as a success.

Checkpoints retain public aggregate intervals/diagnostics, trial/source fold
memberships and fit status. The runner does not save the large fitted learner
objects or all individual bootstrap draws. Full draws remain available in the
package API for users who need them. The first quick run (five q values, one
repetition each, B=20, 15 recipe/learner fits) took about 319 seconds serially
before bootstrap reuse was added; timing does not include a successful prognostic
comparison and must be updated with the repaired comparator before projecting
full-run cost. Quick outputs are software checks, not manuscript results.

### Interaction comparator support

At the checked quick-run fractions, the declared effect basis includes rare or
missing-category interactions without sufficient arm-specific support for the
unpenalized interaction model. The prognostic-adjustment comparator is therefore
reported **unavailable**, with its rank-deficiency reason retained. Each job
writes nonzero support for every basis column by arm and the arm-specific basis
ranks. No effect terms are removed to force this comparator to return a number.
The public figure shows the comparison methods that were estimable; its notes
identify unavailable comparisons. This is a design/support limitation, separate
from a missing optional package or a software error.

`profile_support.R` performs a final reporting audit from each job's recorded
source memberships. It distinguishes the full cohort's original support counts
from each sampled trial's supporting arm counts. A profile with fewer than two
trial observations in either arm for its sex/race/free-lunch pattern is marked
unavailable consistently across all methods. `star_figures()` runs this audit
before rendering; the audit records its own source and primary-data checksums.
This reporting step does not refit or change any estimator. In the five-job
parallel quick check, 17 common profiles were retained and two were unavailable
in the q=0.2 sampled trial. These small-sample support checks are specific to each
construction and must be repeated over all 30 repetitions.
