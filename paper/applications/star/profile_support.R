# Post-fit support audit. This changes reporting masks and supporting counts,
# not fitted models, resamples, pseudo-outcomes or regression coefficients.
star_audit_profile_support <- function(output_dir,
    primary_path = "paper/applications/star/data/star_primary_extract.rds", min_per_arm = 2L) {
  if (!file.exists(primary_path)) stop("Profile audit requires the verified primary STAR extract")
  env <- new.env(parent = globalenv())
  source("paper/applications/star/construction.R", local = env)
  p <- env$star_analysis_population(readRDS(primary_path)); d <- env$star_design(p)
  i <- which(p$geography == "rural_inner_city")
  target <- p[i, ]; td <- d
  td$X <- d$X[i, ]; td$dob <- d$dob[i]; td$missing <- d$missing[i]
  profiles <- env$star_profiles(target, td)
  source_rows <- i[profiles$rows]
  same_value <- function(x, y) ifelse(is.na(x), "Missing", as.character(x)) ==
    ifelse(is.na(y), "Missing", as.character(y))
  membership <- list.files(output_dir, "^q[0-9]+_rep[0-9]+_source_memberships[.]csv$", full.names = TRUE)
  collected <- list(); statuses <- list()
  for (file in membership) {
    prefix <- sub("_source_memberships[.]csv$", "", basename(file))
    source <- read.csv(file); tr <- p[match(source$student[source$source == "trial"], p$stdntid), ]
    counts <- t(vapply(source_rows, function(j) {
      take <- same_value(tr$gender, p$gender[j]) & same_value(tr$g1freelunch, p$g1freelunch[j]) &
        same_value(tr$race, p$race[j]) & !d$missing[match(tr$stdntid, p$stdntid)]
      as.integer(table(factor(tr$A[take], levels = c(-1, 1))))
    }, integer(2)))
    supported <- apply(counts >= min_per_arm, 1, base::all)
    for (cal in c("intercept", "ridge", "lasso")) {
      path <- file.path(output_dir, paste0(prefix, "_", cal, "_profiles.csv"))
      if (!file.exists(path)) next
      result <- read.csv(path)
      if (!identical(result$profile, profiles$metadata$profile)) stop("Profile order changed; do not relabel fitted predictions")
      if (!"full_cohort_n_control" %in% names(result)) {
        result$full_cohort_n_control <- result$n_control
        result$full_cohort_n_treated <- result$n_treated
      }
      result$n_control <- counts[, 1]; result$n_treated <- counts[, 2]
      result$supported <- supported
      fields <- intersect(names(result), c("estimate", "lower", "upper", "width", "trial_estimate",
        "trial_lower", "trial_upper", "trial_width", "width_ratio", "reference_disagreement"))
      result[!supported, fields] <- NA_real_
      write.csv(result, path, row.names = FALSE)
      collected[[length(collected) + 1L]] <- result
    }
    path <- file.path(output_dir, paste0(prefix, "_comparators.rds"))
    if (file.exists(path)) {
      cmp <- readRDS(path)
      for (nm in names(cmp)) {
        cmp[[nm]]$fit <- NULL
        if (!is.null(cmp[[nm]]$interval)) {
          cols <- vapply(cmp[[nm]]$interval, is.numeric, logical(1))
          cmp[[nm]]$interval[!supported, cols] <- NA_real_
        }
        if (length(cmp[[nm]]$prediction) == length(supported)) cmp[[nm]]$prediction[!supported] <- NA_real_
      }
      saveRDS(cmp, path)
    }
    statuses[[length(statuses) + 1L]] <- data.frame(run = prefix, profiles = length(supported),
      supported = sum(supported), unavailable = sum(!supported), min_per_arm = min_per_arm)
  }
  if (!length(membership)) stop("Missing per-job source memberships; cannot audit trial profile support")
  if (length(collected)) write.csv(do.call(rbind, collected), file.path(output_dir, "profile_results.csv"), row.names = FALSE)
  write.csv(do.call(rbind, statuses), file.path(output_dir, "profile_support_status.csv"), row.names = FALSE)
  writeLines(c("n_control/n_treated count each sampled trial's rows with the profile's sex, race and free-lunch pattern with an observed birth date.",
    "full_cohort_n_control/full_cohort_n_treated retain the original profile-source support counts.",
    paste("Profiles with fewer than", min_per_arm, "trial rows in either arm have unavailable estimates for every method."),
    paste("Audit source MD5:", unname(tools::md5sum("paper/applications/star/profile_support.R"))),
    paste("Primary extract MD5:", unname(tools::md5sum(primary_path)))),
    file.path(output_dir, "PROFILE_SUPPORT_AUDIT.txt"))
  invisible(statuses)
}
