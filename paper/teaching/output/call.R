sim <- simulate_scenario("teaching", n_r = 200, n_o = 2000, seed = 20260914)
fit <- borrow_cate(sim$trial, sim$ext, recipe = "A",
  learners = list(external = learner_ols(), calibration = learner_intercept(),
                  trial = learner_ols(), final = learner_ols()),
  basis = ~X1, K = 5, B = 500, grid = sim$profiles, seed = 20260914)
