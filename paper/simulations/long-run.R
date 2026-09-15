#!/usr/bin/env Rscript
# Durable publication simulation driver. Run from the package root, for example:
# nohup Rscript paper/simulations/long-run.R --workers=64 --bootstrap-reps=100 \
#   --projected-original-hours=60 --output=/absolute/output/path > /absolute/run.log 2>&1 &
# Source snapshots and status survive the interactive authoring session.

run_publication_simulations <- function(root = ".", output_dir,
                                        workers = 64L, replications = 500L,
                                        bootstrap_reps = 200L, B = 200L,
                                        seed = 20260914L,
                                        projected_original_hours = NA_real_) {
  root <- normalizePath(root, mustWork = TRUE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  snapshot <- file.path(output_dir, "driver_source")
  status_path <- file.path(output_dir, "driver_status.dcf")
  started <- Sys.time()
  completed_dir <- ""
  update_status <- function(state, result_directory = "", error = "") {
    record <- data.frame(state = state, pid = Sys.getpid(), started = as.character(started),
                         updated = as.character(Sys.time()), workers = workers,
                         point_replications = replications, inference_replications = bootstrap_reps,
                         bootstrap_resamples = B, output = output_dir,
                         results = result_directory, error = error, stringsAsFactors = FALSE)
    tmp <- paste0(status_path, ".tmp")
    write.dcf(record, tmp)
    if (!file.rename(tmp, status_path)) stop("Could not update durable run status")
  }
  update_status("starting")
  tryCatch({
    if (bootstrap_reps < 200L && !(bootstrap_reps == 100L &&
        is.finite(projected_original_hours) && projected_original_hours > 48))
      stop("A reduced inference subset must be 100 and have a recorded original projection above 48 hours")
    if (!dir.exists(snapshot)) {
      for (folder in c("R", "paper/simulations")) {
        dir.create(file.path(snapshot, folder), recursive = TRUE, showWarnings = FALSE)
        files <- list.files(file.path(root, folder), pattern = "\\.(R|md)$", full.names = TRUE)
        if (!all(file.copy(files, file.path(snapshot, folder)))) stop("Source snapshot copy failed")
      }
      dir.create(file.path(snapshot, "paper/results"), recursive = TRUE, showWarnings = FALSE)
      result_sources <- list.files(file.path(root, "paper/results"), pattern = "\\.R$", full.names = TRUE)
      if (!all(file.copy(result_sources, file.path(snapshot, "paper/results"))))
        stop("The results-summary source could not be snapshotted")
      file.copy(file.path(root, c("DESCRIPTION", "NAMESPACE")), snapshot)
    }
    frozen <- new.env(parent = globalenv())
    for (f in list.files(file.path(snapshot, "R"), pattern = "\\.R$", full.names = TRUE))
      sys.source(f, envir = frozen)
    for (f in c("harness.R", "figures.R"))
      sys.source(file.path(snapshot, "paper/simulations", f), envir = frozen)
    sys.source(file.path(snapshot, "paper/results/summarize.R"), envir = frozen)
    # Sourced package code has no installed NAMESPACE registration. Register
    # these two methods explicitly so stats::predict dispatches to the snapshot.
    for (class in c("roscar_cate", "roscar_fit")) {
      registerS3method("predict", class, frozen[[paste0("predict.", class)]],
                        envir = asNamespace("stats"))
    }
    # Forked workers inherit these exact loaded dependency versions even if an
    # unrelated package installation occurs while the long run is in progress.
    for (package in c("glmnet", "grf", "ggplot2", "patchwork")) {
      if (!requireNamespace(package, quietly = TRUE)) stop("Install ", package, " before the publication run")
    }
    writeLines(capture.output(utils::sessionInfo()), file.path(output_dir, "driver_sessionInfo.txt"))
    manifest <- list.files(snapshot, full.names = TRUE, recursive = TRUE)
    utils::write.csv(data.frame(file = substring(manifest, nchar(snapshot) + 2L),
                                md5 = unname(tools::md5sum(manifest))),
                     file.path(output_dir, "driver_source_manifest.csv"), row.names = FALSE)
    writeLines(c("# Recorded compute plan", "",
      sprintf("Workers: %d; point replications per setting: %d; inference subset: %d; B: %d.",
               workers, replications, bootstrap_reps, B),
      if (is.finite(projected_original_hours))
        sprintf("Projection for the original 200-replication inference subset: %.2f hours, estimated from the completed quick run.", projected_original_hours)
      else "No original-design projection supplied; no inference-budget reduction is applied.",
      if (bootstrap_reps == 100L)
        "The inference subset is reduced to 100 under the coder prompt's explicit first reduction rule because the original projection exceeds 48 hours. The generators, all 87 settings, 500 point replications, B = 200, and comparator list are retained." else
        "The original inference subset is retained.", "",
      "A source snapshot is loaded before fitting. Completed per-replication checkpoints are reused on an identical restart. No running interactive session is required.",
      "Progress is visible by counting checkpoints in the hashed run directory. driver_status.dcf records the PID and whether fitting, figure generation, completion, or failure has been reached."),
      file.path(output_dir, "COMPUTE_PLAN.md"))
    update_status("running")
    result <- frozen$run_simulations(output_dir = file.path(output_dir, "runs"),
      workers = workers, replications = replications, bootstrap_reps = bootstrap_reps,
      B = B, seed = seed, root = snapshot)
    completed_dir <- result$directory
    update_status("writing_figures", result$directory)
    frozen$write_simulation_figures(result$summary, file.path(result$directory, "figures"))
    tab <- result$summary
    rows <- tab[tab$target == "integrated" & tab$method %in% c("A", "B", "C", "D", "racer"), ]
    header <- c("# Completed publication simulation run", "",
      sprintf("Completed at %s using %d workers. Elapsed time: %.2f hours.", Sys.time(), workers,
               as.numeric(difftime(Sys.time(), started, units = "hours"))),
      sprintf("Design: %d point replications per setting; intervals on up to the first %d replications with B=%d.",
               replications, bootstrap_reps, B), "",
      "The CSV performance table contains bias, integrated RMSE, conditional-on-success coverage, interval widths, paired width ratios, Monte Carlo standard errors, and attempted/successful fit counts. No unavailable result has been filled in.", "",
      "| Setting | Method | Successful / attempted | Integrated RMSE (MCSE) | Ratio to RACER (MCSE) |",
      "|:---|:---|---:|---:|---:|")
    lines <- vapply(seq_len(nrow(rows)), function(i) {
      z <- rows[i, ]
      sprintf("| %s | %s | %d / %d | %.5f (%.5f) | %.4f (%.4f) |",
               z$setting, z$method, z$successful, z$attempted, z$rmse, z$rmse_mcse,
               z$integrated_rmse_ratio, z$integrated_rmse_ratio_mcse)
    }, character(1))
    writeLines(c(header, lines, "", "Ratios below one indicate lower integrated error; ratios above one indicate higher error. Coverage and interval-width conclusions must be read from the separate profile rows in performance.csv.", "",
                  paste0("Results directory: `", result$directory, "`.")),
                file.path(output_dir, "RUN_SUMMARY.md"))
    saveRDS(result$directory, file.path(output_dir, "completed_results.rds"))
    frozen$write_results_summary(root = root, source_root = snapshot)
    update_status("complete", result$directory)
    invisible(result$directory)
  }, error = function(e) {
    update_status("failed", result_directory = completed_dir, error = conditionMessage(e))
    stop(e)
  })
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  value <- function(name, default) {
    found <- args[startsWith(args, paste0("--", name, "="))]
    if (length(found) > 1L) stop("Duplicate argument: ", name)
    if (!length(found)) return(default)
    sub(paste0("^--", name, "="), "", found)
  }
  run_publication_simulations(root = value("root", "."),
    output_dir = value("output", "paper/simulations/full"),
    workers = as.integer(value("workers", 64)),
    replications = as.integer(value("replications", 500)),
    bootstrap_reps = as.integer(value("bootstrap-reps", 200)),
    B = as.integer(value("B", 200)), seed = as.integer(value("seed", 20260914)),
    projected_original_hours = as.numeric(value("projected-original-hours", NA_real_)))
  # Finish from the already parsed entry expression. This also prevents a
  # repository update during a multi-day run from changing the script's tail
  # before Rscript attempts its next parse operation.
  quit(save = "no", status = 0L)
}
