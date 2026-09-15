# Run from package root: Rscript paper/applications/star/run.R [--quick]
source("paper/applications/star/download_preprocess.R")
source("paper/applications/star/construction.R")
.star_run_serial <- function(quick = FALSE, data_dir = "paper/applications/star/data",
                     output_dir = "paper/applications/star/results", seed = 20260914L,
                     q_values = seq(.1, .5, .1), rep_indices = NULL) {
  stopifnot(requireNamespace("roscar", quietly = TRUE))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(data_dir, "star_primary_extract.rds")
  if (!file.exists(path)) prepare_star(data_dir)
  raw <- readRDS(path); population <- star_analysis_population(raw)
  design <- star_design(population)
  write.csv(data.frame(stage = c("primary_students", "first_grade_aide_excluded",
    "small_or_regular", "complete_three_score_outcome"),
    n = c(nrow(raw), sum(raw$g1classtype == 3, na.rm = TRUE),
      sum(raw$g1classtype %in% c(1, 2)), nrow(population))),
    file.path(output_dir, "population_audit.csv"), row.names = FALSE)
  covariates <- c("gender", "race", "birthyear", "birthmonth", "birthday", "gkfreelunch", "g1freelunch", "g1tchid")
  write.csv(data.frame(covariate = covariates, missing_n = vapply(population[, covariates],
    function(x) sum(is.na(x)), integer(1))), file.path(output_dir, "covariate_missingness.csv"), row.names = FALSE)
  write.csv(data.frame(knot = 1:3, birth_date_numeric = design$knots),
    file.path(output_dir, "effect_basis_knots.csv"), row.names = FALSE)
  # Common outcome-free profiles chosen once from the rural/inner-city population.
  eligible <- which(population$geography == "rural_inner_city")
  target <- population[eligible, ]; target_design <- design
  target_design$X <- design$X[eligible, ]; target_design$dob <- design$dob[eligible]
  target_design$missing <- design$missing[eligible]
  profiles <- star_profiles(target, target_design)
  B <- if (quick) 20L else 500L; reps <- if (quick) 1L else 30L
  if (is.null(rep_indices)) rep_indices <- seq_len(reps)
  reference <- roscar::rct_only_cate(roscar::trial_data(design$X[eligible, ], target$A,
    target$Y, pi = ifelse(target$A == 1, target$p_plus, 1 - target$p_plus),
    id = target$classroom, strata = target$g1schid), basis = design$basis, K = 5,
    seed = seed, learners = list(trial = roscar::learner_lasso(), final = roscar::learner_ols()))
  reference_pred <- predict(reference, profiles$grid)
  summaries <- list(); diagnostics <- list(); statuses <- list()
  for (qi in as.integer(round(q_values * 10))) for (r in rep_indices) {
    q <- qi / 10; construction_seed <- seed + qi * 1000L + r
    cohort <- star_construct(population, q, construction_seed)
    prefix <- sprintf("q%02d_rep%02d", qi, r)
    for (nm in c("counts", "selection", "overlap"))
      write.csv(cohort[[nm]], file.path(output_dir, paste0(prefix, "_", nm, ".csv")), row.names = FALSE)
    write.csv(data.frame(student = cohort$full$stdntid, classroom = cohort$full$classroom,
      source = ifelse(cohort$full$rct, "trial", ifelse(cohort$full$external, "external", "not_selected"))),
      file.path(output_dir, paste0(prefix, "_source_memberships.csv")), row.names = FALSE)
    tr <- cohort$trial; ex <- cohort$ext
    trX <- design$X[match(tr$stdntid, population$stdntid), , drop = FALSE]
    exX <- design$X[match(ex$stdntid, population$stdntid), , drop = FALSE]
    basis_matrix <- model.matrix(design$basis, trX)
    support <- data.frame(term = colnames(basis_matrix),
      nonzero_control = colSums(abs(basis_matrix[tr$A == -1, , drop = FALSE]) > 1e-10),
      nonzero_treated = colSums(abs(basis_matrix[tr$A == 1, , drop = FALSE]) > 1e-10))
    write.csv(support, file.path(output_dir, paste0(prefix, "_effect_basis_support.csv")), row.names = FALSE)
    write.csv(data.frame(arm = c(-1, 1), columns = ncol(basis_matrix),
      rank = vapply(c(-1, 1), function(a) qr(basis_matrix[tr$A == a, , drop = FALSE])$rank, integer(1))),
      file.path(output_dir, paste0(prefix, "_effect_basis_rank.csv")), row.names = FALSE)
    trial <- roscar::trial_data(trX, tr$A, tr$Y,
      pi = ifelse(tr$A == 1, tr$p_plus, 1 - tr$p_plus), id = tr$classroom, strata = tr$g1schid)
    external <- roscar::external_data(exX, ex$A, ex$Y)
    grid <- rbind(profiles$grid, trX)
    subgroup <- lapply(split(seq_len(nrow(tr)), ifelse(is.na(tr$g1freelunch),
      "Missing", as.character(tr$g1freelunch))), function(i) nrow(profiles$grid) + i)
    names(subgroup) <- paste0("free_lunch_", names(subgroup))
    for (cal in c("intercept", "ridge", "lasso")) {
      result <- tryCatch({
        cal_learner <- switch(cal, intercept = roscar::learner_intercept(),
          ridge = roscar::learner_ridge(), lasso = roscar::learner_lasso())
        fit <- roscar::borrow_cate(trial, external, recipe = "A", basis = design$basis,
          learners = list(external = roscar::learner_lasso(), calibration = cal_learner,
            trial = roscar::learner_lasso(), final = roscar::learner_ols()),
          K = 5, B = 0, seed = construction_seed)
        boot <- roscar::bootstrap_cate(fit, B = B, grid = grid,
          subgroups = subgroup, seed = construction_seed + 50000L)
        interval <- boot$intervals[seq_len(nrow(profiles$grid)), , drop = FALSE]
        interval <- cbind(profiles$metadata, interval)
        interval$q <- q; interval$repetition <- r; interval$calibration <- cal
        interval$reference_disagreement <- interval$estimate - reference_pred
        write.csv(interval, file.path(output_dir, paste0(prefix, "_", cal, "_profiles.csv")), row.names = FALSE)
        summaries[[length(summaries) + 1L]] <- interval
        if (!is.null(boot$subgroups)) write.csv(boot$subgroups,
          file.path(output_dir, paste0(prefix, "_", cal, "_subgroups.csv")), row.names = FALSE)
        if (!is.null(boot$subgroups)) saveRDS(boot$subgroups,
          file.path(output_dir, paste0(prefix, "_", cal, "_subgroups.rds")))
        fit$bootstrap <- boot
        diagnostic <- roscar::diagnose(fit, B = B, seed = construction_seed + 50000L)
        diagnostic$borrowing$bootstrap <- boot[c("attempted", "successful", "failures", "seeds", "interval_method", "external_fixed")]
        saveRDS(diagnostic, file.path(output_dir, paste0(prefix, "_", cal, "_diagnostics.rds")))
        membership <- data.frame(student = tr$stdntid, classroom = tr$classroom,
          fold = fit$folds, source = "trial")
        write.csv(membership, file.path(output_dir, paste0(prefix, "_", cal, "_folds.csv")), row.names = FALSE)
        if (r == 1L) {
          grDevices::pdf(file.path(output_dir, paste0(prefix, "_", cal, "_dashboard.pdf")), width = 7.2, height = 6)
          tryCatch(plot(diagnostic), finally = grDevices::dev.off())
        }
        data.frame(q = q, repetition = r, calibration = cal, status = "success", error = "",
          bootstrap_attempted = boot$attempted, bootstrap_successful = boot$successful)
      }, error = function(e) data.frame(q = q, repetition = r, calibration = cal,
        status = "failed", error = conditionMessage(e), bootstrap_attempted = B, bootstrap_successful = 0L))
      statuses[[length(statuses) + 1L]] <- result
      write.csv(do.call(rbind, statuses), file.path(output_dir, "fit_status.csv"), row.names = FALSE)
    }
    # Prognostic adjustment and requested sensitivity methods use the same basis.
    compare <- roscar::compare_methods(trial, external,
      methods = c("procova_interaction", "rlearner", "causal_forest"),
      grid = profiles$grid, basis = design$basis, B = B, seed = construction_seed)
    for (nm in names(compare)) {
      if (is.character(compare[[nm]]$error) && !is.na(compare[[nm]]$error) &&
          grepl("design is rank deficient", compare[[nm]]$error, fixed = TRUE))
        compare[[nm]]$status <- "unavailable"
    }
    public_comparison <- lapply(compare, function(x) x[setdiff(names(x), "fit")])
    saveRDS(public_comparison, file.path(output_dir, paste0(prefix, "_comparators.rds")))
    write.csv(do.call(rbind, lapply(names(compare), function(nm) data.frame(
      method = nm, status = compare[[nm]]$status, error = compare[[nm]]$error,
      interval_method = compare[[nm]]$interval_method))),
      file.path(output_dir, paste0(prefix, "_comparator_status.csv")), row.names = FALSE)
  }
  if (length(summaries)) write.csv(do.call(rbind, summaries),
    file.path(output_dir, "profile_results.csv"), row.names = FALSE)
  writeLines(c("Primary provenance: Harvard Dataverse hdl:1902.1/10766 (CC0 1.0).",
    "Reference: cross-fitted trial-only CATE fitted to full rural/inner-city cohort; estimated, not known truth.",
    "School-specific full-cohort arm proportions are estimated assignment probabilities.",
    "Classroom resampling uses school:teacher as proxy; no separate classroom identifier in extract.",
    "External data stay fixed despite shared classrooms; conditional intervals omit uncertainty from cross-source dependence.",
    "First-grade free lunch is a descriptive subgroup; pretreatment timing was not established.",
    "A rank-deficient interaction comparator is unavailable: the declared treatment interactions lack arm-specific support. No effect terms are dropped; inspect effect_basis_support and effect_basis_rank.",
    "Missing birth dates use outcome-free median imputation plus a missingness indicator.",
    paste("Bootstrap B:", B), paste("Repetitions per q:", reps),
    "The first recorded repetition at each q is the prespecified figure repetition."),
    file.path(output_dir, "RESULTS_NOTES.txt"))
  invisible(statuses)
}


# Resume only an identical code/data/seed/bootstrap specification. Every q/rep
# writes its own directory; the parent alone merges public tables and figures.
star_run <- function(quick = FALSE, data_dir = "paper/applications/star/data",
                     output_dir = "paper/applications/star/results", seed = 20260914L,
                     workers = 1L) {
  stopifnot(length(workers) == 1L, is.finite(workers), workers >= 1L)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(file.path(data_dir, "star_primary_extract.rds"))) prepare_star(data_dir)
  data_dir <- normalizePath(data_dir); output_dir <- normalizePath(output_dir)
  code_files <- c(list.files("R", "[.]R$", full.names = TRUE),
    list.files("paper/applications/star", "[.]R$", full.names = TRUE))
  signature <- list(code = tools::md5sum(code_files),
    data = unname(tools::md5sum(file.path(data_dir, "star_primary_extract.rds"))),
    quick = quick, seed = seed, R = R.version.string,
    glmnet = as.character(utils::packageVersion("glmnet")),
    grf = if (requireNamespace("grf", quietly = TRUE)) as.character(utils::packageVersion("grf")) else "unavailable")
  tmp <- tempfile(); saveRDS(signature, tmp, version = 2)
  fingerprint <- unname(tools::md5sum(tmp)); unlink(tmp)
  checkpoint_dir <- file.path(output_dir, "checkpoints", fingerprint)
  dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(signature, file.path(checkpoint_dir, "SPECIFICATION.rds"))
  for (f in code_files) {
    archived <- file.path(checkpoint_dir, "source", f)
    dir.create(dirname(archived), recursive = TRUE, showWarnings = FALSE)
    if (!file.exists(archived)) file.copy(f, archived)
    if (unname(tools::md5sum(archived)) != unname(signature$code[f]))
      stop("A source file changed while the checkpoint snapshot was being created")
  }
  jobs <- expand.grid(q = seq(.1, .5, .1), repetition = seq_len(if (quick) 1L else 30L))
  jobs$job <- sprintf("q%02d_rep%02d", round(jobs$q * 10), jobs$repetition)
  write.csv(transform(jobs, seed = seed + round(q * 10) * 1000L + repetition),
    file.path(output_dir, "job_manifest.csv"), row.names = FALSE)
  execute <- function(j) {
    spec <- jobs[j, ]; folder <- file.path(checkpoint_dir, spec$job)
    dir.create(folder, recursive = TRUE, showWarnings = FALSE)
    checkpoint <- file.path(folder, "COMPLETED.rds")
    if (file.exists(checkpoint)) return(readRDS(checkpoint))
    start <- proc.time()[["elapsed"]]
    result <- tryCatch({
      statuses <- .star_run_serial(quick, data_dir, folder, seed,
        q_values = spec$q, rep_indices = spec$repetition)
      list(job = spec$job, directory = folder, status = "completed",
        error = NA_character_, statuses = do.call(rbind, statuses))
    }, error = function(e) list(job = spec$job, directory = folder, status = "failed",
      error = conditionMessage(e), statuses = NULL))
    result$elapsed_seconds <- proc.time()[["elapsed"]] - start
    saveRDS(result, checkpoint)
    result
  }
  started <- proc.time()[["elapsed"]]
  if (workers > 1L && .Platform$OS.type != "windows") {
    result <- parallel::mclapply(seq_len(nrow(jobs)), execute,
      mc.cores = min(as.integer(workers), nrow(jobs)), mc.preschedule = FALSE)
  } else result <- lapply(seq_len(nrow(jobs)), execute)
  if (any(vapply(result, inherits, logical(1), "try-error")))
    stop("A STAR worker failed outside the per-job error handler; inspect its checkpoint directory")
  status <- do.call(rbind, lapply(result, function(x) data.frame(job = x$job,
    status = x$status, error = x$error, elapsed_seconds = x$elapsed_seconds)))
  write.csv(status, file.path(output_dir, "job_status.csv"), row.names = FALSE)
  fits <- Filter(Negate(is.null), lapply(result, `[[`, "statuses"))
  if (length(fits)) write.csv(do.call(rbind, fits), file.path(output_dir, "fit_status.csv"), row.names = FALSE)
  rows <- list()
  for (x in result) {
    # Hard links avoid storing a second copy of the larger public diagnostics.
    files <- list.files(x$directory, full.names = TRUE)
    files <- files[grepl("^q[0-9]+_rep[0-9]+_", basename(files))]
    for (f in files) {
      target <- file.path(output_dir, basename(f))
      if (file.exists(target)) unlink(target)
      if (!file.link(f, target)) file.copy(f, target, overwrite = TRUE)
    }
    p <- file.path(x$directory, "profile_results.csv")
    if (file.exists(p)) rows[[length(rows) + 1L]] <- read.csv(p)
  }
  if (length(rows)) write.csv(do.call(rbind, rows), file.path(output_dir, "profile_results.csv"), row.names = FALSE)
  first <- result[[1]]$directory
  for (nm in c("population_audit.csv", "covariate_missingness.csv", "effect_basis_knots.csv", "RESULTS_NOTES.txt")) {
    p <- file.path(first, nm)
    if (file.exists(p)) file.copy(p, file.path(output_dir, nm), overwrite = TRUE)
  }
  write.csv(data.frame(fingerprint = fingerprint, workers = workers,
    jobs_attempted = nrow(jobs), jobs_completed = sum(status$status == "completed"),
    elapsed_seconds = proc.time()[["elapsed"]] - started),
    file.path(output_dir, "run_timing.csv"), row.names = FALSE)
  invisible(list(status = status, fingerprint = fingerprint, output_dir = output_dir))
}
if (sys.nframe() == 0L) {
  workers <- as.integer(Sys.getenv("ROSCAR_WORKERS", "1"))
  star_run("--quick" %in% commandArgs(TRUE), workers = workers)
}
