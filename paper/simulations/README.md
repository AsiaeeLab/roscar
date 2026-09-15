# Simulation reproduction

## Prespecified design

The generator follows Section 8 of the tutorial for Scenarios 1–5. Audit A6
supersedes the manuscript's original inference and comparator budgets. This
folder adapts the grid/replication structure of `experiment()` from
`AsiaeeLab/r-oscar/R/05_experiment.R`; the source archive stays unchanged.

- Point performance: 500 independent replications per setting.
- Inference: the first 200 replications, with 200 complete trial-pipeline
  bootstrap resamples. All methods hold each replication's external sample fixed.
- Trial sizes: 200 and 500, except Scenario 6, which uses 250. External size: 2,000.
- Trial allocation: independent Bernoulli probability 0.5, supplied as known.
- All methods share each replication's trial, external data, and evaluation rows.
- The test set has 2,000 independent trial covariate rows drawn once with seed
  20260901, independent of the replication seed. Test covariates are fixed across
  replications. This seed is recorded in every output row.
- Three profiles have first effect modifier -1, 0, or 1 and all other coordinates
  zero. Integrated error is averaged over the fixed test set.
- Population and first-modifier subgroup targets use exact moments of the
  complete prediction dictionary: original trial covariates and sine/cosine
  of the first four coordinates. This includes Recipe C's preliminary-contrast
  offset as well as the final effect basis. Reconstruction on 100 independent
  test rows verifies that each fitted prediction lies in this span before
  population integration is accepted. One-dimensional quadrature for subgroup
  sine moments has relative tolerance 1e-12; the generator records the absolute
  error bound for its Scenario 5 analytic subgroup truth.
  Population averages of unrestricted causal-forest predictions are unavailable;
  the finite test-set average is not mislabeled as an exact population target.

Scenarios 1, 2, 3, 5, and 6 use a Gaussian AR(1) covariance with correlation 0.3.
The teaching example separately uses four independent standard-normal covariates.

1. **Useful prediction.** Trial prognosis is
   `g = 2 + X1 + X2 + .5*X3 + .5*sin(X4)` and
   `tau = .5 + .5*X1 - .25*X2`. The outcome is `g + A*tau/2 + epsilon`.
   The external sample adds 0.5 to the outcome mean.
2. **Hidden confounding.** The trial is unchanged. External treatment probability
   is `plogis(.6*X1 + 1.2*L)` for an independent, unobserved standard-normal `L`.
   The external outcome adds `L` to the trial mean. No fitted dataset includes `L`.
3. **Unhelpful external prognosis.** Two external mechanisms are evaluated:
   `A/2 + epsilon`, and `4 - g + 2*cos(X1) + A*tau/2 + epsilon`.
4. **Mismatch.** Independent standard-normal Z1:Z4, U1:U2, eta1:eta6, with
   `Vj = rho*Z[1+((j-1) %% 4)] + sqrt(1-rho^2)*etaj` and rho 0 or 0.8.
   Trial observes Z,U; external observes Z,V. Both have latent full outcome
   `2 + Z1 + .5*Z2 + V1 + .5*V2 + .5*U1 + A*(.5+.5*Z1-.25*U1)/2 + epsilon`;
   the external adds 0.5. U1 remains in every final trial effect basis.
5. **One arm.** Controls have `g-tau/2`; treated subjects have
   `g+tau/2+kappa*sin(X3)`. External controls have
   `.5+gamma*(g-tau/2)+epsilon`. Gamma and kappa each range over 0 and 1.
   Treated nuisance fits use either main effects only or those main effects plus
   sin(X3),sin(X4). The final basis always includes sin(X3). The paired RACER
   comparator uses exactly the same treated nuisance as Recipe B.
6. **Sparse extension (explicit implementation choice).** Audit A6 requested this
   scenario without coefficients. We fix p=100 and use the same AR(1) Gaussian
   distribution. Trial prognosis is `2 + X %*% beta`; beta is zero after X10 and
   is `(1,-1,.75,-.75,.5,1,-1,.75,-.75,.5)` on X1:X10. The effect is
   `.5+.5*X1-.25*X2`. The external prognosis adds `.5+.75*X99-.75*X100`.
   Outcome errors are standard normal and allocation is balanced Bernoulli.
   Thus `support_fraction=.1`, `delta_fraction=.02`, both arm regressions are
   sparse, and the source discrepancy is covariate-dependent and sparse.
   Coefficients are fixed before assessing performance; the generator is never
   changed to obtain a benefit. Nondefault support fractions deterministically
   extend/truncate the documented repeating coefficients and shift support.

## Methods and tuning

The applicable calibrated recipe is compared with no augmentation, RACER,
uncalibrated external augmentation, an unattainable oracle baseline, trial
interaction regression, R-learner, causal forest, interaction-based prognostic
adjustment, and pooling with a source indicator. Mismatch includes shared-only
borrowing, Recipe C, and Recipe D. Unsupported combinations remain explicit
unavailable rows. Audit A6 excludes Bayesian and external-standardization methods.

External and trial arm nuisances use ridge with main effects and sine/cosine of
the first four observed coordinates. The one-arm treated restriction is the
exception specified above. Intercept, ridge, and lasso discrepancy calibration
are compared. Penalized fits use 25 log-spaced penalties from 1e-4 to 1e2,
standardized predictors, an unpenalized intercept, and five training-sample
validation folds. Every trial-dependent fit and tuning step is rerun inside the
appropriate training sample. Calibration changes alone do not change simulated
data, nuisance seeds, bootstrap seeds, or test covariates. The one-arm linear
and sine-augmented nuisance analyses also share generated data and seeds.
Final effect fits are
unpenalized on the exact prespecified effect basis.

## Running

Run from the package root after installing the package and its suggested
reproduction dependencies:

```r
library(roscar)
source("paper/simulations/harness.R")
source("paper/simulations/figures.R")
source("paper/simulations/anomaly.R")
quick <- run_simulations(quick = TRUE, workers = 16)
anomaly <- run_anomaly_check(workers = 16)  # 200 point-estimate replications
full <- run_simulations(workers = 16)
write_simulation_figures(full$summary, file.path(full$directory, "figures"))
```

`scenario1.R` through `scenario6.R` are separate ADEMP-ordered entry points for
running one scenario with the shared harness. The top-level `paper/make.R`
orchestrates these alongside the teaching example and public-data application.
Quick mode uses ten replications with B=20. It is a software check; its coverage
or RMSE is not publication evidence. `run_anomaly_check()` assesses Scenario 1
at both trial sizes and Scenario 6 at n=250 under all three calibration learners.

Every invocation writes a source/configuration hash, a runnable snapshot of the
R and reproduction source, R/dependency versions,
settings CSV, seed ledger, per-replication checkpoints, raw CSV, summary CSV,
per-scenario summary CSVs, and elapsed time. Replication checkpoints are finalized
by an atomic rename. An identical invocation resumes finished replications;
changed scientific settings or source code receive a separate run directory.
Bootstrap B is also part of the checkpoint filename. Point-only checkpoints do
not masquerade as interval runs. Independent replication jobs run in parallel
on Unix, with a serial Windows fallback. No outcome-dependent tuning of design
settings occurs. Use single-threaded BLAS when running many workers.

## Performance summaries

Bias is the mean error, with SD(error)/sqrt(successful replications) as MCSE.
RMSE is sqrt(mean squared error); integrated RMSE is sqrt(mean ISE), never the
mean of replication RMSEs. Its MCSE uses the delta method applied to squared
errors. Integrated RMSE ratios use paired ISE summaries and their covariance.
Coverage is conditional on finite, successful intervals, with binomial MCSE
using the number of successful intervals. Failed fits do not count as coverage.
The paired width ratio is averaged within replications, not computed from two
separately averaged widths. Paired mean differences and ratios report their
empirical standard errors. Attempted fits, successful estimates, unavailable
methods, failed fits, and attempted/successful intervals are separate columns.
Whole-replication failures also contribute failed rows for every attempted
method and target.

Figure 4 is split into readable four-panel plates by scenario and calibration;
Figure 5 has one four-panel plate per calibration. Source CSVs preserve the full
factorial design. Error bars are 1.96 MCSEs. Each exported PDF has a matching PNG
and a caption file. Width labels next to Figure 5 coverage points implement the
explicit P014 specification. The figure-style skill supplies typography,
blue/orange colors, and 183-mm-wide publication sizing.
