# Copy only named public aggregate artifacts. This function never visits GPS.
curate_public_results <- function(root = ".") {
  root <- normalizePath(root, mustWork = TRUE)
  destination <- file.path(root, "paper/results/validated")
  manifest <- list()
  copy_artifact <- function(source, relative, run, superseded = NULL) {
    if (!file.exists(source)) return(invisible(NULL))
    target <- file.path(destination, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(source, target, overwrite = TRUE)) stop("Could not copy ", source)
    if (!is.null(superseded) && nrow(superseded)) {
      table <- utils::read.csv(target)
      key <- paste(table$scenario, table$method)
      omit <- paste(superseded$scenario, superseded$method)
      utils::write.csv(table[!key %in% omit, ], target, row.names = FALSE, na = "")
    }
    manifest[[length(manifest) + 1L]] <<- data.frame(
      artifact = relative, run = run, md5 = unname(tools::md5sum(target)),
      bytes = file.info(target)$size, stringsAsFactors = FALSE)
    invisible(target)
  }
  latest <- function(parent, filename) {
    candidates <- list.files(file.path(root, parent), paste0("^", filename, "$"),
                             full.names = TRUE, recursive = TRUE)
    if (!length(candidates)) return(NULL)
    candidates[which.max(file.info(candidates)$mtime)]
  }
  for (mode in c("quick", "anomaly", "full")) {
    completed <- latest(file.path("paper/simulations", mode), "performance.csv")
    if (is.null(completed)) next
    directory <- dirname(completed)
    marker <- file.path(directory, "SUPERSEDED_METHODS.csv")
    superseded <- if (file.exists(marker)) utils::read.csv(marker) else NULL
    names <- c("performance.csv", paste0("scenario", 1:6, ".csv"),
      "settings.csv", "seed_ledger.csv", "method_registry.csv", "timing.csv",
      "ANOMALY_TABLE.csv", "sessionInfo.txt", "causal_forest_defaults.txt", "SUPERSEDED_METHODS.csv")
    for (name in names) copy_artifact(file.path(directory, name),
      file.path("simulations", mode, name), basename(directory),
      superseded = if (name %in% c("performance.csv", paste0("scenario", 1:6, ".csv"))) superseded else NULL)
    for (figure in list.files(file.path(directory, "figures"), "[.]pdf$", full.names = TRUE))
      copy_artifact(figure, file.path("simulations", mode, "figures", basename(figure)), basename(directory))
  }
  for (mode in c("quick", "full")) {
    directory <- file.path(root, "paper/applications/star", paste0("results-", mode))
    if (!file.exists(file.path(directory, "profile_results.csv"))) next
    # A full application is not a completed public artifact until its driver
    # has finished every job and post-fit support/figure generation.
    if (mode == "full" && !file.exists(file.path(directory, "FINISHED.txt"))) next
    names <- c("population_audit.csv", "covariate_missingness.csv", "effect_basis_knots.csv",
      "profile_results.csv", "fit_status.csv", "job_status.csv", "job_manifest.csv",
      "run_timing.csv", "profile_support_status.csv", "PROFILE_SUPPORT_AUDIT.txt", "P024_application_table.csv",
      "P017_repetition_summary.csv", "P018_STAR_effects.pdf", "RESULTS_NOTES.txt")
    for (name in names) copy_artifact(file.path(directory, name),
      file.path("star", mode, name), paste0("star-", mode))
    summary_names <- c("P015_classroom_overlap.csv", "P015_covariate_missingness.csv",
      "P015_population_audit.csv", "P015_selection_denominators.csv", "P015_source_counts.csv",
      "P017_across_repetitions.csv", "P017_borrowing_diagnostics.csv", "P017_profile_support.csv",
      "P017_pseudo_outcome_variances.csv", "P017_rep1_profiles.csv", "P024_rep1_subgroups.csv",
      "P024_subgroup_across_repetitions.csv", "RESULTS_SUMMARY.md", "RUN_STATUS.csv",
      "bootstrap_counts_by_fit.csv", "comparator_fit_counts.csv", "comparator_status.csv",
      "fit_and_bootstrap_counts.csv", "unavailable_comparisons.csv")
    for (name in summary_names) copy_artifact(file.path(directory, "summary", name),
      file.path("star", mode, "summary", name), paste0("star-", mode))
    names <- list.files(directory,
      "^(q[0-9]+_rep01_(counts|selection_audit|overlap|.*_subgroups|comparator_status)[.]csv|P019_STAR_diagnostics_q[0-9]+[.]pdf)$")
    for (name in names) copy_artifact(file.path(directory, name),
      file.path("star", mode, name), paste0("star-", mode))
  }
  primary <- file.path(root, "paper/applications/star/data")
  for (name in c("column_audit.csv", "reconstruction_audit.csv", "LICENSE-CC0.txt"))
    copy_artifact(file.path(primary, name), file.path("star", "reconstruction", name), "Dataverse-1.0")
  if (length(manifest)) {
    current <- do.call(rbind, manifest)
    previous <- file.path(destination, "manifest.csv")
    if (file.exists(previous)) {
      old <- utils::read.csv(previous)
      old <- old[!old$artifact %in% current$artifact & file.exists(file.path(destination, old$artifact)), ]
      if (nrow(old)) current <- rbind(current, old)
    }
    utils::write.csv(current, file.path(destination, "manifest.csv"), row.names = FALSE)
    writeLines(c("# Validated public output snapshots", "",
      "These are named aggregate tables, figures, seeds, and provenance records copied from completed public runs. The manifest records file checksums. No individual STAR records, unlicensed comparison extract, fitted-model checkpoints, or Greenlight outputs are included.", "",
      "Simulation quick mode uses 10 replications and B=20 and checks execution only. The anomaly analysis uses 200 point-performance replications without bootstrap intervals. Full simulations use the counts recorded in their seed ledger and performance table. STAR quick mode uses one source construction per trial fraction and B=20; full mode uses 30 and B=500.", "",
      "If a simulation directory contains SUPERSEDED_METHODS.csv, its listed scenario/method rows are omitted from the public copied tables. The marker gives the reason; the original local checkpoints are preserved. Replacement checks and full runs use the corrected implementation.", "",
      "Only directories actually present are completed snapshots. An absent full directory means final results remain pending. Performance tables retain failures and unavailable targets; coverage is conditional on successful intervals. Consult the application README for STAR dependence and allocation limitations."),
      file.path(destination, "README.md"))
  }
  invisible(destination)
}
