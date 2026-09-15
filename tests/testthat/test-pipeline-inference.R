small_example <- function(n = 100, seed = 73) {
  set.seed(seed)
  X <- matrix(rnorm(n * 3), n, 3, dimnames = list(NULL, paste0("X", 1:3)))
  A <- rep(c(-1, 1), length.out = n)
  Y <- 1 + X[, 1] + X[, 2] + A * (.5 + .25 * X[, 1]) + rnorm(n)
  E <- matrix(rnorm(400 * 3), 400, 3, dimnames = list(NULL, colnames(X)))
  EA <- rep(c(-1, 1), 200)
  EY <- 1.5 + E[, 1] + E[, 2] + EA * (.5 + .25 * E[, 1]) + rnorm(400)
  list(trial = trial_data(X, A, Y, pi = .5), ext = external_data(E, EA, EY),
       learners = list(external = learner_ols(), trial = learner_ols(),
                       calibration = learner_intercept()))
}

test_that("input treatment coding leaves all pipeline quantities unchanged", {
  d <- small_example()
  t01 <- trial_data(d$trial$X, (d$trial$A + 1) / 2, d$trial$Y, pi = .5)
  e01 <- external_data(d$ext$X, (d$ext$A + 1) / 2, d$ext$Y)
  a <- borrow_cate(d$trial, d$ext, learners = d$learners, basis = ~X1, seed = 4)
  b <- borrow_cate(t01, e01, learners = d$learners, basis = ~X1, seed = 4)
  expect_equal(a$heldout, b$heldout, tolerance = 1e-12)
  expect_equal(predict(a), predict(b), tolerance = 1e-12)
})

test_that("zero offset agrees with direct regression", {
  d <- small_example()
  psi <- pseudo_outcome(d$trial, 1)
  direct <- fit_cate(d$trial, psi, ~X1)
  offset <- fit_cate(d$trial, psi, ~X1, rep(0, length(psi)))
  expect_equal(predict(direct), predict(offset), tolerance = 1e-12)
  expect_equal(predict(direct, d$ext$X), predict(offset, d$ext$X, offset = rep(0, nrow(d$ext$X))))
})

test_that("each heldout arm prediction excludes its own outcomes", {
  d <- small_example()
  ff <- make_stratified_folds(d$trial$A, 5, seed = 6)
  a <- borrow_cate(d$trial, d$ext, learners = d$learners, basis = ~X1, seed = 6, folds = ff)
  changed <- d$trial; ix <- which(ff == ff[1]); changed$Y[ix] <- changed$Y[ix] + 1000
  b <- borrow_cate(changed, d$ext, learners = d$learners, basis = ~X1, seed = 6, folds = ff)
  cols <- c("mu_cal_plus", "mu_cal_minus", "mu_trial_plus", "mu_trial_minus", "baseline")
  expect_equal(a$heldout[ix, cols], b$heldout[ix, cols], tolerance = 1e-12)
})

test_that("one-arm calibration is symmetric and reuses the trial missing arm", {
  d <- small_example()
  a <- borrow_cate(d$trial, d$ext, "A", learners = d$learners, basis = ~X1, seed = 6)
  b <- borrow_cate(d$trial, d$ext, "B", learners = d$learners, basis = ~X1, seed = 6)
  expect_equal(a$heldout$mu_cal_minus, b$heldout$mu_cal_minus)
  expect_equal(b$heldout$mu_cal_plus, b$heldout$mu_trial_plus)
  expect_equal(b$heldout$q_plus, b$heldout$mu_trial_plus)
  c <- borrow_cate(d$trial, d$ext, "B", arm_ext = 1, learners = d$learners, basis = ~X1, seed = 6)
  expect_equal(c$heldout$mu_cal_plus, a$heldout$mu_cal_plus)
  expect_equal(c$heldout$mu_cal_minus, c$heldout$mu_trial_minus)
})

test_that("bootstrap is paired, deterministic, grouped, and refits", {
  d <- small_example()
  a <- borrow_cate(d$trial, d$ext, learners = d$learners, basis = ~X1, seed = 6)
  g <- d$trial$X[1:4, , drop = FALSE]
  b <- bootstrap_cate(a, 8, g, seed = 33, subgroups = list(all = 1:4),
                       groups = rep(c("s1", "s2"), 50))
  c <- bootstrap_cate(a, 8, g, seed = 33)
  expect_equal(b$draws, c$draws)
  expect_identical(dim(b$draws), c(8L, 4L))
  expect_equal(b$successful, 8)
  expect_equal(b$subgroup_draws[, 1], rowMeans(b$draws), ignore_attr = TRUE)
  expect_true(all(is.finite(b$intervals$width_ratio)))
  expect_true(all(vapply(b$fold_audit, function(z)
    all(vapply(split(z$fold, z$id), function(f) length(unique(f)) == 1, logical(1))), logical(1))))
  expect_true(any(vapply(b$fold_audit, function(z) anyDuplicated(z$id) > 0, logical(1))))
  expect_gt(sd(b$draws[, 1]), 0)
  dg <- diagnose(a, B = 8, seed = 33, groups = rep(c("s1", "s2"), 50))
  expect_equal(dg$borrowing$table$group, c("pooled", "s1", "s2"))
  expect_true(all(is.finite(dg$borrowing$table$lower_bound)))
})

test_that("logistic offset calibration returns bounded honest means", {
  d <- small_example(200)
  set.seed(94)
  d$trial$Y <- rbinom(200, 1, plogis(-.5 + .4 * d$trial$X[, 1]))
  f <- make_stratified_folds(d$trial$A, 5, seed = 2)
  q <- plogis(.5 + .4 * d$trial$X[, 1])
  cal <- calibrate_in_trial(d$trial, q, -1, learner_intercept(family = "binomial"),
                             scale = "link", folds = f)
  expect_true(all(cal$prediction > 0 & cal$prediction < 1))
  expect_lt(mean(cal$prediction), mean(q))
  expect_error(calibrate_in_trial(d$trial, q, -1, learner_intercept(),
                                  scale = "link", folds = f), "binomial")
})

test_that("sandwich agrees with a directly formed independent-row score", {
  d <- small_example()
  f <- rct_only_cate(d$trial, learners = d$learners, basis = ~X1, seed = 4)
  X <- cbind(1, d$trial$X[, 1])
  e <- f$final$psi - predict(f$final)
  bread <- solve(crossprod(X))
  vv <- bread %*% crossprod(X * e) %*% bread
  expect_equal(unname(as.matrix(vcov(f))), unname(vv), ignore_attr = TRUE)
})

test_that("comparators report genuine unavailable configurations and refit intervals", {
  d <- small_example()
  z <- compare_methods(d$trial, d$ext,
     c("none", "racer", "uncalibrated", "interaction_ols", "rlearner", "procova_interaction", "pooled"),
     grid = d$trial$X[1:2, , drop = FALSE], learners = d$learners, basis = ~X1, B = 3, seed = 7)
  expect_true(all(vapply(z, function(x) x$status == "success", logical(1))))
  expect_true(all(vapply(z, function(x) x$fit$bootstrap$successful == 3, logical(1))))
  expect_true(all(vapply(z, function(x) all(is.finite(x$interval$lower)), logical(1))))
  expect_error(compare_methods(d$trial, d$ext, "invented"), "Unknown")
})
