# roscar

Calibrate external outcome predictions in a randomized trial, then estimate
conditional treatment effects from randomized pseudo-outcomes. This package
supports the tutorial **Borrow Predictions, Not Causal Effects**.

## Install

```r
remotes::install_github("AsiaeeLab/roscar")
```

From a local checkout, use `R CMD INSTALL .`.

R >= 4.1 and glmnet are required. The optional learners use mgcv, ranger, and
SuperLearner. The causal forest comparator requires grf. The main branch is a development version; a release tag will identify the final paper version.

## Example: external controls only (Recipe B)

```r
library(roscar)
s <- simulate_scenario("teaching", n_r = 200, n_o = 2000, seed = 20260914)
ext <- external_data(s$ext$X[s$ext$A == -1, ],
                     Y = s$ext$Y[s$ext$A == -1])
fit <- borrow_cate(
  s$trial, ext, recipe = "B", basis = ~ X1, K = 5, seed = 20260914,
  learners = list(external = learner_ols(), calibration = learner_intercept(),
                  trial = learner_ols())
)
fit
```

```text
roscar: B; 200 trial rows; 5 grouped folds
Effect basis: ~X1
```

The complete generated output, point estimates, and 500-resample intervals for
the two-arm teaching example are in `paper/teaching/output/`.

```r
grid <- s$profiles
boot <- bootstrap_cate(fit, B = 500, grid = grid, seed = 20260915)
boot$intervals
plot(diagnose(fit, B = 500, seed = 20260915))
```

## Data and modeling contract

* `trial_data(X, A, Y, pi, id, strata)` accepts 0/1 or -1/+1 treatment.
  **`pi` is the probability of the observed arm.** With positive-arm probability
  `p`, supply `pi = ifelse(A == 1, p, 1 - p)`. Without `pi`, observed arm
  proportions within design strata are used and must permit both arms.
* `personalized_baseline(plus, minus, pi)` instead takes the **positive-arm**
  probability, available as `trial$p_plus`. Opposite-arm weights are essential.
* `X` must be finite numeric data. Encode categorical predictors explicitly and
  harmonize columns across sources. Specify shared/trial-only/external-only
  blocks for mismatch. Independent unit IDs can have multiple rows; folds and
  bootstrap copies remain grouped. This is not a validated general extension to
  cluster-randomized trials with few clusters or cross-source dependence.
* Learners supply `fit` and `predict`. Gaussian predictions are residual-scale
  corrections; the caller adds the offset. Binomial predictions are link-scale
  corrections. Final pseudo-outcomes always use a squared-loss regression.
* The final `basis` is a prespecified one-sided formula with an intercept.
  Trial nuisance fitting and tuning exclude each evaluation unit. The final
  regression uses all held-out pseudo-outcomes; honest evaluation of that CATE
  regression itself requires an additional outer split.
* Recipe C defaults to an offset correction. At any prediction grid the
  preliminary contrast averages the fold models; the same rule is repeated in
  bootstrap. Held-out arm quantities are stored separately in `fit$heldout`.
* `B = 0` is the computational API default. Paper examples use `B = 500`.
  Bootstrap intervals are pointwise, conditional on the external source, and
  include full trial refitting. Failures are reported; no coverage is assumed
  for arbitrary regularized final models. `vcov(fit)` is an explicitly labeled
  fixed-nuisance sandwich approximation for a linear final regression.

## Recipes and comparisons

| Recipe | External resource | Mapping |
|---|---|---|
| A | Both arms, matched predictors | Identity |
| B | One arm | Calibrate that arm; estimate the other in the trial |
| C | Shared and external-only predictors | Ridge imputation, MR-OSCAR offset correction |
| D | Shared and external-only predictors | Supervised external PLS, ridge imputation, linear CALM |

D uses pooled external outcome supervision with treatment excluded from the
encoder. `pls_by_arm = TRUE` is an optional alternative. Dimensions are selected
from 1–3 using external prediction error. `method = "shared_only"` provides
SR-OSCAR. Neural CALM and B-CALM are cited but not implemented.

`compare_methods()` includes RACER, no/uncalibrated/oracle augmentation, trial
interaction OLS, R-learner, grf causal forest, interaction prognostic adjustment,
and pooling. Unsupported configurations and missing optional packages return
explicit status and error messages. `diagnose()` separates arm losses,
pseudo-outcome variance, calibration, support, and weighted prediction evidence.

## Reproduce the paper

```sh
Rscript paper/make.R --quick --workers=48
```

See the simulation and application README files for full settings and seeds.
STAR is reconstructed from primary CC0 Dataverse data, with column-by-column
verification against the published extract; the unlicensed extract is never
redistributed. Source overlap and incomplete covariates are audited explicitly.

Greenlight code reads `GPS_CLEAN_DIR` and requires an output directory outside
all repositories. It is run by the data-authorized investigator. No protected
data, derived datasets, synthetic mimic, or participant-level output is shipped.

## Provenance and compatibility

This checkout preserves the full history of
[Cole Beck's ROSCAR](https://github.com/couthcommander/ROSCAR).
The original `cate_model()`/`model_roscar()` engine remains available with its
original 0/1 coding and in-sample default. The tutorial API has different
cross-fitting, tuning, and final-regression defaults; it does not promise equal
predictions under unequal settings.

One-arm estimation and diagnostics derive from the frozen
[JMLR reproduction archive](https://github.com/AsiaeeLab/r-oscar).
MR-OSCAR follows Pal, Huling, and Asiaee's algorithm; linear CALM follows
Asiaee and Pal's external PLS and ridge implementation. `citation("roscar")`
provides the references. GPL-3.
