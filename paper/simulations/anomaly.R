# Resolve the single-replicate demo finding before the large coverage runs.
# External and trial outcome nuisances use the same ridge dictionary across
# calibration choices; only discrepancy calibration changes.
run_anomaly_check <- function(output_dir = "paper/simulations/anomaly", workers = 8L,
                              replications = 200L, ...) {
  result <- run_simulations(output_dir = output_dir, scenarios = c(1, 6),
                             replications = replications, bootstrap_reps = 0L, B = 0L,
                             workers = workers, anomaly = TRUE, ...)
  table <- result$summary[result$summary$target == "integrated",
                          c("scenario", "n_r", "calibration", "method", "attempted", "successful",
                            "rmse", "rmse_mcse", "integrated_rmse_ratio", "integrated_rmse_ratio_mcse",
                            "ise_difference", "ise_difference_mcse", "ise_increase_frequency")]
  utils::write.csv(table, file.path(result$directory, "ANOMALY_TABLE.csv"), row.names = FALSE)
  body <- c("# Replicated anomaly check", "",
             "All results below are computed from independent replications of the prespecified generators.",
             "External and trial nuisance fits use ridge with main effects and sine/cosine of the first four predictors; discrepancy calibration varies. All fits use the same data and seeds within a setting. No generator or penalty grid is changed in response to performance.", "",
             "The RMSE ratio is sqrt(mean ISE for Recipe A / mean paired ISE for RACER). Its MCSE uses paired replication summaries. These runs contain no bootstrap intervals.", "")
  for (j in which(table$method == "A")) {
    x <- table[j, ]
    body <- c(body, sprintf("- Scenario %d, n = %d, %s calibration: %d/%d successful; integrated RMSE %.5f (MCSE %.5f); ratio to RACER %.4f (MCSE %.4f); mean paired ISE difference %.5f (MCSE %.5f).",
                            x$scenario, x$n_r, x$calibration, x$successful, x$attempted,
                            x$rmse, x$rmse_mcse, x$integrated_rmse_ratio, x$integrated_rmse_ratio_mcse,
                            x$ise_difference, x$ise_difference_mcse))
  }
  body <- c(body, "", "Ratios below one indicate lower error; ratios above one indicate higher error. Interpretation should account for the reported Monte Carlo uncertainty. These results do not establish interval coverage.")
  writeLines(body, file.path(result$directory, "ANOMALY_FINDINGS.md"))
  result
}
