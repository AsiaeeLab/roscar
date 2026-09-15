# Section 4.3 and placeholders P002/P003. Independent synthetic teaching data;
# these data are unrelated to any protected application.
run_teaching <- function(output_dir = "paper/teaching/output", B = 500L,
                         seed = 20260914L) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  sim <- simulate_scenario("teaching", n_r = 200L, n_o = 2000L, seed = seed)
  learners <- list(external = learner_ols(), calibration = learner_intercept(),
                   trial = learner_ols(), final = learner_ols())
  fit <- borrow_cate(sim$trial, sim$ext, recipe = "A", learners = learners,
                     basis = ~X1, K = 5L, B = B, grid = sim$profiles, seed = seed)
  held <- fit$heldout
  required <- c("fold", "A", "pi", "q_plus", "q_minus", "mu_cal_plus", "mu_cal_minus", "baseline", "pseudo_outcome")
  stopifnot(all(required %in% names(held)))
  rows <- head(held[, required], 6L)
  rows$external_prediction <- ifelse(rows$A == 1, rows$q_plus, rows$q_minus)
  rows <- rows[, c("fold", "A", "pi", "external_prediction", "q_plus", "q_minus", "mu_cal_plus", "mu_cal_minus", "baseline", "pseudo_outcome")]
  # This sign/factor check is deliberately visible next to the printed rows.
  stopifnot(isTRUE(all.equal(rows$pseudo_outcome,
    head(sim$trial$A * (sim$trial$Y - held$baseline) / sim$trial$pi, 6L), check.attributes = FALSE)))
  summary <- data.frame(X1 = c(-1, 0, 1), truth = sim$truth_profiles,
                         recipe_A = as.numeric(predict(fit, sim$profiles)),
                         trial_only = as.numeric(predict(fit$trial_only, sim$profiles)))
  for (nm in c("recipe_A_lower", "recipe_A_upper", "trial_only_lower", "trial_only_upper", "width_ratio"))
    summary[[nm]] <- NA_real_
  boot <- fit$bootstrap
  if (B > 0L && !is.null(boot)) {
    summary$recipe_A_lower <- boot$intervals$lower
    summary$recipe_A_upper <- boot$intervals$upper
    if (!is.null(boot$trial_draws)) {
      td <- as.matrix(boot$trial_draws)
      qq <- apply(td, 2, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE)
      summary$trial_only_lower <- qq[1L, ]
      summary$trial_only_upper <- qq[2L, ]
    }
    summary$width_ratio <- (summary$recipe_A_upper - summary$recipe_A_lower) /
      (summary$trial_only_upper - summary$trial_only_lower)
  }
  variance <- data.frame(baseline = c("None", "Trial-only", "Uncalibrated external", "Calibrated external"),
    heldout_pseudo_outcome_variance = vapply(c("psi_none", "psi_trial", "psi_external", "pseudo_outcome"),
                                              function(nm) stats::var(held[[nm]]), numeric(1)))
  call <- c(sprintf('sim <- simulate_scenario("teaching", n_r = 200, n_o = 2000, seed = %d)', seed),
            'fit <- borrow_cate(sim$trial, sim$ext, recipe = "A",',
            '  learners = list(external = learner_ols(), calibration = learner_intercept(),',
            '                  trial = learner_ols(), final = learner_ols()),',
            sprintf('  basis = ~X1, K = 5, B = %d, grid = sim$profiles, seed = %d)', B, seed))
  utils::write.csv(rows, file.path(output_dir, "heldout_first_six.csv"), row.names = FALSE)
  utils::write.csv(summary, file.path(output_dir, "cate_profiles.csv"), row.names = FALSE)
  utils::write.csv(variance, file.path(output_dir, "pseudo_outcome_variances.csv"), row.names = FALSE)
  writeLines(call, file.path(output_dir, "call.R"))
  text <- c("Section 4.3 teaching example; independent synthetic data", "", call, "",
             "First six held-out rows:", capture.output(print(rows, digits = 6, row.names = FALSE)), "",
             "Profile estimates and analytic truths (truth is not an estimate):",
             capture.output(print(summary, digits = 6, row.names = FALSE)), "",
             "Pseudo-outcome variances on identical held-out trial rows:",
             capture.output(print(variance, digits = 6, row.names = FALSE)), "",
             paste0("Bootstrap resamples attempted: ", B),
             paste0("Bootstrap resamples successful: ", if (is.null(boot)) 0L else boot$successful),
             "Intervals are pointwise percentile confidence intervals conditional on this external sample.",
             "A width ratio above one means increased uncertainty; below one means reduced uncertainty.",
             "This single example does not estimate coverage or typical efficiency gains.")
  writeLines(text, file.path(output_dir, "paste_ready.txt"))
  saveRDS(list(metadata = sim$metadata, B = B, fit = fit, profiles = summary, variance = variance),
          file.path(output_dir, "teaching.rds"))
  writeLines(capture.output(utils::sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
  list(fit = fit, profiles = summary, variance = variance, rows = rows, output_dir = output_dir)
}
