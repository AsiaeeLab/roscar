test_that("arbitrary fixed baselines preserve CATE within covariate strata", {
    # Monte Carlo test of the safety identity, with deliberately bad baselines
    # and unequal randomization. The acceptance limit is five analytic MC SEs.
    set.seed(20260914)
    group <- rep(1:3, each = 20000)
    x <- c(-1, 0, 2)[group]
    p <- c(.2, .5, .8)[group]
    mu0 <- 1 + x^2; mu1 <- mu0 + .5 + .8 * x
    sd0 <- .5 + .1 * group; sd1 <- 1 + .1 * group
    A <- ifelse(runif(length(x)) < p, 1, -1)
    Y <- ifelse(A == 1, mu1 + sd1 * rnorm(length(x)), mu0 + sd0 * rnorm(length(x)))
    trial <- trial_data(cbind(X1 = x), A, Y, pi = ifelse(A == 1, p, 1 - p), strata = group)
    for (baseline in list(rep(0, length(x)), 8 * cos(x), -5 + 2 * x)) {
        psi <- pseudo_outcome(trial, baseline)
        optimum <- personalized_baseline(mu1, mu0, p)
        variance <- sd1^2 / p + sd0^2 / (1 - p) + (baseline - optimum)^2 / (p * (1 - p))
        for (g in 1:3) {
            i <- group == g
            analytic <- unique(mu1[i] - mu0[i])
            mcse <- sqrt(unique(variance[i]) / sum(i))
            expect_lt(abs(mean(psi[i]) - analytic), 5 * mcse)
        }
    }
})

test_that("finite-support enumeration exactly verifies the variance-gap formula", {
    # Each potential outcome has two equally likely values, so enumerating the
    # four observed (A,Y) states gives exact moments without simulation error.
    mu1 <- 3.2; mu0 <- -.7; sd1 <- 1.3; sd0 <- .4
    for (p in c(.1, .3, .5, .8, .95)) {
        A <- c(1, 1, -1, -1)
        Y <- c(mu1 - sd1, mu1 + sd1, mu0 - sd0, mu0 + sd0)
        observed_pi <- ifelse(A == 1, p, 1 - p)
        probability <- observed_pi / 2
        trial <- trial_data(matrix(0, 4, 1), A, Y, pi = observed_pi)
        optimum <- personalized_baseline(mu1, mu0, p)
        expect_equal(optimum, (1 - p) * mu1 + p * mu0)
        for (baseline in c(-10, 0, optimum, 10)) {
            psi <- pseudo_outcome(trial, baseline)
            exact_mean <- sum(probability * psi)
            exact_variance <- sum(probability * (psi - exact_mean)^2)
            expected <- sd1^2 / p + sd0^2 / (1 - p) + (baseline - optimum)^2 / (p * (1 - p))
            expect_equal(exact_mean, mu1 - mu0, tolerance = 1e-12)
            expect_equal(exact_variance, expected, tolerance = 1e-11)
        }
    }
})

test_that("coding and zero-offset final regression give identical estimates", {
    set.seed(2001)
    X <- matrix(rnorm(240), 80, 3, dimnames = list(NULL, c("X1", "X2", "X3")))
    A <- rep(c(0, 1), 40); Y <- rnorm(80) + X[, 1] * A
    t01 <- trial_data(X, A, Y, pi = .5)
    tpm <- trial_data(X, 2 * A - 1, Y, pi = .5)
    expect_equal(pseudo_outcome(t01, X[, 2]), pseudo_outcome(tpm, X[, 2]))
    psi <- pseudo_outcome(t01, X[, 2])
    a <- fit_cate(t01, psi, basis = ~ X1 + X2)
    b <- fit_cate(tpm, psi, basis = ~ X1 + X2, offset = rep(0, 80))
    expect_equal(as.numeric(predict(a)), as.numeric(predict(b)))
    expect_equal(a$model$coefficients, b$model$coefficients)
})
