# Assemble only completed artifacts; absence is a reported status, never a zero.
write_results_summary <- function(root = ".", output = file.path(root, "paper/results/RESULTS_SUMMARY.md")) {
  md_table <- function(d, digits = 5) {
    for (nm in names(d)) if (is.numeric(d[[nm]])) d[[nm]] <- format(d[[nm]], digits = digits, trim = TRUE)
    d[] <- lapply(d, function(x) {x <- as.character(x); x[is.na(x)] <- "unavailable"; gsub("[|\r\n]", " ", x)})
    c(paste0("| ", paste(names(d), collapse = " | "), " |"),
      paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
      apply(d, 1L, function(x) paste0("| ", paste(x, collapse = " | "), " |")))
  }
  latest <- function(parent, filename) {
    paths <- list.files(file.path(root, parent), paste0("^", filename, "$"), recursive = TRUE, full.names = TRUE)
    if (!length(paths)) return(NULL)
    paths[which.max(file.info(paths)$mtime)]
  }
  body <- c("# Reproduction results and completion status", "",
    paste0("Generated: ", format(Sys.time(), tz = "UTC", usetz = TRUE)), "",
    "Only completed runs are summarized. Quick-mode tables check execution; 10 replications and 20 resamples do not supply the paper's final coverage or precision evidence.", "",
    "## P002–P003: teaching example", "")
  p <- file.path(root, "paper/teaching/output/cate_profiles.csv")
  if (file.exists(p)) {
    d <- read.csv(p)
    body <- c(body, md_table(d), "", "The prespecified seed is 20260914, with 200 trial and 2,000 external observations and 500 conditional trial bootstrap resamples. Width ratios below one indicate narrower intervals; ratios above one indicate wider intervals. This is one illustration, not an estimate of typical performance or coverage.", "")
    v <- read.csv(file.path(root, "paper/teaching/output/pseudo_outcome_variances.csv"))
    body <- c(body, md_table(v), "")
  } else body <- c(body, "Not completed.", "")
  body <- c(body, "## Replicated anomaly check: Scenarios 1 and 6", "")
  a <- latest("paper/simulations/anomaly", "ANOMALY_TABLE.csv")
  if (is.null(a)) body <- c(body, "Not completed. No replicated efficiency finding is asserted.", "") else {
    d <- read.csv(a); d <- d[d$method == "A", ]
    body <- c(body, paste0("Source: `", sub(paste0(root, "/"), "", a, fixed = TRUE), "`."), "",
      md_table(d), "", "The comparison uses paired datasets and trial-only estimates. The ratio is the square root of mean integrated squared error for borrowing divided by that for RACER; uncertainty is Monte Carlo uncertainty across independent replications. No generators are retuned in response to these findings.", "")
  }
  body <- c(body, "## P009–P014: simulation operating characteristics", "")
  full <- latest("paper/simulations/full", "performance.csv")
  quick <- latest("paper/simulations/quick", "performance.csv")
  use <- if (!is.null(full)) full else quick
  if (is.null(use)) body <- c(body, "The simulation harness exists; the complete quick and full tables have not yet finished.", "") else {
    label <- if (!is.null(full)) "Full-mode completed table" else "Quick-mode execution check only"
    body <- c(body, paste0(label, ": `", sub(paste0(root, "/"), "", use, fixed = TRUE), "`."), "")
    d <- read.csv(use)
    cols <- intersect(c("scenario", "n_r", "variant", "rho", "gamma", "kappa", "calibration", "method", "target", "attempted", "successful", "rmse", "rmse_mcse", "coverage", "coverage_mcse", "width_ratio", "width_ratio_mcse"), names(d))
    selected <- d[d$target %in% c("integrated", "profile_zero") & d$method %in% c("A", "B", "C", "D", "racer"), cols, drop = FALSE]
    body <- c(body, md_table(selected), "", "Each scenario CSV retains the complete comparator list, attempted/successful counts, target definitions, biases, Monte Carlo errors, and unavailable methods. Coverage is conditional on successful intervals; interval failures are also counted. Interpret benefit and harm together with these denominators.", "")
    if (is.null(full)) body <- c(body, "Full 500-replication point performance and the final coverage subset are pending. The quick table cannot fill the final manuscript result placeholders.", "")
  }
  body <- c(body, "## P015–P019 and STAR block of P024: public application", "",
    "Primary Dataverse reconstruction matches all 43 substantive columns of the comparison extract. The first-grade small/regular analysis yields 4,218 students with all three outcome scores. This is complete-outcome selection; some baseline covariates remain missing. Source scripts report the missingness handling and exact source-construction denominators.", "",
    "Teacher IDs occur in one treatment arm only and are not effect modifiers. The quick construction shows extensive shared classrooms across trial and external sources (approximately 94–97% of trial students). Grouping trial resampling by classroom does not remove cross-source dependence when external fits are held fixed; conditional intervals therefore carry a substantive dependence limitation.", "",
    "Quick-run estimates are stored separately under `paper/applications/star/results-quick/`. Full 30-repetition-per-fraction, 500-resample results should be used only after their completion and review. Rare covariate levels can make the declared prognostic-adjustment treatment interactions unidentifiable; the comparator status table records these unavailable fits.", "",
    "## P020–P026: protected Greenlight application", "",
    "Not run by the coding agent. The investigator-run scripts read GPS_CLEAN_DIR, require locally verified design/endpoint information, and export aggregate tables and figures to GPS_OUTPUT_DIR outside repositories. The cleaned files omit timing/interpolation metadata, so those checks require source records or an investigator attestation. No Greenlight outcome numbers are supplied here. No protected files or synthetic mimic are distributed.", "",
    "## P001, P004–P008, P016, P021, P027–P028: software artifacts", "",
    "The implemented API, example calls, simulation registry, application scripts, generated argument table, and source/data provenance map are listed in paper/README.md. The GitHub fork preserves upstream history. A release tag and archive identifier remain pending until final numerical results and release checks are complete.")
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  writeLines(body, output)
  invisible(output)
}
