# Update only the marked result block after the actual B=500 teaching run.
update_teaching_vignette <- function(output_dir = "paper/teaching/output",
                                     path = "vignettes/getting-started.Rmd") {
  result <- readRDS(file.path(output_dir, "teaching.rds"))
  if (!identical(as.integer(result$B), 500L) || result$metadata$seed != 20260914L)
    stop("The vignette requires the prespecified seed and 500 actual bootstrap resamples")
  x <- result$profiles
  block <- c("The recorded 500-resample run gives the following pointwise 95% intervals.", "",
    "| X1 | Analytic truth | Recipe A (95% interval) | Trial-only (95% interval) | Width ratio |",
    "|---:|---:|:---|:---|---:|")
  for (i in seq_len(nrow(x))) {
    z <- x[i, ]
    block <- c(block, sprintf("| %g | %g | %.3f (%.3f, %.3f) | %.3f (%.3f, %.3f) | %.3f |",
      z$X1, z$truth, z$recipe_A, z$recipe_A_lower, z$recipe_A_upper,
      z$trial_only, z$trial_only_lower, z$trial_only_upper, z$width_ratio))
  }
  v <- result$variance$heldout_pseudo_outcome_variance
  block <- c(block, "", sprintf("The held-out pseudo-outcome variance is %.3f for Recipe A and %.3f for the paired trial-only fit. Width ratios above one indicate increased uncertainty; ratios below one indicate reduced uncertainty.", v[4], v[2]), "")
  old <- readLines(path)
  start <- match("<!-- BEGIN VERIFIED TEACHING OUTPUT -->", old)
  end <- match("<!-- END VERIFIED TEACHING OUTPUT -->", old)
  if (is.na(start) || is.na(end) || start >= end) stop("Missing or malformed vignette result markers")
  writeLines(c(old[seq_len(start)], block, old[seq.int(end, length(old))]), path)
  invisible(path)
}
