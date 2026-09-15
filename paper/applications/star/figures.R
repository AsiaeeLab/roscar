# Aggregate publication panels; follows the figure-style skill.
application_theme <- function() ggplot2::theme_minimal(base_size = 8, base_family = "sans") +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(color = "#F2F3F4", linewidth = .3),
    plot.title = ggplot2::element_text(face = "bold", size = 8),
    axis.text = ggplot2::element_text(size = 7), legend.position = "bottom")
application_colors <- function() ggplot2::scale_color_manual(name = NULL, values = c(
  "Calibrated borrowing" = "#1B4F72", "Trial only" = "#E67E22",
  "Prognostic adjustment" = "#7F8C8D"))
star_figures <- function(output_dir = "paper/applications/star/results") {
  stopifnot(requireNamespace("ggplot2", quietly = TRUE), requireNamespace("patchwork", quietly = TRUE))
  source("paper/applications/star/profile_support.R")
  star_audit_profile_support(output_dir)
  d <- read.csv(file.path(output_dir, "profile_results.csv"))
  d <- d[d$calibration == "lasso", ]; one <- d[d$repetition == 1L, ]
  effect <- rbind(transform(one, method = "Calibrated borrowing"),
    transform(one, estimate = trial_estimate, lower = trial_lower, upper = trial_upper, method = "Trial only"))
  for (qi in 1:5) {
    p <- file.path(output_dir, sprintf("q%02d_rep01_comparators.rds", qi))
    if (!file.exists(p)) next
    c <- readRDS(p)$procova_interaction
    if (is.null(c$interval)) next
    rr <- one[one$q == qi / 10, ]; rr$estimate <- c$interval$estimate
    rr$lower <- c$interval$lower; rr$upper <- c$interval$upper
    rr$method <- "Prognostic adjustment"; effect <- rbind(effect, rr)
  }
  A <- ggplot2::ggplot(effect, ggplot2::aes(x = profile, y = estimate, ymin = lower,
      ymax = upper, color = method)) + ggplot2::geom_pointrange(na.rm = TRUE, position = ggplot2::position_dodge(width = .5), linewidth = .3) +
    ggplot2::facet_wrap(~ q, ncol = 1) + ggplot2::labs(x = "Supported baseline profile", y = "Small-minus-regular test score", title = "Profile Effects") +
    application_colors() + application_theme() + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1))
  # First summarize within repetition so repetitions, not profiles, are the units
  # of the empirical quantile display.
  rep_width <- aggregate(width_ratio ~ q + repetition, d, median)
  widths <- do.call(rbind, lapply(split(rep_width$width_ratio, rep_width$q),
    function(x) data.frame(mid = median(x), lo = quantile(x, .1), hi = quantile(x, .9))))
  widths$q <- as.numeric(rownames(widths))
  B <- ggplot2::ggplot(widths, ggplot2::aes(q, mid, ymin = lo, ymax = hi)) +
    ggplot2::geom_hline(yintercept = 1, color = "#7F8C8D", linewidth = .3) +
    ggplot2::geom_pointrange(na.rm = TRUE, color = "#1B4F72") +
    ggplot2::labs(x = "Trial fraction", y = "Median paired interval-width ratio", title = "Width Across Repetitions") + application_theme()
  files <- list.files(output_dir, "q[0-9]+_rep01_lasso_subgroups[.]rds$", full.names = TRUE)
  subgroup <- do.call(rbind, lapply(files, function(p) {
    z <- readRDS(p); z$q <- as.integer(sub(".*q([0-9]+)_.*", "\\1", basename(p))) / 10; z
  }))
  if (is.null(subgroup)) stop("Subgroup intervals have not completed")
  subeffects <- rbind(transform(subgroup, method = "Calibrated borrowing"),
    transform(subgroup, method = "Trial only", estimate = trial_estimate, lower = trial_lower, upper = trial_upper))
  C <- ggplot2::ggplot(subeffects, ggplot2::aes(subgroup, estimate, ymin = lower, ymax = upper, color = method)) +
    ggplot2::geom_pointrange(na.rm = TRUE, position = ggplot2::position_dodge(width = .5), linewidth = .3) +
    ggplot2::facet_wrap(~ q, ncol = 2) +
    ggplot2::scale_x_discrete(labels = c(free_lunch_1 = "Free", free_lunch_2 = "Not\nfree", free_lunch_Missing = "Missing")) +
    ggplot2::labs(x = "Free-lunch subgroup", y = "Average effect", title = "Subgroup Effects") +
    application_colors() + application_theme()
  figure <- patchwork::wrap_plots(A, patchwork::wrap_plots(B, C, ncol = 1), widths = c(1.6, 1), guides = "collect") +
    patchwork::plot_annotation(tag_levels = "A", theme = ggplot2::theme(plot.tag = ggplot2::element_text(face = "bold")))
  figure <- figure & ggplot2::theme(legend.position = "bottom", plot.tag = ggplot2::element_text(face = "bold"))
  ggplot2::ggsave(file.path(output_dir, "P018_STAR_effects.pdf"), figure, width = 7.2, height = 6.7)
  writeLines("Panel B displays medians and empirical 10th/90th quantiles of repetition-specific median paired profile width ratios. Panels A/C use repetition 1. Reference CATE is estimated, not truth. An unavailable prognostic comparison is omitted from the display; see comparator_status CSVs for rank/support or dependency reasons.",
    file.path(output_dir, "P018_figure_notes.txt"))
  invisible(figure)
}


application_diagnostic_figure <- function(calibration, variance, widths, borrowing, axis) {
  A <- ggplot2::ggplot(calibration, ggplot2::aes(predicted, observed, color = stage)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2, color = "#7F8C8D", linewidth = .3) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0, linewidth = .3) +
    ggplot2::geom_point(na.rm = TRUE, size = 1) + ggplot2::facet_wrap(~ arm) + application_theme() +
    ggplot2::scale_color_manual(values = c(external = "#7F8C8D", calibrated = "#1B4F72", trial_only = "#E67E22")) +
    ggplot2::labs(x = "Predicted outcome", y = "Observed mean", title = "Held-Out Calibration")
  variance$baseline <- factor(variance$baseline, levels = c("none", "trial_only", "external", "calibrated"))
  B <- ggplot2::ggplot(variance, ggplot2::aes(baseline, variance)) +
    ggplot2::geom_point(na.rm = TRUE, color = "#1B4F72", size = 2) +
    ggplot2::scale_y_log10() +
    ggplot2::scale_x_discrete(labels = c(none = "None", trial_only = "Trial only", external = "External", calibrated = "Calibrated")) +
    application_theme() +
    ggplot2::labs(x = "Augmentation baseline", y = "Pseudo-outcome variance (log scale)", title = "Baseline Comparison")
  C <- ggplot2::ggplot(widths, ggplot2::aes(calibration, width_ratio)) +
    ggplot2::geom_hline(yintercept = 1, color = "#7F8C8D", linewidth = .3) +
    ggplot2::geom_point(na.rm = TRUE, color = "#1B4F72", alpha = .6) + application_theme() +
    ggplot2::labs(x = "Calibration learner", y = "Paired interval-width ratio", title = "Calibration Sensitivity")
  borrowing$axis <- borrowing[[axis]]
  D <- ggplot2::ggplot(borrowing, ggplot2::aes(axis, estimate)) +
    ggplot2::geom_hline(yintercept = 0, color = "#7F8C8D", linewidth = .3) +
    ggplot2::geom_linerange(ggplot2::aes(ymin = lower_bound, ymax = estimate), color = "#1B4F72") +
    ggplot2::geom_point(na.rm = TRUE, color = "#1B4F72") + application_theme() +
    ggplot2::labs(x = if (axis == "q") "Trial fraction" else "Site / pooled target",
      y = "Weighted paired loss improvement", title = "Borrowing Diagnostic")
  patchwork::wrap_plots(A, B, C, D, ncol = 2) + patchwork::plot_annotation(tag_levels = "A") &
    ggplot2::theme(plot.tag = ggplot2::element_text(face = "bold"))
}
star_diagnostic_figures <- function(output_dir = "paper/applications/star/results") {
  paths <- list.files(output_dir, "q[0-9]+_rep01_lasso_diagnostics[.]rds$", full.names = TRUE)
  diagnoses <- lapply(paths, readRDS)
  qvalues <- as.integer(sub(".*q([0-9]+)_.*", "\\1", basename(paths))) / 10
  borrowing <- do.call(rbind, lapply(seq_along(diagnoses), function(i)
    transform(diagnoses[[i]]$borrowing$table, q = qvalues[i])))
  widths <- read.csv(file.path(output_dir, "profile_results.csv"))
  for (i in seq_along(diagnoses)) {
    diag <- diagnoses[[i]]
    figure <- application_diagnostic_figure(diag$calibration_binned, diag$variance,
      widths[widths$repetition == 1 & widths$q == qvalues[i], ], borrowing, "q")
    ggplot2::ggsave(file.path(output_dir, sprintf("P019_STAR_diagnostics_q%02d.pdf", qvalues[i] * 10)),
      figure, width = 7.2, height = 6)
  }
  invisible(TRUE)
}

if (sys.nframe() == 0L) { star_figures(); star_diagnostic_figures() }
