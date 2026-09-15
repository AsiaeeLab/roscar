# AUTHOR-RUN ONLY. Reads aggregate outputs from GPS_OUTPUT_DIR; never raw inputs.
source("paper/applications/gps/audit.R")
source("paper/applications/star/figures.R")
gps_figures <- function(output = gps_external_directory(Sys.getenv("GPS_OUTPUT_DIR", ""))) {
  stopifnot(requireNamespace("ggplot2", quietly = TRUE), requireNamespace("patchwork", quietly = TRUE))
  d <- read.csv(file.path(output, "P022_lasso_profiles.csv"))
  effect <- rbind(transform(d, method = "Calibrated borrowing"),
    transform(d, estimate = trial_estimate, lower = trial_lower, upper = trial_upper, method = "Trial only"))
  prognostic_path <- file.path(output, "P025_prognostic_profiles.csv")
  if (file.exists(prognostic_path)) {
    p <- read.csv(prognostic_path); p$method <- "Prognostic adjustment"
    common <- intersect(names(effect), names(p))
    effect <- rbind(effect[, common], p[, common])
  }
  A <- ggplot2::ggplot(effect, ggplot2::aes(factor(percentile), estimate, ymin = lower,
      ymax = upper, color = method)) + ggplot2::geom_pointrange(na.rm = TRUE, position = ggplot2::position_dodge(width = .4), linewidth = .3) +
    ggplot2::facet_wrap(~ site) + application_colors() + application_theme() +
    ggplot2::labs(x = "Baseline WFLz percentile", y = "Digital-minus-clinic-only WFLz", title = "Profile Effects")
  B <- ggplot2::ggplot(d, ggplot2::aes(factor(percentile), width_ratio)) +
    ggplot2::geom_hline(yintercept = 1, color = "#7F8C8D", linewidth = .3) +
    ggplot2::geom_point(na.rm = TRUE, color = "#1B4F72") + ggplot2::facet_wrap(~ site) + application_theme() +
    ggplot2::labs(x = "Baseline WFLz percentile", y = "Paired interval-width ratio", title = "Conditional Precision")
  s <- read.csv(file.path(output, "P024_lasso_subgroups.csv"))
  sub <- rbind(transform(s, method = "Calibrated borrowing"),
    transform(s, estimate = trial_estimate, lower = trial_lower, upper = trial_upper, method = "Trial only"))
  C <- ggplot2::ggplot(sub, ggplot2::aes(target, estimate, ymin = lower, ymax = upper, color = method)) +
    ggplot2::geom_pointrange(na.rm = TRUE, position = ggplot2::position_dodge(width = .4), linewidth = .3) +
    application_colors() + application_theme() + ggplot2::labs(x = "Standardized target", y = "Average WFLz effect", title = "Average Effects")
  fig <- patchwork::wrap_plots(A, B, C, ncol = 1) + patchwork::plot_annotation(tag_levels = "A")
  ggplot2::ggsave(file.path(output, "P025_Greenlight_effects.pdf"), fig, width = 7.2, height = 6.7)
  invisible(fig)
}


gps_diagnostic_figure <- function(output = gps_external_directory(Sys.getenv("GPS_OUTPUT_DIR", ""))) {
  calibration <- read.csv(file.path(output, "P023_lasso_calibration.csv"))
  variance <- read.csv(file.path(output, "P023_lasso_variances.csv"))
  borrowing <- read.csv(file.path(output, "P023_lasso_borrowing.csv"))
  widths <- do.call(rbind, lapply(c("intercept", "ridge", "lasso"), function(cal) {
    z <- read.csv(file.path(output, paste0("P022_", cal, "_profiles.csv"))); z$calibration <- cal; z
  }))
  fig <- application_diagnostic_figure(calibration, variance, widths, borrowing, "group")
  ggplot2::ggsave(file.path(output, "P026_Greenlight_diagnostics.pdf"), fig, width = 7.2, height = 6)
  # A separate permutation display keeps the negative control distinct.
  path <- file.path(output, "P023_permuted_EHR_outcomes.csv")
  if (file.exists(path)) {
    perm <- read.csv(path)
    panel <- ggplot2::ggplot(perm, ggplot2::aes(group, estimate)) +
      ggplot2::geom_hline(yintercept = 0, color = "#7F8C8D", linewidth = .3) +
      ggplot2::geom_point(na.rm = TRUE, color = "#1B4F72", alpha = .6, position = ggplot2::position_jitter(width = .1, seed = 20260914)) +
      application_theme() + ggplot2::labs(x = "Site / pooled target", y = "Weighted paired loss improvement", title = "Permuted EHR Outcomes")
    ggplot2::ggsave(file.path(output, "P026_Greenlight_permutations.pdf"), panel, width = 3.5, height = 3)
  }
  invisible(fig)
}

if (sys.nframe() == 0L) { gps_figures(); gps_diagnostic_figure() }
