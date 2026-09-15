# Replication-grid design adapted from AsiaeeLab/r-oscar/R/05_experiment.R,
# experiment(), by Amir Asiaee and Cole Beck. The seed ledger, restartable
# checkpoints, failure accounting, interval subset, and MCSEs are new.

simulation_settings <- function(scenarios = 1:6, calibration = c("intercept", "ridge", "lasso")) {
  out <- list()
  for (scenario in scenarios) {
    grid <- expand.grid(n_r = if (scenario == 6) 250L else c(200L, 500L),
                        variant = if (scenario == 3) c("nonprognostic", "reversed") else "nonprognostic",
                        rho = if (scenario == 4) c(0, 0.8) else 0,
                        gamma = if (scenario == 5) 0:1 else 1,
                        kappa = if (scenario == 5) 0:1 else 0,
                        treated_nuisance = if (scenario == 5) c("linear", "sine") else "dictionary",
                        calibration = calibration, stringsAsFactors = FALSE)
    grid$scenario <- scenario
    grid$n_o <- 2000L
    grid$setting <- apply(grid, 1, function(x) paste0("s", x["scenario"], "_n", x["n_r"],
      "_", x["variant"], "_rho", x["rho"], "_g", x["gamma"], "_k", x["kappa"],
      "_", x["treated_nuisance"], "_", x["calibration"]))
    grid$setting <- gsub("[[:space:]]", "", grid$setting)
    out[[length(out) + 1L]] <- grid
  }
  do.call(rbind, out)
}

# Select a feature map once, based on covariate names. Every fitted scaler
# and tuning fold remains inside the underlying learner's fit() call.
dictionary_learner <- function(learner, mode = c("dictionary", "linear", "sine")) {
  mode <- match.arg(mode)
  expand <- function(X) {
    X <- as.data.frame(X)
    out <- X
    if (mode == "dictionary") {
      for (j in seq_len(min(4L, ncol(X)))) {
        out[[paste0("sin_", names(X)[j])]] <- sin(X[[j]])
        out[[paste0("cos_", names(X)[j])]] <- cos(X[[j]])
      }
    } else if (mode == "sine") {
      for (nm in intersect(c("X3", "X4"), names(X))) out[[paste0("sin_", nm)]] <- sin(X[[nm]])
    }
    as.matrix(out)
  }
  ans <- learner
  ans$name <- paste0(if (is.null(learner$name)) "learner" else learner$name, "_", mode)
  ans$fit <- function(X, y, weights = NULL, offset = NULL, ...) {
    learner$fit(expand(X), y, weights = weights, offset = offset, ...)
  }
  ans$predict <- function(fit, X, ...) learner$predict(fit, expand(X), ...)
  ans
}

simulation_learners <- function(setting, seed) {
  lambda <- 10^seq(-4, 2, length.out = 25L)
  ridge <- learner_ridge(lambda = lambda, seed = seed)
  calibration <- switch(setting$calibration,
    intercept = learner_intercept(), ridge = ridge,
    lasso = learner_lasso(lambda = lambda, seed = seed))
  # The same ridge nuisance and tuning grid define RACER and the calibrated pair.
  list(external = dictionary_learner(ridge),
       trial = dictionary_learner(ridge),
       rlearner = dictionary_learner(learner_lasso(lambda = lambda, seed = seed)),
       trial_minus = dictionary_learner(ridge),
       trial_plus = dictionary_learner(ridge, setting$treated_nuisance),
       calibration = if (setting$calibration == "intercept") calibration else dictionary_learner(calibration),
       final = learner_ols())
}

simulation_methods <- function(scenario, anomaly = FALSE) {
  if (anomaly) return(c("racer", "A"))
  recipes <- if (scenario == 4) c("shared_only", "C", "D") else if (scenario == 5) "B" else "A"
  c("none", "racer", "oracle", "uncalibrated", recipes, "interaction_ols",
    "rlearner", "causal_forest", "procova_interaction", "pooled")
}

simulation_registry <- function(settings, anomaly = FALSE) {
  version <- function(package) {
    tryCatch(as.character(utils::packageVersion(package)), error = function(e) "unavailable")
  }
  rows <- lapply(seq_len(nrow(settings)), function(i) {
    z <- settings[i, ]
    methods <- simulation_methods(z$scenario, anomaly)
    specifications <- c(none = "unaugmented randomized pseudo-outcome; unpenalized effect-basis regression",
      racer = "cross-fitted trial-arm augmentation; unpenalized effect-basis regression",
      oracle = "analytic oracle baseline; unpenalized effect-basis regression",
      uncalibrated = "transported external augmentation without discrepancy correction",
      A = "two external arms; identity transport; trial calibration",
      B = "external controls; trial-only treated arm; trial control calibration",
      shared_only = "SR-OSCAR; shared external predictors; original trial calibration and CATE offset",
      C = "MR-OSCAR; ridge block imputation; discrepancy calibration and CATE offset",
      D = "CALM-Lin; external pooled outcome-supervised PLS; trial calibration; 1-3 components by external CV",
      interaction_ols = "trial OLS main effects and treatment-by-effect-basis interactions",
      rlearner = "cross-fitted lasso outcome residual; known treatment residual; weighted effect-basis regression",
      causal_forest = "grf causal forest; known propensity; native pointwise variance",
      procova_interaction = "external prognostic score plus effect-basis main effects and treatment interactions",
      pooled = "stacked trial/external OLS with study indicator and shared treatment interactions")
    data.frame(setting = z$setting, scenario = z$scenario, method = methods,
      fitted_model = unname(specifications[methods]),
      implementation = ifelse(methods == "causal_forest", "grf", "roscar / stats / glmnet"),
      glmnet_version = version("glmnet"), grf_version = version("grf"),
      effect_basis = if (z$scenario == 4) "~ Z1 + U1" else if (z$scenario == 5) "~ X1 + X2 + sin(X3)" else "~ X1 + X2",
      calibration = z$calibration, treated_nuisance = z$treated_nuisance,
      external_nuisance = "ridge; main effects + sine/cosine first four observed coordinates",
      trial_nuisance = "ridge; main effects + sine/cosine first four; Scenario 5 treated restriction applies",
      rlearner_nuisance = "lasso; main effects + sine/cosine first four observed coordinates",
      penalty_grid = "25 log-spaced values from 1e-4 to 1e2; minimum validation MSE",
      training_validation_folds = 5L, trial_crossfit_folds = 5L,
      predictor_standardization = "training sample only; unpenalized intercept",
      interval_method = ifelse(methods == "causal_forest", "grf pointwise asymptotic normal", "conditional trial-unit percentile bootstrap"),
      population_targets = ifelse(methods == "causal_forest", "unavailable: unrestricted prediction span", "integrated full prediction dictionary including Recipe C offset"),
      configuration_supported = !(z$scenario == 4 & methods == "pooled"),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

simulation_hash <- function(object) {
  p <- tempfile("roscar-config-", fileext = ".rds")
  on.exit(unlink(p), add = TRUE)
  saveRDS(object, p, version = 2)
  unname(tools::md5sum(p))
}

simulation_source_hash <- function(root = ".") {
  paths <- c(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE),
             file.path(root, "paper/simulations/harness.R"))
  unname(tools::md5sum(paths[file.exists(paths)]))
}

# Integrate the complete linear/sine/cosine prediction span. Recipe C includes
# its preliminary-contrast offset, so integrating only the final effect basis
# would be incorrect. Under these generators and the specified ridge imputer,
# all regular estimators lie in this larger dictionary on original trial X.
population_contrasts <- function(sim) {
  X <- sim$center_X
  columns <- colnames(X)
  nonlinear <- head(columns, 4L)
  terms <- c(columns, paste0("sin(", nonlinear, ")"), paste0("cos(", nonlinear, ")"))
  full_basis <- stats::reformulate(terms)
  anchors <- X[rep(1L, length(terms) + 1L), , drop = FALSE]
  row <- 1L
  for (nm in columns) {
    values <- if (nm %in% nonlinear) c(-1, 1, 2) else 1
    for (value in values) {
      row <- row + 1L
      anchors[row, nm] <- value
    }
  }
  design <- stats::model.matrix(full_basis, as.data.frame(anchors))
  moment <- matrix(0, 3L, ncol(design), dimnames = list(c("average", "below_zero", "above_zero"), colnames(design)))
  moment[, 1L] <- 1
  h <- sqrt(2 / pi)
  s <- sim$metadata$scenario
  for (j in seq_along(columns)) {
    nm <- columns[j]
    rr <- if (j == 1L) 1 else if (s %in% c("4", "teaching")) 0 else 0.3^(j - 1L)
    moment[2:3, nm] <- c(-rr * h, rr * h)
    if (nm %in% nonlinear) {
      sin_mean <- if (rr == 0) 0 else stats::integrate(function(z)
        2 * sin(rr * z) * exp(-(1 - rr^2) / 2) * stats::dnorm(z),
        0, Inf, rel.tol = 1e-12)$value
      moment[2:3, paste0("sin(", nm, ")")] <- c(-sin_mean, sin_mean)
      moment[, paste0("cos(", nm, ")")] <- exp(-0.5)
    }
  }
  list(anchors = anchors, weights = moment %*% solve(design), moments = moment, basis = full_basis)
}

simulation_replication <- function(setting, replication, seed, B = 0L,
                                   methods = simulation_methods(setting$scenario)) {
  began <- proc.time()[["elapsed"]]
  sim <- simulate_scenario(setting$scenario, n_r = setting$n_r, n_o = setting$n_o,
                           seed = seed, variant = setting$variant, rho = setting$rho,
                           gamma = setting$gamma, kappa = setting$kappa)
  pop <- population_contrasts(sim)
  grid <- rbind(sim$profiles, sim$test_X, pop$anchors)
  test_idx <- 3L + seq_len(nrow(sim$test_X))
  anchor_idx <- 3L + nrow(sim$test_X) + seq_len(nrow(pop$anchors))
  anchor_design <- stats::model.matrix(pop$basis, as.data.frame(pop$anchors))
  check_idx <- test_idx[seq_len(min(100L, length(test_idx)))]
  check_design <- stats::model.matrix(pop$basis, as.data.frame(grid[check_idx, , drop = FALSE]))
  result <- compare_methods(sim$trial, sim$ext, methods = methods, grid = grid,
                            basis = sim$basis, learners = simulation_learners(setting, seed),
                            B = B, K = 5L, seed = seed + 100000L,
                            shared = sim$shared, trial_only = sim$trial_only,
                            external_only = sim$external_only,
                            arm_ext = -1, oracle_baseline = sim$oracle_baseline)
  targets <- c("profile_minus1", "profile_zero", "profile_plus1", "integrated",
               "average", "below_zero", "above_zero")
  truth <- c(sim$truth_profiles, NA_real_, sim$truth_average, sim$truth_subgroups)
  rows <- list()
  for (method in methods) {
    value <- result[[method]]
    if (is.null(value)) value <- list(status = "failed", error = "Method returned no result")
    ok <- identical(value$status, "success") || identical(value$status, "ok")
    if (is.null(value$status)) ok <- !is.null(value$prediction)
    pred <- value$prediction
    if (ok && (length(pred) != nrow(grid) || any(!is.finite(pred)))) {
      ok <- FALSE
      value$status <- "failed"
      value$error <- "Nonfinite or incorrectly sized predictions"
    }
    estimates <- rep(NA_real_, length(targets))
    lower <- upper <- estimates
    ise <- pseudo_variance <- control_loss <- imputation_mse <- imputation_r_squared <- embed_dim <- NA_real_
    bootstrap_successful <- 0L
    prediction_span_max_error <- NA_real_
    population_supported <- FALSE
    if (ok) {
      estimates[1:3] <- pred[1:3]
      ise <- mean((pred[test_idx] - sim$truth_test)^2)
      # Forests are not restricted to the effect basis, so these population
      # functionals are unavailable rather than silently approximated by anchors.
      if (method != "causal_forest") {
        co <- solve(anchor_design, pred[anchor_idx])
        prediction_span_max_error <- max(abs(drop(check_design %*% co) - pred[check_idx]))
        population_supported <- prediction_span_max_error < 1e-7 * (1 + max(abs(pred[check_idx])))
        if (population_supported) estimates[5:7] <- drop(pop$weights %*% pred[anchor_idx])
      }
      interval <- value$interval
      if (!is.null(interval) && nrow(interval) >= 3L) {
        lower[1:3] <- interval$lower[1:3]
        upper[1:3] <- interval$upper[1:3]
      }
      fit <- value$fit
      if (!is.null(fit$bootstrap$successful)) bootstrap_successful <- fit$bootstrap$successful
      meta <- fit$transport$metadata
      if (!is.null(meta$imputation_validation)) {
        imputation_mse <- mean(meta$imputation_validation$mse)
        imputation_r_squared <- mean(meta$imputation_validation$r_squared)
      }
      if (!is.null(meta$embed_dim)) embed_dim <- meta$embed_dim
      if (!is.null(fit$bootstrap$draws) && population_supported) {
        draws <- as.matrix(fit$bootstrap$draws)
        if (ncol(draws) == nrow(grid)) {
          pop_draws <- draws[, anchor_idx, drop = FALSE] %*% t(pop$weights)
          enough <- colSums(is.finite(pop_draws)) >= 2L
          for (j in which(enough)) {
            qq <- stats::quantile(pop_draws[, j], c(0.025, 0.975), na.rm = TRUE, names = FALSE)
            lower[j + 4L] <- qq[1L]
            upper[j + 4L] <- qq[2L]
          }
        }
      }
      held <- fit$heldout
      if (!is.null(held)) {
        pseudo_variance <- stats::var(held$pseudo_outcome)
        ix <- sim$trial$A == -1
        mu <- if (method == "racer") held$mu_trial_minus else held$mu_cal_minus
        if (length(mu) == length(ix)) control_loss <- mean((sim$trial$Y[ix] - mu[ix])^2)
      }
    }
    width <- upper - lower
    rr <- data.frame(setting = setting$setting, scenario = setting$scenario,
       n_r = setting$n_r, n_o = setting$n_o, calibration = setting$calibration,
       variant = setting$variant, rho = setting$rho, gamma = setting$gamma, kappa = setting$kappa,
       treated_nuisance = setting$treated_nuisance, replication = replication, seed = seed,
       test_seed = sim$metadata$test_seed, B = B,
       bootstrap_attempted = if (method == "causal_forest") 0L else B,
       bootstrap_successful = bootstrap_successful,
       method = method, target = targets,
       truth = truth, estimate = estimates, error = estimates - truth, ise = ise,
       lower = lower, upper = upper, width = width,
       covered = ifelse(is.finite(lower) & is.finite(upper), lower <= truth & upper >= truth, NA),
       width_ratio = NA_real_, pseudo_variance = pseudo_variance, control_loss = control_loss,
       imputation_mse = imputation_mse, imputation_r_squared = imputation_r_squared, embed_dim = embed_dim,
       prediction_span_max_error = prediction_span_max_error,
       status = if (ok) "success" else if (is.null(value$status)) "failed" else value$status,
       failure = if (is.null(value$error)) "" else value$error,
       interval_method = if (is.null(value$interval_method)) "unavailable" else value$interval_method,
       stringsAsFactors = FALSE)
    rows[[method]] <- rr
  }
  raw <- do.call(rbind, rows)
  ref <- raw[raw$method == "racer", ]
  if (nrow(ref)) {
    idx <- match(raw$target, ref$target)
    raw$width_ratio <- raw$width / ref$width[idx]
    raw$width_difference <- raw$width - ref$width[idx]
    raw$ise_racer <- ref$ise[idx]
    raw$ise_difference <- raw$ise - raw$ise_racer
    raw$variance_ratio <- raw$pseudo_variance / ref$pseudo_variance[idx]
    raw$control_loss_reduction <- ref$control_loss[idx] - raw$control_loss
  }
  raw$elapsed_seconds <- proc.time()[["elapsed"]] - began
  rownames(raw) <- NULL
  raw
}

failed_replication <- function(setting, replication, seed, B, methods, error) {
  targets <- c("profile_minus1", "profile_zero", "profile_plus1", "integrated", "average", "below_zero", "above_zero")
  out <- expand.grid(method = methods, target = targets, stringsAsFactors = FALSE)
  for (nm in c("setting", "scenario", "n_r", "n_o", "calibration", "variant", "rho", "gamma", "kappa", "treated_nuisance"))
    out[[nm]] <- setting[[nm]]
  out$replication <- replication
  out$seed <- seed
  out$test_seed <- 20260901L
  out$B <- B
  out$bootstrap_attempted <- ifelse(out$method == "causal_forest", 0L, B)
  out$bootstrap_successful <- 0L
  for (nm in c("truth", "estimate", "error", "ise", "lower", "upper", "width", "covered", "width_ratio",
               "pseudo_variance", "control_loss", "width_difference", "ise_racer", "ise_difference",
               "variance_ratio", "control_loss_reduction", "elapsed_seconds", "imputation_mse",
               "imputation_r_squared", "embed_dim", "prediction_span_max_error")) out[[nm]] <- NA_real_
  out$status <- "failed"
  out$failure <- error
  out$interval_method <- "unavailable due to replication failure"
  out
}

mcse_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2L) return(NA_real_)
  stats::sd(x) / sqrt(length(x))
}

simulation_summary <- function(raw) {
  groups <- split(raw, interaction(raw$setting, raw$method, raw$target, drop = TRUE, lex.order = TRUE))
  ans <- lapply(groups, function(z) {
    scalar <- function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
    err <- z$error[z$status == "success" & is.finite(z$error)]
    sq <- if (z$target[1L] == "integrated") z$ise[z$status == "success" & is.finite(z$ise)] else err^2
    rmse <- sqrt(scalar(sq))
    intervals <- z$B > 0L & is.finite(z$lower) & is.finite(z$upper) & is.finite(z$truth)
    coverage <- scalar(as.numeric(z$covered[intervals]))
    both <- is.finite(z$ise) & is.finite(z$ise_racer)
    ratio <- if (any(both)) sqrt(mean(z$ise[both]) / mean(z$ise_racer[both])) else NA_real_
    ratio_mcse <- if (sum(both) > 1L && is.finite(ratio) && ratio > 0) {
      x <- z$ise[both]; y <- z$ise_racer[both]
      mcse_mean(ratio / 2 * (x / mean(x) - y / mean(y)))
    } else NA_real_
    keys <- c("setting", "scenario", "n_r", "n_o", "calibration", "variant", "rho", "gamma", "kappa",
              "treated_nuisance", "method", "target", "interval_method")
    data.frame(z[1L, keys, drop = FALSE], attempted = nrow(z),
       successful = sum(z$status == "success" & (is.finite(z$estimate) | z$target == "integrated")),
       fit_failures = sum(z$status == "failed"), unavailable = sum(z$status == "unavailable"),
       target_unavailable = sum(z$status == "success" & !is.finite(z$estimate) & z$target != "integrated"),
       interval_attempted = sum(z$B > 0 & z$target != "integrated"), interval_successful = sum(intervals),
       bootstrap_draws_attempted = sum(z$bootstrap_attempted), bootstrap_draws_successful = sum(z$bootstrap_successful),
       bias = scalar(err), bias_mcse = mcse_mean(err), rmse = rmse,
       rmse_mcse = if (is.finite(rmse) && rmse > 0) mcse_mean(sq) / (2 * rmse) else NA_real_,
       coverage = coverage,
       coverage_mcse = if (sum(intervals)) sqrt(coverage * (1 - coverage) / sum(intervals)) else NA_real_,
       mean_width = scalar(z$width[intervals]), width_mcse = mcse_mean(z$width[intervals]),
       width_ratio = scalar(z$width_ratio[intervals]), width_ratio_mcse = mcse_mean(z$width_ratio[intervals]),
       width_difference = scalar(z$width_difference[intervals]),
       width_difference_mcse = mcse_mean(z$width_difference[intervals]),
       ise_difference = scalar(z$ise_difference), ise_difference_mcse = mcse_mean(z$ise_difference),
       integrated_rmse_ratio = ratio, integrated_rmse_ratio_mcse = ratio_mcse,
       ise_increase_frequency = scalar(as.numeric(z$ise_difference > 0)),
       width_increase_frequency = scalar(as.numeric(z$width_ratio[intervals] > 1)),
       variance_ratio = scalar(z$variance_ratio), variance_ratio_mcse = mcse_mean(z$variance_ratio),
       control_loss_reduction = scalar(z$control_loss_reduction),
       control_loss_reduction_mcse = mcse_mean(z$control_loss_reduction),
       pseudo_variance = scalar(z$pseudo_variance), control_loss = scalar(z$control_loss),
       imputation_mse = scalar(z$imputation_mse), imputation_mse_mcse = mcse_mean(z$imputation_mse),
       imputation_r_squared = scalar(z$imputation_r_squared),
       imputation_r_squared_mcse = mcse_mean(z$imputation_r_squared), mean_embed_dim = scalar(z$embed_dim),
       coverage_scope = "conditional on successful intervals", stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, ans)
  rownames(out) <- NULL
  out
}

run_simulations <- function(output_dir = "paper/simulations/results", quick = FALSE,
                            scenarios = 1:6, replications = if (quick) 10L else 500L,
                            bootstrap_reps = if (quick) 10L else 200L,
                            B = if (quick) 20L else 200L,
                            workers = min(8L, parallel::detectCores()),
                            anomaly = FALSE, seed = 20260914L,
                            calibration = c("intercept", "ridge", "lasso"), root = ".") {
  stopifnot(replications > 0L, bootstrap_reps >= 0L, B >= 0L, workers >= 1L)
  settings <- simulation_settings(scenarios, calibration)
  config <- list(settings = settings, seed = seed, anomaly = anomaly,
                 code = simulation_source_hash(root), R = R.version.string,
                 glmnet = as.character(utils::packageVersion("glmnet")))
  digest <- substr(simulation_hash(config), 1L, 12L)
  out <- file.path(output_dir, digest)
  checkpoints <- file.path(out, "checkpoints")
  dir.create(checkpoints, recursive = TRUE, showWarnings = FALSE)
  saveRDS(config, file.path(out, "configuration.rds"))
  # Preserve runnable source along with hashes, including uncommitted changes.
  # A restart keeps the original snapshot for this immutable configuration.
  snapshot <- file.path(out, "source")
  for (folder in c("R", "paper/simulations")) {
    target <- file.path(snapshot, folder)
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    files <- list.files(file.path(root, folder), pattern = "\\.(R|md)$", full.names = TRUE)
    invisible(file.copy(files, target, overwrite = FALSE))
  }
  root_files <- file.path(root, c("DESCRIPTION", "NAMESPACE"))
  invisible(file.copy(root_files[file.exists(root_files)], snapshot, overwrite = FALSE))
  writeLines(capture.output(utils::sessionInfo()), file.path(snapshot, "sessionInfo.txt"))
  jobs <- expand.grid(setting_index = seq_len(nrow(settings)), replication = seq_len(replications))
  # Removing learner choices from the seed key gives each learner the same datasets,
  # nuisance split seed, and bootstrap seeds within every scientific setting.
  scientific <- settings[, setdiff(names(settings), c("setting", "calibration", "treated_nuisance")), drop = FALSE]
  keys <- apply(scientific, 1, paste, collapse = "|")
  seed_index <- vapply(keys, function(key) strtoi(substr(simulation_hash(key), 1L, 5L), 16L), integer(1))
  if (anyDuplicated(seed_index[!duplicated(keys)])) stop("Seed-key collision; choose a different recorded mapping")
  jobs$seed <- as.integer(seed + seed_index[jobs$setting_index] * 1000 + jobs$replication)
  jobs$B <- ifelse(jobs$replication <= bootstrap_reps, B, 0L)
  jobs$setting <- settings$setting[jobs$setting_index]
  utils::write.csv(jobs, file.path(out, "seed_ledger.csv"), row.names = FALSE)
  utils::write.csv(settings, file.path(out, "settings.csv"), row.names = FALSE)
  utils::write.csv(simulation_registry(settings, anomaly), file.path(out, "method_registry.csv"), row.names = FALSE)
  if (requireNamespace("grf", quietly = TRUE)) {
    writeLines(c("Actual installed causal_forest defaults; the runner overrides W.hat, sample.weights, seed, and num.threads=1:",
                  capture.output(dput(formals(grf::causal_forest)))), file.path(out, "causal_forest_defaults.txt"))
  }
  writeLines(capture.output(utils::sessionInfo()), file.path(out, "sessionInfo.txt"))
  work <- function(j) {
    task <- jobs[j, ]
    path <- file.path(checkpoints, sprintf("%s_rep%04d_B%d.rds", task$setting, task$replication, task$B))
    if (file.exists(path)) return(readRDS(path))
    setting <- as.list(settings[task$setting_index, ])
    methods <- simulation_methods(setting$scenario, anomaly = anomaly)
    result <- tryCatch(simulation_replication(setting, task$replication, task$seed, task$B, methods),
                       error = function(e) failed_replication(setting, task$replication, task$seed,
                                                               task$B, methods, conditionMessage(e)))
    tmp <- paste0(path, ".", Sys.getpid(), ".tmp")
    saveRDS(result, tmp)
    if (!file.rename(tmp, path)) stop("Could not finalize replication checkpoint: ", path)
    result
  }
  started <- Sys.time()
  message("Simulation run ", digest, ": ", nrow(jobs), " replication jobs; ", workers, " workers; output ", out)
  if (.Platform$OS.type != "windows" && workers > 1L) {
    results <- parallel::mclapply(seq_len(nrow(jobs)), work, mc.cores = workers,
                                  mc.preschedule = FALSE, mc.set.seed = FALSE)
  } else results <- lapply(seq_len(nrow(jobs)), work)
  failed <- vapply(results, function(x) !is.data.frame(x), logical(1))
  if (any(failed)) {
    errors <- lapply(results[failed], function(x) if (is.list(x) && !is.null(x$task))
      data.frame(x$task, error = x$job_error) else data.frame(error = as.character(x)))
    saveRDS(errors, file.path(out, "job_failures.rds"))
    warning(sum(failed), " entire replication jobs failed; see job_failures.rds")
  }
  # Even a worker crash receives one failed row per attempted method/target.
  for (j in which(failed)) {
    task <- jobs[j, ]
    setting <- as.list(settings[task$setting_index, ])
    results[[j]] <- failed_replication(setting, task$replication, task$seed, task$B,
                                       simulation_methods(setting$scenario, anomaly),
                                       "Parallel worker exited without a complete result")
  }
  columns <- names(results[[1L]])
  raw <- do.call(rbind, lapply(results, function(x) x[, columns]))
  summary <- if (nrow(raw)) simulation_summary(raw) else data.frame()
  utils::write.csv(raw, file.path(out, "replications.csv"), row.names = FALSE, na = "")
  utils::write.csv(summary, file.path(out, "performance.csv"), row.names = FALSE, na = "")
  for (s in scenarios) {
    utils::write.csv(summary[summary$scenario == s, , drop = FALSE],
                     file.path(out, paste0("scenario", s, ".csv")), row.names = FALSE, na = "")
  }
  timing <- data.frame(started = as.character(started), ended = as.character(Sys.time()),
                       seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
                       workers = workers, attempted_jobs = nrow(jobs), failed_jobs = sum(failed))
  utils::write.csv(timing, file.path(out, "timing.csv"), row.names = FALSE)
  list(raw = raw, summary = summary, directory = out, timing = timing, job_failures = results[failed])
}
