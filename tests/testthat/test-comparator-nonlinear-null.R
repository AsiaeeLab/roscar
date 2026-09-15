test_that("nonlinear prognosis cannot become a treatment interaction under the null", {
    # A treatment-by-sine term must have its sine main effect in the outcome
    # model. Otherwise it can absorb omitted prognosis and create a nonzero
    # conditional effect despite identically zero individual treatment effects.
    set.seed(2515)
    X <- cbind(X1 = runif(160, -pi, pi), X2 = rnorm(160))
    A <- ifelse(runif(160) < .5, 1, -1)
    trial <- trial_data(X, A, Y = sin(X[, "X1"]), pi = .5)
    E <- cbind(X1 = runif(320, -pi, pi), X2 = rnorm(320))
    EA <- ifelse(runif(320) < .4, 1, -1)
    # Pooled regression must also account for the external study main effect.
    ext <- external_data(E, EA, Y = .7 + sin(E[, "X1"]))
    grid <- cbind(X1 = c(-2.7, -1.2, 0, .8, 2.4), X2 = rep(0, 5))
    learners <- list(trial = learner_intercept(), external = learner_ols(),
                     final = learner_ols())
    fits <- compare_methods(trial, ext,
              methods = c("interaction_ols", "pooled"), grid = grid,
              basis = ~ sin(X1), learners = learners, K = 3, B = 2, seed = 71)
    for (method in names(fits)) {
        result <- fits[[method]]
        expect_identical(result$status, "success", info = method)
        expect_equal(as.numeric(result$prediction), rep(0, nrow(grid)),
                      tolerance = 1e-10, info = method)
        expect_equal(result$fit$bootstrap$successful, 2L, info = method)
        expect_equal(as.numeric(result$fit$bootstrap$draws), rep(0, 2L * nrow(grid)),
                      tolerance = 1e-10, info = method)
    }
})
