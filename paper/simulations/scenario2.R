# Aims: Hidden external treatment confounding with useful prognosis.
# Data: simulate_scenario(2); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(2); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario2 <- function(...) run_simulations(scenarios = 2L, ...)
