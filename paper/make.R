#!/usr/bin/env Rscript
# Run from anywhere: Rscript /path/to/roscar/paper/make.R --quick --workers=48
args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (!length(file_arg)) stop("Run this entrypoint with Rscript.")
root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
setwd(root)
quick <- "--quick" %in% args
value <- function(key, default) {
  a <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (length(a)) sub(paste0("^--", key, "="), "", tail(a, 1)) else default
}
workers <- as.integer(value("workers", "8"))
if (!is.finite(workers) || workers < 1) stop("workers must be a positive integer.")
# Load this exact checkout as a namespace, including application roscar:: calls.
if (!requireNamespace("pkgload", quietly = TRUE)) stop("Install pkgload for source-checkout reproduction.")
pkgload::load_all(root, quiet = TRUE)
source("paper/teaching/run.R")
source("paper/simulations/harness.R")
source("paper/simulations/anomaly.R")
source("paper/simulations/figures.R")
source("paper/results/arguments.R")
write_argument_table(root)
default_steps <- if (quick) "teaching,simulations,star,summary" else "teaching,anomaly,simulations,star,summary"
steps <- strsplit(value("steps", default_steps), ",", fixed = TRUE)[[1]]
unknown <- setdiff(steps, c("teaching", "anomaly", "simulations", "star", "gps", "summary"))
if (length(unknown)) stop("Unknown steps: ", paste(unknown, collapse = ", "))
if ("teaching" %in% steps) invisible(run_teaching(
  output_dir = if (quick) "paper/teaching/quick_output" else "paper/teaching/output",
  B = if (quick) 20L else 500L))
if ("anomaly" %in% steps) invisible(run_anomaly_check(workers = workers))
if ("simulations" %in% steps) {
  out <- run_simulations(quick = quick, workers = workers,
    bootstrap_reps = as.integer(value("bootstrap-reps", if (quick) "10" else "200")),
    output_dir = if (quick) "paper/simulations/quick" else "paper/simulations/full")
  write_simulation_figures(out$summary, file.path(out$directory, "figures"))
}
if ("star" %in% steps) {
  source("paper/applications/star/run.R")
  source("paper/applications/star/figures.R")
  star_output <- if (quick) "paper/applications/star/results-quick" else "paper/applications/star/results-full"
  invisible(star_run(quick = quick, workers = min(workers, 24L), output_dir = star_output))
  star_figures(star_output)
  star_diagnostic_figures(star_output)
}
if ("gps" %in% steps) stop("Greenlight is investigator-run only: see paper/applications/gps/README.md. This public entrypoint never reads protected data.")
if ("summary" %in% steps) {
  source("paper/results/summarize.R")
  write_results_summary(root)
}
message("Requested public reproduction stages completed. See paper/results/RESULTS_SUMMARY.md for actual run status.")
