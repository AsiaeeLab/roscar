# Focused mathematical checks for the reproduction summaries. These artificial
# values are unit-test inputs only and are never written as simulation results.
check_simulation_harness <- function() {
  setting <- as.list(simulation_settings(1, "intercept")[1L, ])
  raw <- do.call(rbind, lapply(1:4, function(i) {
    z <- failed_replication(setting, i, i, 20, c("A", "racer"), "unit-test input")
    z$status <- if (i < 4) "success" else "failed"
    z$truth <- 0.5
    z$error <- if (i < 4) c(-1, 1, -2)[i] else NA_real_
    z$estimate <- z$truth + z$error
    z$ise <- if (i < 4) c(1, 4, 9)[i] else NA_real_
    z$ise_racer <- if (i < 4) c(2, 3, 4)[i] else NA_real_
    z$ise_difference <- z$ise - z$ise_racer
    z$width <- if (i < 4) c(1, 4, 8)[i] else NA_real_
    z$width_ratio <- if (i < 4) c(0.5, 2, 2)[i] else NA_real_
    z$width_difference <- if (i < 4) c(-1, 2, 4)[i] else NA_real_
    z$lower <- z$estimate - z$width / 2
    z$upper <- z$estimate + z$width / 2
    z$covered <- if (i < 4) c(TRUE, FALSE, TRUE)[i] else NA
    z
  }))
  summary <- simulation_summary(raw)
  center <- summary[summary$method == "A" & summary$target == "profile_zero", ]
  integrated <- summary[summary$method == "A" & summary$target == "integrated", ]
  stopifnot(center$attempted == 4, center$successful == 3,
            center$interval_attempted == 4, center$interval_successful == 3,
            abs(center$bias + 2 / 3) < 1e-12,
            abs(center$coverage - 2 / 3) < 1e-12,
            abs(center$coverage_mcse - sqrt(2 / 27)) < 1e-12,
            abs(center$width_ratio - 1.5) < 1e-12,
            abs(integrated$rmse - sqrt(14 / 3)) < 1e-12,
            abs(integrated$rmse_mcse - stats::sd(c(1, 4, 9)) / sqrt(3) / (2 * sqrt(14 / 3))) < 1e-12)
  for (scenario in 1:6) {
    sim <- simulate_scenario(scenario, n_r = 50, n_o = 100, kappa = 1, seed = 291)
    pop <- population_contrasts(sim)
    truth <- drop(pop$weights %*% sim$truth_function(pop$anchors))
    stopifnot(max(abs(truth - c(sim$truth_average, sim$truth_subgroups))) < 1e-10)
  }
  invisible(TRUE)
}
