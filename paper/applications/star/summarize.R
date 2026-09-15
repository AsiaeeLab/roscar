# Aggregate-only paper summaries from a completed public STAR run. No GPS paths
# or inputs are accessed. Profile support must already have been audited.
star_summarize <- function(run_dir = "paper/applications/star/results-full",
                          output_dir = file.path(run_dir, "summary"),
                          primary_path = "paper/applications/star/data/star_primary_extract.rds") {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  read_table <- function(name) {
    path <- file.path(run_dir, name)
    if (file.exists(path)) read.csv(path, stringsAsFactors = FALSE) else data.frame()
  }
  bind <- function(parts) {
    parts <- Filter(function(x) is.data.frame(x) && nrow(x) > 0, parts)
    if (!length(parts)) return(data.frame())
    fields <- unique(unlist(lapply(parts, names)))
    do.call(rbind, lapply(parts, function(x) {
      for (nm in setdiff(fields, names(x))) x[[nm]] <- NA
      x[, fields, drop = FALSE]
    }))
  }
  write_table <- function(x, name) {
    write.csv(x, file.path(output_dir, name), row.names = FALSE, na = "NA")
    invisible(x)
  }
  parse_name <- function(path) {
    tag <- regmatches(basename(path), regexec("^q([0-9]+)_rep([0-9]+)_", basename(path)))[[1]]
    if (length(tag) != 3L) stop("Unrecognized STAR run filename: ", basename(path))
    data.frame(q = as.integer(tag[2]) / 10, repetition = as.integer(tag[3]))
  }
  collect_csv <- function(suffix) {
    files <- list.files(run_dir, paste0("^q[0-9]+_rep[0-9]+_", suffix, "[.]csv$"), full.names = TRUE)
    bind(lapply(files, function(path) {
      x <- read.csv(path, stringsAsFactors = FALSE); meta <- parse_name(path)
      if (!nrow(x)) return(x)
      x$q <- meta$q; x$repetition <- meta$repetition; x
    }))
  }
  mean_finite <- function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
  median_finite <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
  q_finite <- function(x, p) if (any(is.finite(x))) unname(quantile(x[is.finite(x)], p)) else NA_real_
  group_map <- function(d, keys, fun) {
    if (!nrow(d)) return(data.frame())
    groups <- interaction(d[, keys, drop = FALSE], drop = TRUE, lex.order = TRUE)
    bind(lapply(split(d, groups), function(x) cbind(x[1, keys, drop = FALSE], fun(x))))
  }

  manifest <- read_table("job_manifest.csv"); job_status <- read_table("job_status.csv")
  fits <- read_table("fit_status.csv"); timing <- read_table("run_timing.csv")
  specification <- NULL
  if (nrow(timing)) {
    path <- file.path(run_dir, "checkpoints", timing$fingerprint[1], "SPECIFICATION.rds")
    if (file.exists(path)) specification <- readRDS(path)
  }
  known_quick <- !is.null(specification) && isTRUE(specification$quick)
  known_full <- !is.null(specification) && identical(specification$quick, FALSE)
  requested <- if (nrow(manifest)) table(manifest$q) else integer()
  jobs_complete <- nrow(manifest) > 0 && nrow(job_status) == nrow(manifest) &&
    all(manifest$job %in% job_status$job) && all(job_status$status == "completed")
  mode <- if (known_quick) "quick" else if (known_full) "full" else "unclassified"
  expected_repetitions <- if (known_quick) 1L else if (known_full) 30L else NA_integer_
  expected_B <- if (known_quick) 20L else if (known_full) 500L else NA_integer_
  full_design_complete <- known_full && jobs_complete && length(requested) == 5L &&
    all(requested == 30L) && nrow(fits) == 450L &&
    identical(sort(unique(as.integer(round(fits$q * 10)))), 1:5) &&
    identical(sort(unique(fits$calibration)), sort(c("intercept", "ridge", "lasso"))) &&
    nrow(unique(fits[, c("q", "repetition", "calibration")])) == 450L &&
    all(sort(unique(fits$repetition)) == seq_len(30L)) &&
    "bootstrap_attempted" %in% names(fits) && all(fits$bootstrap_attempted == 500L)
  run_status <- data.frame(mode = mode, jobs_complete = jobs_complete,
    full_design_complete = full_design_complete, requested_repetitions_per_q = expected_repetitions,
    requested_bootstrap_B = expected_B, jobs_requested = nrow(manifest),
    jobs_completed = sum(job_status$status == "completed"), recipe_fits_recorded = nrow(fits),
    recipe_fits_successful = sum(fits$status == "success"),
    recipe_fits_failed = sum(fits$status == "failed"))
  write_table(run_status, "RUN_STATUS.csv")
  # A merged run is required. Do not turn partial checkpoint files into a claim
  # that all 30 repetitions have completed while the durable job is running.
  if (!jobs_complete) {
    writeLines(c("# STAR run is incomplete", "",
      sprintf("Recorded completed jobs: %d of %d. No completed-run effect summary was produced.",
        run_status$jobs_completed, run_status$jobs_requested)), file.path(output_dir, "RESULTS_SUMMARY.md"))
    return(invisible(list(status = run_status, output_dir = output_dir)))
  }
  profiles <- read_table("profile_results.csv")
  if (!nrow(profiles) || !"supported" %in% names(profiles))
    stop("Run star_audit_profile_support() before producing the STAR paper summary")
  if (any(!profiles$supported & is.finite(profiles$estimate)))
    stop("Unsupported profile estimates must be masked before summary generation")

  counts <- collect_csv("counts"); selections <- collect_csv("selection")
  overlaps <- collect_csv("overlap")
  write_table(counts, "P015_source_counts.csv")
  write_table(selections, "P015_selection_denominators.csv")
  write_table(overlaps, "P015_classroom_overlap.csv")
  write_table(read_table("population_audit.csv"), "P015_population_audit.csv")
  write_table(read_table("covariate_missingness.csv"), "P015_covariate_missingness.csv")
  write_table(read_table("profile_support_status.csv"), "P017_profile_support.csv")

  diagnostic_files <- list.files(run_dir,
    "^q[0-9]+_rep[0-9]+_(intercept|ridge|lasso)_diagnostics[.]rds$", full.names = TRUE)
  diag_rows <- variance_rows <- bootstrap_rows <- list()
  for (path in diagnostic_files) {
    meta <- parse_name(path)
    meta$calibration <- sub("^q[0-9]+_rep[0-9]+_(.*)_diagnostics[.]rds$", "\\1", basename(path))
    d <- readRDS(path)
    if (nrow(d$borrowing$table)) diag_rows[[length(diag_rows) + 1L]] <- cbind(meta, d$borrowing$table,
      negative_transfer = d$negative_transfer)
    if (nrow(d$variance)) variance_rows[[length(variance_rows) + 1L]] <- cbind(meta, d$variance)
    b <- d$borrowing$bootstrap
    if (!is.null(b)) bootstrap_rows[[length(bootstrap_rows) + 1L]] <- cbind(meta,
      bootstrap_attempted = b$attempted, bootstrap_successful = b$successful)
  }
  diagnostic <- bind(diag_rows); variances <- bind(variance_rows); bootstrap <- bind(bootstrap_rows)
  write_table(diagnostic, "P017_borrowing_diagnostics.csv")
  write_table(variances, "P017_pseudo_outcome_variances.csv")
  write_table(bootstrap, "bootstrap_counts_by_fit.csv")
  pooled <- diagnostic[diagnostic$group == "pooled", , drop = FALSE]
  names(pooled)[names(pooled) == "estimate"] <- "borrowing_estimate"
  names(pooled)[names(pooled) == "lower_bound"] <- "borrowing_lower_bound"
  pooled <- pooled[, intersect(names(pooled), c("q", "repetition", "calibration", "borrowing_estimate",
    "borrowing_lower_bound", "control_estimate", "control_lower", "control_upper", "negative_transfer")), drop = FALSE]
  profile_table <- merge(profiles[profiles$repetition == 1L, ], pooled,
    by = c("q", "repetition", "calibration"), all.x = TRUE, sort = FALSE)
  write_table(profile_table, "P017_rep1_profiles.csv")

  subgroup_files <- list.files(run_dir,
    "^q[0-9]+_rep[0-9]+_(intercept|ridge|lasso)_subgroups[.]csv$", full.names = TRUE)
  subgroups <- bind(lapply(subgroup_files, function(path) {
    meta <- parse_name(path)
    meta$calibration <- sub("^q[0-9]+_rep[0-9]+_(.*)_subgroups[.]csv$", "\\1", basename(path))
    cbind(meta, read.csv(path, stringsAsFactors = FALSE))
  }))
  # IDs are used only in memory to obtain aggregate subgroup arm counts from the
  # licensed public primary extract. They are never exported in these tables.
  subgroup_counts <- list()
  if (file.exists(primary_path)) {
    primary <- readRDS(primary_path)
    membership <- list.files(run_dir, "^q[0-9]+_rep[0-9]+_source_memberships[.]csv$", full.names = TRUE)
    for (path in membership) {
      meta <- parse_name(path); m <- read.csv(path)
      i <- match(m$student[m$source == "trial"], primary$stdntid)
      if (anyNA(i)) stop("Public primary extract does not match a source-membership file")
      p <- primary[i, ]; subgroup <- paste0("free_lunch_", ifelse(is.na(p$g1freelunch), "Missing", p$g1freelunch))
      for (s in unique(subgroup)) subgroup_counts[[length(subgroup_counts) + 1L]] <- cbind(meta,
        data.frame(subgroup = s, n_control = sum(p$g1classtype[subgroup == s] == 2),
          n_treated = sum(p$g1classtype[subgroup == s] == 1)))
    }
  }
  sc <- bind(subgroup_counts)
  if (nrow(sc)) subgroups <- merge(subgroups, sc, by = c("q", "repetition", "subgroup"), all.x = TRUE, sort = FALSE)
  else { subgroups$n_control <- NA_integer_; subgroups$n_treated <- NA_integer_ }
  subgroups <- merge(subgroups, pooled, by = c("q", "repetition", "calibration"), all.x = TRUE, sort = FALSE)

  comparator_files <- list.files(run_dir, "^q[0-9]+_rep[0-9]+_comparators[.]rds$", full.names = TRUE)
  comparators <- comparator_subgroups <- list()
  for (path in comparator_files) {
    meta <- parse_name(path); methods <- readRDS(path)
    for (method in names(methods)) {
      m <- methods[[method]]
      comparators[[length(comparators) + 1L]] <- cbind(meta, data.frame(method = method,
        status = m$status, reason = m$error, interval_method = m$interval_method))
      if (!is.null(m$subgroups) && nrow(m$subgroups)) comparator_subgroups[[length(comparator_subgroups) + 1L]] <-
        cbind(meta, method = method, m$subgroups)
    }
  }
  comparators <- bind(comparators); cs <- bind(comparator_subgroups)
  procova <- comparators[comparators$method == "procova_interaction", c("q", "repetition", "status", "reason"), drop = FALSE]
  names(procova)[3:4] <- c("prognostic_status", "prognostic_reason")
  subgroups <- merge(subgroups, procova, by = c("q", "repetition"), all.x = TRUE, sort = FALSE)
  subgroups$prognostic_estimate <- subgroups$prognostic_lower <- subgroups$prognostic_upper <- NA_real_
  if (nrow(cs)) {
    for (j in seq_len(nrow(subgroups))) {
      z <- cs[cs$method == "procova_interaction" & cs$q == subgroups$q[j] &
        cs$repetition == subgroups$repetition[j] & cs$subgroup == subgroups$subgroup[j], , drop = FALSE]
      if (nrow(z) == 1L) {
        subgroups$prognostic_estimate[j] <- z$estimate
        subgroups$prognostic_lower[j] <- z$lower; subgroups$prognostic_upper[j] <- z$upper
      }
    }
  }
  no_subgroup <- subgroups$prognostic_status == "success" & !is.finite(subgroups$prognostic_estimate)
  no_subgroup[is.na(no_subgroup)] <- FALSE
  subgroups$prognostic_status[no_subgroup] <- "unavailable"
  subgroups$prognostic_reason[no_subgroup] <- "Subgroup intervals were not retained by this run"
  write_table(subgroups[subgroups$repetition == 1L, ], "P024_rep1_subgroups.csv")
  write_table(comparators, "comparator_status.csv")
  reasons <- comparators[comparators$status != "success", , drop = FALSE]
  write_table(reasons, "unavailable_comparisons.csv")

  fit_summary <- group_map(fits, c("q", "calibration"), function(x) data.frame(
    fits_attempted = nrow(x), fits_successful = sum(x$status == "success"), fits_failed = sum(x$status == "failed")))
  boot_summary <- group_map(bootstrap, c("q", "calibration"), function(x) data.frame(
    fits_with_bootstrap_audit = nrow(x), bootstrap_attempted = sum(x$bootstrap_attempted),
    bootstrap_successful = sum(x$bootstrap_successful)))
  fit_summary <- merge(fit_summary, boot_summary, by = c("q", "calibration"), all.x = TRUE)
  write_table(fit_summary, "fit_and_bootstrap_counts.csv")
  write_table(group_map(comparators, "method", function(x) data.frame(attempted = nrow(x),
    successful = sum(x$status == "success"), unavailable = sum(x$status == "unavailable"),
    failed = sum(x$status == "failed"))), "comparator_fit_counts.csv")

  # Each repetition contributes one value per metric. Profiles are not treated
  # as independent replications in the empirical quantile summaries.
  per_rep <- group_map(profiles, c("q", "repetition", "calibration"), function(x) data.frame(
    profile_width_ratio_median = median_finite(x$width_ratio[x$supported]),
    absolute_reference_disagreement_median = median_finite(abs(x$reference_disagreement[x$supported])),
    signed_reference_disagreement_mean = mean_finite(x$reference_disagreement[x$supported]),
    supported_profiles = sum(x$supported)))
  per_rep <- merge(per_rep, pooled, by = c("q", "repetition", "calibration"), all.x = TRUE)
  quantile_summary <- function(d, keys, fields) bind(lapply(fields, function(field)
    group_map(d, keys, function(x) data.frame(metric = field,
      repetitions_recorded = length(unique(x$repetition)), repetitions_finite = sum(is.finite(x[[field]])),
      median = median_finite(x[[field]]), p10 = q_finite(x[[field]], .1), p90 = q_finite(x[[field]], .9),
      full_30_repetitions = full_design_complete && length(unique(x$repetition)) == 30L))))
  across <- quantile_summary(per_rep, c("q", "calibration"),
    c("profile_width_ratio_median", "absolute_reference_disagreement_median", "signed_reference_disagreement_mean",
      "borrowing_estimate", "borrowing_lower_bound", "supported_profiles"))
  write_table(across, "P017_across_repetitions.csv")
  write_table(quantile_summary(subgroups, c("q", "calibration", "subgroup"),
    c("estimate", "trial_estimate", "width_ratio")), "P024_subgroup_across_repetitions.csv")

  number <- function(x, digits = 3) ifelse(is.finite(x), formatC(x, digits = digits, format = "f"), "unavailable")
  title <- if (known_quick) "Quick STAR software check" else if (full_design_complete) "Completed full STAR analysis" else "Completed STAR run with an incomplete full-design specification"
  lines <- c(paste0("# ", title), "",
    sprintf("Recorded %d completed source-construction jobs with %s repetition(s) per q and B=%s requested bootstrap resamples.",
      nrow(job_status), paste(unique(as.integer(requested)), collapse = "/"), ifelse(is.na(expected_B), "unclassified", expected_B)), "",
    if (known_quick) "These outputs check the software. The 30-repetition, B=500 analysis has not been completed in this run." else
      if (full_design_complete) "All 30 requested repetitions at each q are represented. Failed or unavailable methods remain explicit below." else
        "The files do not establish completion of the full 30-repetition, B=500 specification.", "",
    sprintf("Recipe fits succeeded in %d of %d recorded attempts. The available bootstrap audits report %d successful refits out of %d attempted refits.",
      sum(fits$status == "success"), nrow(fits), sum(bootstrap$bootstrap_successful), sum(bootstrap$bootstrap_attempted)), "",
    "## Conditional interval widths", "",
    "Each repetition contributes its median width ratio across supported profiles. The table gives the median and empirical 10th/90th percentiles across repetitions; these percentiles are not confidence intervals.", "",
    "| q | Calibration | Repetitions | Median width ratio | Empirical 10th–90th percentiles |",
    "|---:|---|---:|---:|---:|")
  w <- across[across$metric == "profile_width_ratio_median", ]
  for (j in seq_len(nrow(w))) lines <- c(lines, sprintf("| %.1f | %s | %d | %s | %s–%s |", w$q[j],
    w$calibration[j], w$repetitions_finite[j], number(w$median[j]), number(w$p10[j]), number(w$p90[j])))
  lines <- c(lines, "", "Ratios below one indicate narrower conditional intervals; ratios above one indicate wider intervals. Reference disagreement uses an estimated cross-fitted CATE from the full rural/inner-city cohort.", "",
    "## Source construction and limitations", "",
    sprintf("Across these constructions, %.1f%%–%.1f%% of trial students share a classroom proxy with external students. Resampling trial classrooms with external data fixed leaves this cross-source dependence unresolved.",
      100 * min(overlaps$trial_fraction_in_shared_classroom), 100 * max(overlaps$trial_fraction_in_shared_classroom)), "",
    "The implementation uses school-specific empirical assignment fractions because exact allocation probabilities are absent from the public extract. First-grade free-lunch groups are descriptive because pretreatment timing is unresolved. Teacher identity is used for dependence handling.", "",
    sprintf("There are %d unavailable or failed comparison-method fits. Their reasons are retained in [unavailable comparisons](unavailable_comparisons.csv); rank-deficient declared treatment interactions remain unavailable.", nrow(reasons)), "",
    "## Aggregate tables", "",
    "- [P015 source counts](P015_source_counts.csv), [selection denominators](P015_selection_denominators.csv), and [classroom overlap](P015_classroom_overlap.csv).",
    "- [P017 repetition-1 profile effects](P017_rep1_profiles.csv), [across-repetition summaries](P017_across_repetitions.csv), and [borrowing diagnostics](P017_borrowing_diagnostics.csv).",
    "- [P024 repetition-1 subgroup effects](P024_rep1_subgroups.csv) and [subgroup summaries](P024_subgroup_across_repetitions.csv).",
    "- [Fit/bootstrap counts](fit_and_bootstrap_counts.csv) and [comparator counts](comparator_fit_counts.csv).")
  writeLines(lines, file.path(output_dir, "RESULTS_SUMMARY.md"))
  invisible(list(status = run_status, output_dir = normalizePath(output_dir),
    summary = file.path(normalizePath(output_dir), "RESULTS_SUMMARY.md")))
}
if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  if (!length(args)) stop("Usage: Rscript paper/applications/star/summarize.R RUN_DIR [OUTPUT_DIR]")
  star_summarize(args[1], if (length(args) > 1L) args[2] else file.path(args[1], "summary"))
}
