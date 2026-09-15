# Targeted integration check after adding transformed basis main effects to
# interaction OLS and pooled models. Run from the package root:
# Rscript paper/simulations/check-comparators.R

write_comparator_check <- function(raw, output_dir, root = ".") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  columns <- c("setting", "scenario", "n_r", "n_o", "calibration", "variant", "rho",
    "gamma", "kappa", "treated_nuisance", "replication", "seed", "test_seed", "B",
    "method", "status", "failure", "bootstrap_attempted", "bootstrap_successful")
  tab <- unique(raw[, columns])
  sources <- c(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE),
               file.path(root, "paper/simulations/harness.R"))
  manifest <- data.frame(file = sub(paste0("^", normalizePath(root), "/"), "", normalizePath(sources)),
    md5 = unname(tools::md5sum(sources)))
  tab$source_hash <- simulation_hash(manifest$md5)
  utils::write.csv(tab, file.path(output_dir, "comparator_fix_smoke.csv"), row.names = FALSE)
  utils::write.csv(manifest, file.path(output_dir, "source_manifest.csv"), row.names = FALSE)
  writeLines(capture.output(utils::sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
  writeLines(c("# Comparator correction integration check", "",
    "Seven prespecified cases cover all six scenarios and both Scenario 5 treated-arm nuisance specifications. Each supported comparator receives 20 bootstrap resamples. Pooled fitting is explicitly unavailable in the mismatched-covariate scenario.", "",
    "Run from the package root: `Rscript paper/simulations/check-comparators.R`.",
    "The CSV records the actual design, replication and fixed-test seeds, resample counts, and source checksum. source_manifest.csv lists the source files contributing to that checksum.", "",
    "The check verifies execution of the corrected interaction and pooled models. A separate noiseless nonlinear null-effect regression test verifies the mathematical reason for the correction; this small run provides no coverage or performance evidence."),
    file.path(output_dir, "README.md"))
  expected_unavailable <- tab$scenario == 4L & tab$method == "pooled"
  stopifnot(all(tab$status[expected_unavailable] == "unavailable"),
            all(tab$status[!expected_unavailable] == "success"),
            all(tab$bootstrap_successful[!expected_unavailable] == tab$B[!expected_unavailable]))
  invisible(tab)
}

run_comparator_check <- function(root = ".", output_dir = "paper/results/validated/comparator_fix",
                                 workers = 7L) {
  for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE))
    sys.source(f, envir = globalenv())
  sys.source(file.path(root, "paper/simulations/harness.R"), envir = globalenv())
  settings <- simulation_settings(1:6, "ridge")
  base <- settings[!duplicated(settings$scenario) & settings$scenario != 5L, ]
  special <- settings[settings$scenario == 5L & settings$n_r == 200L &
                        settings$gamma == 1 & settings$kappa == 1, ]
  settings <- rbind(base, special)
  one <- function(i) simulation_replication(as.list(settings[i, ]), 1L, 20260914L + i,
    B = 20L, methods = c("interaction_ols", "pooled"))
  results <- if (.Platform$OS.type == "unix" && workers > 1L)
    parallel::mclapply(seq_len(nrow(settings)), one, mc.cores = workers) else
    lapply(seq_len(nrow(settings)), one)
  raw <- do.call(rbind, results)
  write_comparator_check(raw, output_dir, root)
}

if (sys.nframe() == 0L) run_comparator_check()
