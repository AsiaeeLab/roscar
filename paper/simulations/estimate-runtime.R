# Estimate the prespecified compute budget from completed runs at two B values.
# This is a workload projection, not a statistical performance result.
estimate_simulation_runtime <- function(quick_dir, pilot_dir, output_dir,
                                        workers = c(64L, 80L), replications = 500L,
                                        inference_reps = c(200L, 100L), B = 200L) {
  read_times <- function(directory) {
    ledger <- utils::read.csv(file.path(directory, "seed_ledger.csv"))
    paths <- list.files(file.path(directory, "checkpoints"), pattern = "\\.rds$", full.names = TRUE)
    if (length(paths) != nrow(ledger)) stop("Budget projection requires a completed run: ", directory)
    data <- do.call(rbind, lapply(paths, function(path) {
      z <- readRDS(path)
      z[1L, c("setting", "scenario", "replication", "B", "elapsed_seconds")]
    }))
    if (length(unique(data$B)) != 1L || any(!is.finite(data$elapsed_seconds)))
      stop("Runtime reference must use a single B and have finite completed timing records")
    list(B = unique(data$B), times = stats::aggregate(elapsed_seconds ~ setting + scenario, data, mean),
         directory = normalizePath(directory))
  }
  high <- read_times(quick_dir)
  low <- read_times(pilot_dir)
  if (high$B <= low$B || !setequal(high$times$setting, low$times$setting))
    stop("The quick and pilot runs must cover identical settings and have increasing B")
  inputs <- merge(high$times, low$times, by = c("setting", "scenario"), suffixes = c("_high", "_low"))
  inputs$seconds_per_resample <- pmax(0, (inputs$elapsed_seconds_high - inputs$elapsed_seconds_low) / (high$B - low$B))
  inputs$fixed_seconds <- pmax(0, inputs$elapsed_seconds_low - low$B * inputs$seconds_per_resample)
  design <- expand.grid(workers = workers, inference_reps = inference_reps)
  design$point_reps <- replications
  design$B <- B
  design$projected_hours <- vapply(seq_len(nrow(design)), function(i) {
    sum(replications * inputs$fixed_seconds + design$inference_reps[i] * B * inputs$seconds_per_resample) /
      (design$workers[i] * 3600)
  }, numeric(1))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(inputs, file.path(output_dir, "runtime_input_by_setting.csv"), row.names = FALSE)
  utils::write.csv(design, file.path(output_dir, "runtime_projection.csv"), row.names = FALSE)
  writeLines(c("# Measured workload projection", "",
    paste0("High-B reference: `", high$directory, "` (B = ", high$B, ")."),
    paste0("Low-B reference: `", low$directory, "` (B = ", low$B, ")."), "",
    "For each setting, fit the two-point timing model T(B) = F + b*B. The per-resample cost b is the difference in average completed job times divided by the difference in B; F is the remaining fixed cost. Negative fitted components are truncated at zero.", "",
    "Total projected worker-seconds sum 500*F + inference_reps*200*b across the 87 settings. Divide by workers*3600 to obtain hours. The CSV inputs and formula make this projection reproducible.", "",
    "This assumes approximately linear throughput when changing worker count. Machine load, cache behavior, and method refitting can change actual runtime. The pilot uses the final core; the earlier quick run additionally exercises the initial integration version. No point-performance or coverage outcome enters the compute decision."),
    file.path(output_dir, "RUNTIME_PROJECTION.md"))
  design
}
