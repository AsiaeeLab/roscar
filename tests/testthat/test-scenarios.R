test_that("scenario seeds separate replications from the fixed test population", {
  set.seed(123)
  before <- .Random.seed
  a <- simulate_scenario(1, n_r = 80, n_o = 100, seed = 1)
  expect_identical(.Random.seed, before)
  b <- simulate_scenario("scenario1", n_r = 80, n_o = 100, seed = 2)
  expect_identical(a$test_X, b$test_X)
  expect_false(identical(a$trial$X, b$trial$X))
  again <- simulate_scenario(1, n_r = 80, n_o = 100, seed = 1)
  expect_identical(a$trial, again$trial)
  expect_identical(a$ext, again$ext)
  expect_equal(dim(a$test_X), c(2000L, 20L))
  expect_equal(a$truth_profiles, c(0, 0.5, 1))
  expect_true(all(a$trial$pi == 0.5))
})

test_that("all conditional effects and sparse supports match their declared generators", {
  for (scenario in 1:6) {
    s <- simulate_scenario(scenario, n_r = 80, n_o = 100, seed = 52, kappa = 1)
    X <- s$trial$X
    expected <- if (scenario == 4) 0.5 + 0.5 * X[, "Z1"] - 0.25 * X[, "U1"]
      else 0.5 + 0.5 * X[, "X1"] - 0.25 * X[, "X2"] +
        if (scenario == 5) sin(X[, "X3"]) else 0
    expect_equal(s$truth_trial, expected)
    expect_equal(s$truth_test, s$truth_function(s$test_X))
    if (scenario == 5) {
      expect_true(all(s$ext$A == -1))
      expect_true("sin(X3)" %in% attr(terms(s$basis), "term.labels"))
    }
    if (scenario == 6) {
      expect_equal(ncol(X), 100L)
      expect_equal(sum(s$metadata$prognosis_coefficients != 0), 10L)
      expect_equal(sum(s$metadata$source_shift_coefficients != 0), 2L)
      expect_equal(names(which(s$metadata$source_shift_coefficients != 0)), c("X99", "X100"))
    }
  }
})

test_that("mismatch observes the declared blocks and integrates latent prognosis", {
  for (rho in c(0, 0.8)) {
    s <- simulate_scenario(4, n_r = 12000, n_o = 12000, rho = rho, seed = 723)
    expect_identical(colnames(s$trial$X), c(paste0("Z", 1:4), paste0("U", 1:2)))
    expect_identical(colnames(s$ext$X), c(paste0("Z", 1:4), paste0("V", 1:6)))
    expect_equal(cor(s$ext$X[, "Z1"], s$ext$X[, "V1"]), rho, tolerance = 0.025)
    residual <- s$trial$Y - s$oracle_baseline(s$trial$X) - s$trial$A * s$truth_trial / 2
    expect_lt(abs(mean(residual)), 0.06)
    expect_equal(var(residual), 1 + 1.25 * (1 - rho^2), tolerance = 0.09)
  }
})

test_that("Scenario 5 changes only the treated-arm sine and specified control prognosis", {
  a <- simulate_scenario(5, n_r = 400, n_o = 400, seed = 83, gamma = 1, kappa = 0)
  b <- simulate_scenario(5, n_r = 400, n_o = 400, seed = 83, gamma = 1, kappa = 1)
  expect_identical(a$trial$X, b$trial$X)
  expect_identical(a$trial$A, b$trial$A)
  expect_equal(b$trial$Y - a$trial$Y, ifelse(a$trial$A == 1, sin(a$trial$X[, "X3"]), 0))
  expect_equal(a$ext$Y, b$ext$Y)
  c <- simulate_scenario(5, n_r = 400, n_o = 400, seed = 83, gamma = 0, kappa = 0)
  control_mean <- a$oracle_baseline(a$ext$X) - a$truth_function(a$ext$X) / 2
  expect_equal(a$ext$Y - c$ext$Y, control_mean)
})

test_that("teaching example has four independent predictors and its stated model", {
  s <- simulate_scenario("teaching", n_r = 12000, n_o = 12000, seed = 20260914)
  expect_equal(ncol(s$trial$X), 4)
  expect_equal(s$truth_trial, 0.5 + 0.5 * s$trial$X[, 1L])
  expect_lt(max(abs(cor(s$trial$X) - diag(4))), 0.035)
  r <- s$trial$Y - s$oracle_baseline(s$trial$X) - s$trial$A * s$truth_trial / 2
  e <- s$ext$Y - s$oracle_baseline(s$ext$X) - s$ext$A * s$truth_function(s$ext$X) / 2
  expect_lt(abs(mean(r)), 0.04)
  expect_equal(mean(e), 0.5, tolerance = 0.04)
})

test_that("scenario names and design parameters are validated", {
  expect_error(simulate_scenario("unknown"), "name")
  expect_error(simulate_scenario(4, rho = 0.2), "rho")
  expect_error(simulate_scenario(5, gamma = 2), "gamma")
  expect_error(simulate_scenario(1, n_r = 2.5), "sample sizes")
})
