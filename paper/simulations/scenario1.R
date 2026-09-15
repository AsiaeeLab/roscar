# Aims: Useful external prognosis with a constant outcome shift.
# Data: simulate_scenario(1); exact settings in README.md and metadata.
# Estimands: three profiles, integrated CATE error, population and subgroup means.
# Methods: simulation_methods(1); audit A6 comparator list and calibration grid.
# Performance: bias, RMSE, coverage, width, paired ratios, failures, and MCSEs.
run_scenario1 <- function(...) run_simulations(scenarios = 1L, ...)
