# Aims: Sparse high-dimensional prognosis and sparse covariate-dependent shift.
# Data: simulate_scenario(6); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(6); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario6 <- function(...) run_simulations(scenarios = 6L, ...)
