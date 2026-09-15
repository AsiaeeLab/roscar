# Aims: Nonprognostic or reversed external prognosis.
# Data: simulate_scenario(3); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(3); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario3 <- function(...) run_simulations(scenarios = 3L, ...)
