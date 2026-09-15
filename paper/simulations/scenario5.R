# Aims: External controls with a prognosis-by-treated-complexity factorial.
# Data: simulate_scenario(5); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(5); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario5 <- function(...) run_simulations(scenarios = 5L, ...)
