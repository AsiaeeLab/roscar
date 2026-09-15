# Publication style: /home/amir/.codex/skills/figure-style/SKILL.md.
# All plotted values come from completed replication records; unavailable
# metrics remain absent, with denominators retained in the companion table.
simulation_figure_theme <- function() {
  ggplot2::theme_minimal(base_size = 8, base_family = "sans") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major = ggplot2::element_line(colour = "#F2F3F4", linewidth = 0.3),
                   panel.background = ggplot2::element_rect(fill = "white", colour = NA),
                   plot.background = ggplot2::element_rect(fill = "white", colour = NA),
                   axis.text = ggplot2::element_text(size = 6.5),
                   axis.title = ggplot2::element_text(size = 7.5),
                   plot.title = ggplot2::element_text(size = 8, face = "bold"),
                   strip.text = ggplot2::element_text(size = 7),
                   plot.tag = ggplot2::element_text(face = "bold"))
}

write_simulation_figures <- function(summary, output_dir = "paper/simulations/figures") {
  if (!requireNamespace("ggplot2", quietly = TRUE) || !requireNamespace("patchwork", quietly = TRUE))
    stop("Plotting requires the suggested ggplot2 and patchwork packages")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- character()
  captions <- character()
  save_plate <- function(plate, stem) {
    p <- file.path(output_dir, paste0(stem, ".pdf"))
    ggplot2::ggsave(p, plate, width = 7.2, height = 6.5, units = "in", device = grDevices::cairo_pdf)
    ggplot2::ggsave(file.path(output_dir, paste0(stem, ".png")), plate,
                    width = 7.2, height = 6.5, units = "in", dpi = 180)
    p
  }
  for (s in intersect(c(1:4, 6), unique(summary$scenario))) {
    for (cal in unique(summary$calibration[summary$scenario == s])) {
      z <- summary[summary$scenario == s & summary$calibration == cal, ]
      label <- paste0("n = ", z$n_r)
      if (s == 3) label <- paste(z$variant, label, sep = "; ")
      if (s == 4) label <- paste0("rho = ", z$rho, "; ", label)
      z$facet <- label
      order <- c("none", "racer", "oracle", "uncalibrated", "A", "shared_only", "C", "D", "interaction_ols",
                  "rlearner", "causal_forest", "procova_interaction", "pooled")
      z$method <- factor(z$method, levels = intersect(order, unique(z$method)))
      method_labels <- c(none = "None", racer = "RACER", oracle = "Oracle",
        uncalibrated = "Uncalibrated", A = "Recipe A", shared_only = "SR-OSCAR",
        C = "Recipe C", D = "Recipe D", interaction_ols = "Trial OLS",
        rlearner = "R-learner", causal_forest = "Forest", procova_interaction = "PROCOVA", pooled = "Pooling")
      make_panel <- function(target, measure, se, title, ylab, reference = NULL) {
        d <- z[z$target == target, ]
        d$value <- as.numeric(d[[measure]])
        d$lo <- d$value - 1.96 * as.numeric(d[[se]])
        d$hi <- d$value + 1.96 * as.numeric(d[[se]])
        p <- ggplot2::ggplot(d, ggplot2::aes(x = method, y = value)) +
          ggplot2::geom_point(colour = "#1B4F72", size = 1.3, na.rm = TRUE) +
          ggplot2::geom_errorbar(ggplot2::aes(ymin = lo, ymax = hi), width = 0.15,
                                 colour = "#1B4F72", linewidth = 0.35, na.rm = TRUE) +
          ggplot2::facet_wrap(~facet, ncol = if (s %in% c(3, 4)) 2 else 1) +
          ggplot2::scale_x_discrete(labels = method_labels) +
          ggplot2::labs(title = title, x = NULL, y = ylab) + simulation_figure_theme() +
          ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 60, hjust = 1, size = 5.8))
        if (!is.null(reference)) p <- p + ggplot2::geom_hline(yintercept = reference,
                                     colour = "#7F8C8D", linetype = 2, linewidth = 0.35)
        p
      }
      panels <- list(make_panel("profile_zero", "bias", "bias_mcse", "Central-Profile Bias", "Bias", 0),
                     make_panel("integrated", "rmse", "rmse_mcse", "Integrated Error", "Integrated RMSE"),
                     make_panel("profile_zero", "coverage", "coverage_mcse", "Pointwise Coverage", "Coverage", 0.95),
                     make_panel("profile_zero", "width_ratio", "width_ratio_mcse", "Paired Interval Width", "Width ratio to RACER", 1))
      plate <- patchwork::wrap_plots(panels, ncol = 2) + patchwork::plot_annotation(tag_levels = "A")
      stem <- paste0(if (s == 6) "supplement" else "figure4", "_scenario", s, "_", cal)
      paths <- c(paths, save_plate(plate, stem))
      captions <- c(captions, paste0(stem, ": Scenario ", s, ", ", cal,
        " calibration. A: pointwise bias at the central profile. B: square root of mean integrated squared error across successful replications. C: coverage conditional on successful intervals. D: mean within-replication paired width ratio to RACER. Error bars are plus or minus 1.96 Monte Carlo standard errors. Dashed lines mark 0, 0.95, and 1 in A, C, and D. The CSV table records attempted and successful fits and the bootstrap subset; blank metrics are unavailable. Plates are separated by scenario and calibration to preserve readable type."))
    }
  }
  for (cal in unique(summary$calibration[summary$scenario == 5])) {
    z <- summary[summary$scenario == 5 & summary$calibration == cal & summary$method == "B", ]
    z$setting_label <- paste0("gamma = ", z$gamma, "\nkappa = ", z$kappa)
    z$n_label <- paste0("n = ", z$n_r)
    z$treated_nuisance <- factor(z$treated_nuisance, levels = c("linear", "sine"))
    panel <- function(target, measure, se, title, label, reference, annotate = FALSE) {
      d <- z[z$target == target, ]
      d$value <- as.numeric(d[[measure]])
      d$lo <- d$value - 1.96 * as.numeric(d[[se]])
      d$hi <- d$value + 1.96 * as.numeric(d[[se]])
      pos <- ggplot2::position_dodge(width = 0.45)
      p <- ggplot2::ggplot(d, ggplot2::aes(x = setting_label, y = value, colour = treated_nuisance)) +
        ggplot2::geom_hline(yintercept = reference, colour = "#7F8C8D", linetype = 2, linewidth = 0.35) +
        ggplot2::geom_point(position = pos, size = 1.5, na.rm = TRUE) +
        ggplot2::geom_errorbar(ggplot2::aes(ymin = lo, ymax = hi), position = pos,
                               width = 0.12, linewidth = 0.35, na.rm = TRUE) +
        ggplot2::facet_wrap(~n_label, ncol = 1) +
        ggplot2::scale_colour_manual(values = c(linear = "#1B4F72", sine = "#E67E22")) +
        ggplot2::labs(x = NULL, y = label, title = title, colour = "Treated nuisance") +
        simulation_figure_theme() + ggplot2::theme(legend.position = "bottom")
      # Width labels beside coverage points are explicitly requested in P014.
      if (annotate) {
        d$width_label <- ifelse(is.finite(d$width_ratio), sprintf("%.2f", d$width_ratio), "")
        p <- p + ggplot2::geom_text(data = d, ggplot2::aes(label = width_label),
                                    position = pos, vjust = -1, size = 2.2, na.rm = TRUE)
      }
      p
    }
    panels <- list(panel("integrated", "control_loss_reduction", "control_loss_reduction_mcse", "Control Prediction", "Control-loss reduction", 0),
                   panel("integrated", "variance_ratio", "variance_ratio_mcse", "Pseudo-Outcome Variance", "Variance ratio to RACER", 1),
                   panel("integrated", "integrated_rmse_ratio", "integrated_rmse_ratio_mcse", "Integrated CATE Error", "Integrated RMSE ratio", 1),
                   panel("profile_zero", "coverage", "coverage_mcse", "Coverage and Width", "Coverage", 0.95, TRUE))
    plate <- patchwork::wrap_plots(panels, ncol = 2, guides = "collect") + patchwork::plot_annotation(tag_levels = "A")
    stem <- paste0("figure5_one_arm_", cal)
    paths <- c(paths, save_plate(plate, stem))
    captions <- c(captions, paste0(stem, ": Recipe B versus its paired RACER comparator, ", cal,
      " calibration. A: paired control-loss reduction. B: paired pseudo-outcome variance ratio. C: ratio of integrated RMSEs across replications, with a paired delta-method MCSE. D: conditional-on-success central-profile coverage; labels beside points are mean paired interval-width ratios. Error bars show plus or minus 1.96 MCSEs; dashed lines mark 0, 1, 1, and 0.95. Colors identify the linear and sine-augmented treated-arm nuisances; rows identify trial sizes."))
  }
  writeLines(captions, file.path(output_dir, "CAPTIONS.txt"))
  paths
}
