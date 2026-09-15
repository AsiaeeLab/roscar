# Code-only protected analysis. Do not source the historical notebooks: they
# print individual rows and write caches within their project directories.
gps_external_directory <- function(path) {
  if (!nzchar(path)) stop("GPS_OUTPUT_DIR must name a directory outside every repository")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  p <- normalizePath(path, mustWork = TRUE)
  probe <- p
  repeat {
    if (file.exists(file.path(probe, ".git"))) stop("GPS output directory is inside a Git repository")
    up <- dirname(probe); if (identical(up, probe)) break
    probe <- up
  }
  p
}
gps_require <- function(d, fields) {
  missing <- setdiff(fields, names(d))
  if (length(missing)) stop("Required input fields absent: ", paste(missing, collapse = ", "))
}
gps_harmonize <- function(d, source, control_labels = c("Clinic Only", "Clinic Only Intervention", "Clinic-only", "Clinic Only Control")) {
  d <- as.data.frame(d)
  gps_require(d, c("record_id", "site", "sex", "race_ethnicity", "language", "insurance",
                   "wflz_baseline", "wflz_24m", if (source == "trial") "treatment"))
  d$site <- as.character(d$site); d$sex <- as.character(d$sex)
  d$sex[d$sex %in% c("M", "Male")] <- "Male"
  d$sex[d$sex %in% c("F", "Female")] <- "Female"
  d$race_ethnicity <- as.character(d$race_ethnicity)
  for (race in c("White", "Black", "Other"))
    d$race_ethnicity[d$race_ethnicity == paste("Non-Hispanic", race)] <- paste0(race, ", non-Hispanic")
  d$language <- as.character(d$language); d$insurance <- as.character(d$insurance)
  unknown <- is.na(d$insurance) | d$insurance == "" | grepl("Unavailable|Blank|None", d$insurance)
  d$insurance[unknown] <- "Unknown/Unavailable"
  d$A <- -1L
  if (source == "trial") {
    labels <- as.character(d$treatment)
    # Exact source label for the intervention; remaining labels must be explicitly
    # recognized to avoid silently turning misspellings into controls.
    allowed_control <- control_labels
    if (any(!labels %in% c(allowed_control, "Clinic + Digital Intervention")))
      stop("Unrecognized trial treatment label; verify coding against the data dictionary")
    d$A <- ifelse(labels == "Clinic + Digital Intervention", 1L, -1L)
  }
  d$Y <- as.numeric(d$wflz_24m); d$source <- source
  d
}
gps_filter_audit <- function(d) {
  audit <- list()
  record <- function(x, label) {
    tab <- as.data.frame(table(source = x$source, site = x$site, arm = x$A, useNA = "ifany"))
    tab$stage <- label; audit[[length(audit) + 1L]] <<- tab
  }
  record(d, "loaded_clean_file")
  d <- d[d$site %in% c("Duke", "UNC", "Vanderbilt"), ]; record(d, "three_EHR_centers")
  baseline <- c("site", "sex", "race_ethnicity", "language", "insurance", "wflz_baseline")
  d <- d[complete.cases(d[, baseline]) & is.finite(d$wflz_baseline), ]
  record(d, "complete_shared_baseline")
  d <- d[d$wflz_baseline >= -5 & d$wflz_baseline <= 5, ]; record(d, "baseline_WFLz_range")
  eligible <- d
  d <- d[is.finite(d$Y), ]; record(d, "observed_24m_endpoint")
  d <- d[d$Y >= -5 & d$Y <= 5, ]; record(d, "endpoint_WFLz_range")
  list(complete = d, eligible = eligible, audit = do.call(rbind, audit))
}
gps_endpoint_audit <- function(trial, ext, verification = NULL) {
  # Timing/visit/linkage data were not retained by the cross-sectional builders.
  timing <- "baseline_days_from_randomization" %in% names(trial)
  endpoint <- all(c("endpoint_min_age_months", "endpoint_max_age_months", "endpoint_rule") %in% names(trial))
  out <- data.frame(check = c("trial_duplicate_rows", "EHR_duplicate_rows", "baseline_after_randomization",
    "endpoint_window", "cross_source_linkage", "upstream_eligibility_counts", "randomization_design"),
    value = c(sum(duplicated(trial$record_id)), sum(duplicated(ext$record_id)),
      if (timing) sum(trial$baseline_days_from_randomization > 0, na.rm = TRUE) else NA,
      if (endpoint) sum(trial$endpoint_min_age_months < 23 | trial$endpoint_max_age_months > 25, na.rm = TRUE) else NA,
      NA, NA, NA),
    status = c("checked", "checked", if (timing) "checked" else "unverifiable_from_clean_file",
      if (endpoint) "checked" else "unverifiable_from_clean_file", "requires_linkage_audit",
      "requires_upstream_filter_log", "requires_verified_design_metadata"))
  # Matching source-local IDs does not establish overlap or its absence.
  if (!is.null(verification)) {
    for (nm in intersect(out$check, names(verification))) {
      j <- match(nm, out$check)
      if (isTRUE(verification[[nm]]$verified) && nzchar(verification[[nm]]$evidence))
        out$status[j] <- "verified_by_local_documentation"
      value <- verification[[nm]]$value
      if (is.numeric(value) && length(value) == 1L && is.finite(value)) out$value[j] <- value
    }
  }
  out
}
gps_validate_design <- function(config, trial) {
  fields <- c("assignment_probability", "assignment_evidence", "baseline_verified",
    "endpoint_verified", "source_overlap_verified", "strata_columns")
  if (!all(fields %in% names(config))) stop("Incomplete GPS_DESIGN_RDS; see local_config_example.R")
  if (!all(vapply(config[c("baseline_verified", "endpoint_verified", "source_overlap_verified")], isTRUE, logical(1))))
    stop("Baseline, endpoint and cross-source overlap audits must be verified before estimation")
  if (!is.character(config$assignment_evidence) || !nzchar(config$assignment_evidence))
    stop("Document the assignment-probability source")
  p <- config$assignment_probability
  if (!is.numeric(p) || !(length(p) == 1L || length(p) == nrow(trial)) ||
      any(!is.finite(p) | p <= 0 | p >= 1)) stop("Invalid known treatment probability")
  if (!length(config$strata_columns)) stop("Randomization strata must be documented")
  gps_require(trial, config$strata_columns)
  if (anyNA(trial[, config$strata_columns, drop = FALSE])) stop("Randomization strata contain missing values")
  invisible(TRUE)
}
