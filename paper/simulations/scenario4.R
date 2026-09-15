# Aims: Recoverable versus unrecoverable covariate mismatch.
# Data: simulate_scenario(4); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(4); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario4 <- function(...) run_simulations(scenarios = 4L, ...)
