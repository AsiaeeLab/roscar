# AUTHOR-RUN ONLY. Run from package root with GPS_CLEAN_DIR, GPS_OUTPUT_DIR,
# and GPS_DESIGN_RDS. Reads protected files only when gps_run() is called.
source("paper/applications/gps/audit.R")
source("paper/applications/gps/response_sensitivity.R")
source("paper/applications/star/construction.R") # outcome-independent spline helper

gps_design <- function(trial, external, eligible) {
  shared <- c("site", "sex", "race_ethnicity", "language", "insurance", "wflz_baseline")
  all <- rbind(trial[, shared], external[, shared], eligible[, shared])
  for (nm in setdiff(shared, "wflz_baseline")) all[[nm]] <- factor(all[[nm]])
  knots <- as.numeric(quantile(trial$wflz_baseline, c(.25, .5, .75)))
  basis <- model.matrix(~ site + sex + race_ethnicity + language + insurance, all)[, -1, drop = FALSE]
  spl <- application_rcs(all$wflz_baseline, knots)
  X <- as.data.frame(cbind(basis, baseline_linear = spl[, 1], baseline_nonlinear = spl[, 2]))
  names(X) <- make.names(names(X)); n <- nrow(trial); m <- nrow(external)
  list(trial = X[seq_len(n), , drop = FALSE], external = X[n + seq_len(m), , drop = FALSE],
    eligible = X[n + m + seq_len(nrow(eligible)), , drop = FALSE],
    basis = reformulate(names(X)), knots = knots)
}
gps_profiles <- function(d, X, min_arm_n = 5L) {
  idx <- integer(); metadata <- list()
  for (site in c("Duke", "UNC", "Vanderbilt")) {
    rows <- which(d$site == site)
    for (p in c(.1, .5, .9)) {
      target <- as.numeric(quantile(d$wflz_baseline[rows], p))
      j <- rows[which.min(abs(d$wflz_baseline[rows] - target))]
      # Require both arms among same-site participants around this
      # baseline profile, using the nearest one-third of site observations.
      pattern <- rows
      for (nm in c("sex", "race_ethnicity", "language", "insurance"))
        pattern <- pattern[as.character(d[[nm]][pattern]) == as.character(d[[nm]][j])]
      neighborhood <- pattern[order(abs(d$wflz_baseline[pattern] - d$wflz_baseline[j]))]
      neighborhood <- head(neighborhood, max(10L, ceiling(length(rows) / 3)))
      support <- table(factor(d$A[neighborhood], levels = c(-1, 1)))
      idx <- c(idx, j)
      metadata[[length(metadata) + 1L]] <- data.frame(site = site, percentile = p,
        n_control = as.integer(support[1]), n_treated = as.integer(support[2]),
        supported = all(support >= min_arm_n))
    }
  }
  # Do not export the representative child's baseline covariates or identifiers.
  list(index = idx, grid = X[idx, , drop = FALSE], metadata = do.call(rbind, metadata))
}
gps_aggregate_intervals <- function(boot, profiles, subgroup_indices) {
  ans <- boot$intervals[seq_len(nrow(profiles$grid)), , drop = FALSE]
  for (nm in names(ans)) if (is.numeric(ans[[nm]])) ans[[nm]][!profiles$metadata$supported] <- NA_real_
  profile_table <- cbind(profiles$metadata, ans)
  targets <- lapply(names(subgroup_indices), function(nm) {
    i <- subgroup_indices[[nm]]
    e <- mean(boot$intervals$estimate[i]); r <- mean(boot$intervals$trial_estimate[i])
    d <- rowMeans(boot$draws[, i, drop = FALSE]); rd <- rowMeans(boot$trial_draws[, i, drop = FALSE])
    ci <- quantile(d[is.finite(d)], c(.025, .975)); rci <- quantile(rd[is.finite(rd)], c(.025, .975))
    data.frame(target = nm, n = length(i), estimate = e, lower = ci[1], upper = ci[2],
      trial_estimate = r, trial_lower = rci[1], trial_upper = rci[2], width_ratio = diff(ci) / diff(rci))
  })
  list(profiles = profile_table, subgroups = do.call(rbind, targets))
}
gps_export_diagnostic <- function(diagnostic, prefix, output) {
  # Never serialize the fit/diagnostic objects: they may retain protected rows.
  if (!is.null(diagnostic$borrowing$table)) write.csv(diagnostic$borrowing$table,
    file.path(output, paste0(prefix, "_borrowing.csv")), row.names = FALSE)
  if (!is.null(diagnostic$variance)) write.csv(diagnostic$variance,
    file.path(output, paste0(prefix, "_variances.csv")), row.names = FALSE)
  if (!is.null(diagnostic$calibration_binned)) write.csv(diagnostic$calibration_binned[
    diagnostic$calibration_binned$n >= 5L &
      (diagnostic$calibration_binned$arm == -1 | diagnostic$calibration_binned$stage == "trial_only"), ],
    file.path(output, paste0(prefix, "_calibration.csv")), row.names = FALSE)
}
gps_run <- function(quick = FALSE, audit_only = FALSE, seed = 20260914L) {
  output <- gps_external_directory(Sys.getenv("GPS_OUTPUT_DIR", ""))
  clean <- Sys.getenv("GPS_CLEAN_DIR", "")
  if (!nzchar(clean)) stop("GPS_CLEAN_DIR must point to the protected cleaned inputs")
  config_path <- Sys.getenv("GPS_DESIGN_RDS", "")
  config <- if (nzchar(config_path)) readRDS(config_path) else NULL
  # No printing of data, model frames, fitted objects, or individual predictions.
  tr_raw <- readRDS(file.path(clean, "cate_rct_cross_sectional_data.rds"))
  ex_raw <- readRDS(file.path(clean, "cate_ehr_cross_sectional_data.rds"))
  tr <- if (is.null(config$control_labels)) gps_harmonize(tr_raw, "trial") else
    gps_harmonize(tr_raw, "trial", config$control_labels)
  ex <- gps_harmonize(ex_raw, "external")
  ta <- gps_filter_audit(tr); ea <- gps_filter_audit(ex)
  counts <- rbind(ta$audit, ea$audit)
  write.csv(counts, file.path(output, "P020_filter_counts.csv"), row.names = FALSE)
  endpoint <- gps_endpoint_audit(tr, ex, config$endpoint_audit)
  write.csv(endpoint, file.path(output, "P020_endpoint_audit.csv"), row.names = FALSE)
  if (audit_only) return(invisible(endpoint))
  if (is.null(config)) stop("Audit saved. Supply GPS_DESIGN_RDS after resolving unverified checks")
  if (anyDuplicated(tr$record_id) || anyDuplicated(ex$record_id)) stop("Duplicate children require resolution")
  linked_overlap <- config$endpoint_audit$cross_source_linkage$value
  if (!is.null(linked_overlap) && (!is.numeric(linked_overlap) || length(linked_overlap) != 1L ||
      !is.finite(linked_overlap) || linked_overlap != 0))
    stop("The documented cross-source linkage count must be zero before fitting")
  tr <- ta$complete; ex <- ea$complete; eligible <- ta$eligible
  gps_validate_design(config, eligible)
  if ("baseline_days_from_randomization" %in% names(tr) &&
      any(tr$baseline_days_from_randomization > 0, na.rm = TRUE))
    stop("Some earliest WFLz measurements follow randomization; resolve the baseline definition")
  actual <- c(trial = nrow(tr), external = nrow(ex))
  expected <- c(trial = config$expected_trial_n, external = config$expected_external_n)
  write.csv(data.frame(source = names(actual), actual = actual, expected = expected),
    file.path(output, "P020_reconstruction_counts.csv"), row.names = FALSE)
  if (isTRUE(config$strict_reconstruction) && any(actual != expected))
    stop("Complete-case counts differ from 330/8867; resolve and document before estimation")
  design <- gps_design(tr, ex, eligible)
  profiles <- gps_profiles(tr, design$trial, config$min_profile_arm_n)
  grid <- rbind(profiles$grid, design$trial); g <- nrow(profiles$grid)
  subgroup <- c(list(pooled = g + seq_len(nrow(tr))),
    lapply(split(seq_len(nrow(tr)), tr$site), function(i) g + i))
  stratum <- function(d) interaction(d[, config$strata_columns, drop = FALSE], drop = TRUE)
  p <- config$assignment_probability
  # Per-subject probabilities, when supplied, are indexed to baseline-eligible rows.
  p_tr <- rep(p, length.out = nrow(eligible))[match(tr$record_id, eligible$record_id)]
  trial <- roscar::trial_data(design$trial, tr$A, tr$Y,
    pi = ifelse(tr$A == 1, p_tr, 1 - p_tr), id = tr$record_id, strata = stratum(tr))
  external <- roscar::external_data(design$external, A = NULL, Y = ex$Y)
  B <- if (quick) 20L else 500L
  primary_fit <- NULL
  for (cal in c("intercept", "ridge", "lasso")) {
    learner <- switch(cal, intercept = roscar::learner_intercept(),
      ridge = roscar::learner_ridge(), lasso = roscar::learner_lasso())
    fit <- roscar::borrow_cate(trial, external, recipe = "B", arm_ext = -1,
      basis = design$basis, K = 5, seed = seed,
      learners = list(external = roscar::learner_lasso(), calibration = learner,
        trial = roscar::learner_lasso(), final = roscar::learner_ols()))
    boot <- roscar::bootstrap_cate(fit, B = B, grid = grid, seed = seed + 10000L, groups = tr$site)
    write.csv(data.frame(calibration = cal, attempted = boot$attempted,
      successful = boot$successful, B = B, seed = seed + 10000L),
      file.path(output, paste0("P022_", cal, "_bootstrap_status.csv")), row.names = FALSE)
    tables <- gps_aggregate_intervals(boot, profiles, subgroup)
    write.csv(tables$profiles, file.path(output, paste0("P022_", cal, "_profiles.csv")), row.names = FALSE)
    write.csv(tables$subgroups, file.path(output, paste0("P024_", cal, "_subgroups.csv")), row.names = FALSE)
    fit$bootstrap <- boot
    diagnostic <- roscar::diagnose(fit, B = B, seed = seed + 10000L, groups = tr$site)
    gps_export_diagnostic(diagnostic, paste0("P023_", cal), output)
    if (cal == "lasso") primary_fit <- fit
  }
  comparators <- roscar::compare_methods(trial, external, methods = "procova_interaction",
    grid = grid, basis = design$basis, B = B, seed = seed, subgroups = subgroup)
  comp <- comparators$procova_interaction
  write.csv(data.frame(method = "procova_interaction", status = comp$status,
    error = comp$error, interval_method = comp$interval_method),
    file.path(output, "comparator_status.csv"), row.names = FALSE)
  if (!is.null(comp$subgroups)) write.csv(comp$subgroups,
    file.path(output, "P024_prognostic_subgroups.csv"), row.names = FALSE)
  if (!is.null(comp$interval)) {
    # Profile summaries only. The entire comparator object must stay in memory.
    profile_interval <- comp$interval[seq_len(g), , drop = FALSE]
    numeric_columns <- vapply(profile_interval, is.numeric, logical(1))
    profile_interval[!profiles$metadata$supported, numeric_columns] <- NA_real_
    write.csv(cbind(profiles$metadata, profile_interval),
      file.path(output, "P025_prognostic_profiles.csv"), row.names = FALSE)
  }
  # Negative control: refit external outcome model AND trial calibration each time.
  permutation <- list()
  for (j in seq_len(if (quick) 2L else 30L)) {
    set.seed(seed + 30000L + j)
    perm <- roscar::external_data(design$external, A = NULL, Y = sample(ex$Y))
    fit <- roscar::borrow_cate(trial, perm, recipe = "B", arm_ext = -1,
      basis = design$basis, K = 5, seed = seed,
      learners = list(external = roscar::learner_lasso(), calibration = roscar::learner_lasso(),
        trial = roscar::learner_lasso(), final = roscar::learner_ols()))
    diag <- roscar::diagnose(fit, B = B, seed = seed + 20000L, groups = tr$site)
    tab <- diag$borrowing$table
    if (!is.null(tab)) { tab$permutation <- j; tab$seed <- seed + 30000L + j
      permutation[[j]] <- tab }
  }
  if (length(permutation)) write.csv(do.call(rbind, permutation),
    file.path(output, "P023_permuted_EHR_outcomes.csv"), row.names = FALSE)
  sensitivity <- if (!isTRUE(config$response_denominator_verified)) simpleError(
    "The original baseline-eligible response denominator has not been verified against upstream filters") else
    tryCatch(gps_response_bootstrap(eligible, ex, design$eligible,
    design$external, rbind(profiles$grid, design$eligible), stratum(eligible), p,
    B = B, seed = seed + 40000L), error = function(e) e)
  if (inherits(sensitivity, "error")) writeLines(conditionMessage(sensitivity),
    file.path(output, "response_sensitivity_unavailable.txt"))
  else {
    d <- sensitivity$draws[, seq_len(g), drop = FALSE]
    q <- apply(d, 2, quantile, c(.025, .975), na.rm = TRUE)
    table <- cbind(profiles$metadata, estimate = sensitivity$point$prediction[seq_len(g)],
      lower = q[1, ], upper = q[2, ])
    for (nm in c("estimate", "lower", "upper")) table[[nm]][!table$supported] <- NA_real_
    write.csv(table, file.path(output, "response_sensitivity_profiles.csv"), row.names = FALSE)
    write.csv(data.frame(attempted = sensitivity$attempted, successful = sensitivity$successful,
      eligible_n = sensitivity$point$eligible_n, observed_n = sensitivity$point$observed_n,
      min_response_probability = sensitivity$point$min_response_probability,
      max_response_weight = sensitivity$point$max_response_weight),
      file.path(output, "response_sensitivity_status.csv"), row.names = FALSE)
    targets <- c(list(pooled = seq_len(nrow(eligible))),
      split(seq_len(nrow(eligible)), eligible$site))
    target_table <- do.call(rbind, lapply(names(targets), function(nm) {
      i <- g + targets[[nm]]
      draws <- rowMeans(sensitivity$draws[, i, drop = FALSE])
      ci <- quantile(draws, c(.025, .975), na.rm = TRUE)
      data.frame(target = nm, n = length(i), estimate = mean(sensitivity$point$prediction[i]),
        lower = ci[1], upper = ci[2])
    }))
    write.csv(target_table, file.path(output, "response_sensitivity_subgroups.csv"), row.names = FALSE)
  }
  writeLines(c("Primary analysis: pooled complete-case children in Duke/UNC/Vanderbilt.",
    "Site estimates average over each site's observed covariate distribution; pooled estimate uses pooled distribution.",
    "Outcome: 24-month chronological-age WFLz, digital minus clinic-only.",
    "Conditional trial bootstrap holds EHR fixed; child is the resampling unit.",
    "Response weighting is one sensitivity analysis with baseline response-MAR and positivity assumptions.",
    paste("Bootstrap B:", B), paste("Base seed:", seed),
    paste("Known treatment probability range:", paste(range(p), collapse = ", ")),
    paste("Assignment evidence:", config$assignment_evidence),
    paste("Randomization strata:", paste(config$strata_columns, collapse = ", "))), file.path(output, "RESULTS_NOTES.txt"))
  invisible(TRUE)
}
if (sys.nframe() == 0L) gps_run(quick = "--quick" %in% commandArgs(TRUE),
                              audit_only = "--audit-only" %in% commandArgs(TRUE))
