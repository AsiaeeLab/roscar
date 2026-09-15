test_that("constructors preserve observed-arm probabilities and validate blocks", {
    X <- matrix(seq_len(24), 8, 3, dimnames = list(NULL, c("Z", "U", "W")))
    A <- c(1, 1, 1, 0, 1, 0, 0, 0)
    d <- trial_data(X, A, seq_len(8), strata = rep(1:2, each = 4), shared = 1, trial_only = 2:3)
    expect_equal(d$pi, c(.75, .75, .75, .25, .25, .75, .75, .75))
    expect_equal(d$p_plus, rep(c(.75, .25), each = 4))
    expect_identical(d, trial_data(X, 2 * A - 1, seq_len(8), strata = rep(1:2, each = 4), shared = "Z", trial_only = c("U", "W")))
    expect_null(external_data(X, Y = seq_len(8))$A)
    expect_error(trial_data(X, A, seq_len(8), pi = 1), "strictly")
    expect_error(trial_data(X, A, seq_len(8), shared = 1, trial_only = 1), "overlap")
    expect_error(trial_data(X, A, seq_len(8), weights = rep(-1, 8)), "positive")
    expect_error(external_data(data.frame(f = factor(c("a", "b"))), Y = 1:2), "numeric")
    bad <- X; bad[1, 1] <- NA_real_
    expect_error(external_data(bad, Y = seq_len(8)), "finite")
})

test_that("stratified folds group repeated copies and restore RNG state", {
    id <- rep(seq_len(80), each = 2)
    A <- rep(rep(c(-1, 1), each = 20), 2)[id]
    strata <- rep(c("s1", "s2"), each = 40)[id]
    set.seed(72); before <- .Random.seed
    folds <- make_stratified_folds(A, 5, strata, id, seed = 9)
    expect_identical(.Random.seed, before)
    expect_true(all(vapply(split(folds, id), function(x) length(unique(x)) == 1L, logical(1))))
    expect_equal(as.numeric(table(folds, A, strata)), rep(8, 20))
    expect_identical(folds, make_stratified_folds(A, 5, strata, id, seed = 9))
    bad <- strata; bad[1] <- "other"
    expect_error(make_stratified_folds(A, 5, bad, id), "cross design strata")
})

test_that("Gaussian learners return corrections without adding offsets", {
    set.seed(101)
    X <- matrix(rnorm(360), 120, 3, dimnames = list(NULL, c("x", "z", "v")))
    off <- 4 + X[, 2]^2
    residual <- 1 + 2 * X[, 1] + rnorm(120, sd = .2)
    for (l in list(learner_ols(), learner_intercept(), learner_lasso(seed = 2), learner_ridge(seed = 2))) {
        a <- l$fit(X, residual + off, offset = off)
        b <- l$fit(X, residual)
        expect_equal(l$predict(a, X), l$predict(b, X), tolerance = 1e-10)
        expect_length(l$predict(a, X[1, , drop = FALSE]), 1L)
    }
    l <- learner_ols(); empty <- X[, FALSE, drop = FALSE]
    expect_equal(l$predict(l$fit(empty, residual), empty), rep(mean(residual), 120))
})

test_that("penalty tuning groups all copies of each bootstrap unit", {
    set.seed(102)
    id <- rep(seq_len(50), each = 2)
    X0 <- matrix(rnorm(150), 50, 3)
    X <- X0[id, , drop = FALSE]; Y <- (X0[, 1] + rnorm(50))[id]
    for (l in list(learner_lasso(seed = 9), learner_ridge(seed = 9))) {
        fit <- l$fit(X, Y, id = id)
        expect_true(all(vapply(split(fit$foldid, id), function(x) length(unique(x)) == 1L, logical(1))))
        expect_true(fit$lambda %in% l$lambda)
    }
})

test_that("logistic offsets are on the link scale and absent at prediction", {
    set.seed(103)
    X <- matrix(rnorm(600), 300, 2, dimnames = list(NULL, c("x", "z")))
    off <- 1.5 + .3 * X[, 2]
    Y <- rbinom(300, 1, plogis(off - .7 + .4 * X[, 1]))
    l <- learner_ols(family = "binomial")
    fit <- l$fit(X, Y, offset = off)
    ref <- glm(Y ~ X + offset(off), family = binomial())
    expect_equal(l$predict(fit, X) + off, as.numeric(predict(ref, type = "link")), tolerance = 1e-8)
    ridge <- learner_ridge(lambda = .1, family = "binomial", seed = 9)
    rm <- ridge$fit(X, Y, offset = off)
    expect_equal(ridge$predict(rm, X), as.numeric(predict(rm$model, newx = X, newoffset = rep(0, 300), s = rm$lambda, type = "link")))
})

test_that("optional regression wrappers preserve the offset contract", {
    set.seed(104)
    X <- matrix(rnorm(240), 120, 2, dimnames = list(NULL, c("x", "z")))
    Y <- 1 + sin(X[, 1]) + rnorm(120, sd = .1); off <- 2 + X[, 2]^2
    if (requireNamespace("mgcv", quietly = TRUE)) {
        l <- learner_gam(k = 4)
        expect_equal(l$predict(l$fit(X, Y + off, offset = off), X), l$predict(l$fit(X, Y), X), tolerance = 1e-7)
    }
    if (requireNamespace("ranger", quietly = TRUE)) {
        l <- learner_rf(num.trees = 25, seed = 7)
        expect_equal(l$predict(l$fit(X, Y + off, offset = off), X), l$predict(l$fit(X, Y), X), tolerance = 1e-7)
    }
    if (requireNamespace("SuperLearner", quietly = TRUE)) {
        l <- learner_sl(SL.library = c("SL.mean", "SL.glm"), nfolds = 3, seed = 7)
        id <- rep(seq_len(60), each = 2)
        a <- l$fit(X, Y + off, offset = off, id = id)
        b <- l$fit(X, Y, id = id)
        expect_equal(l$predict(a, X), l$predict(b, X), tolerance = 1e-7)
        expect_true(all(vapply(split(a$foldid, id), function(x) length(unique(x)) == 1L, logical(1))))
    }
})

.transport_fixture <- function() {
    set.seed(105)
    xo <- matrix(rnorm(720), 240, 3, dimnames = list(NULL, c("Z1", "Z2", "V")))
    xo[, 3] <- 1 + xo[, 1] + .4 * xo[, 2] + rnorm(240, sd = .3)
    a <- rep(c(-1, 1), 120)
    e <- external_data(xo, a, 1 + xo[, 1] + 2 * xo[, 3] + a + rnorm(240, sd = .1), shared = c("Z1", "Z2"), external_only = "V")
    xr <- cbind(xo[1:60, 1:2], U = rnorm(60))
    r <- trial_data(xr, a[1:60], rnorm(60), shared = c("Z1", "Z2"), trial_only = "U")
    list(ext = e, trial = r)
}

test_that("imputation matches explicit external regressions and includes Vhat", {
    z <- .transport_fixture(); ef <- fit_external_arms(z$ext, learner_ols())
    tp <- transport(ef, z$trial, method = "impute", imputer = learner_ols(), seed = 9)
    ref <- lm(V ~ Z1 + Z2, as.data.frame(z$ext$X))
    vv <- as.numeric(predict(ref, as.data.frame(z$trial$X)))
    expect_equal(tp$calibration_X[, "V"], vv, tolerance = 1e-10)
    expect_equal(tp$calibration_X[, colnames(z$trial$X)], z$trial$X)
    completed <- cbind(z$trial$X[, 1:2], V = vv)
    expect_equal(tp$q_plus, ef$learner$predict(ef$plus, completed), tolerance = 1e-10)
    expect_equal(tp$q, tp$predict(z$trial$X)$q)
    expect_equal(tp$external_prediction, .roscar_external_predict(ef, z$ext$X)$q)
    expect_true(tp$metadata$imputation_validation$r_squared > .8)
    expect_error(transport(ef, z$trial, "identity"), "requires every external predictor")
    sr <- transport(ef, z$trial, "shared_only")
    expect_identical(sr$calibration_X, z$trial$X)
})

test_that("external one-arm fits explicitly leave the missing arm unavailable", {
    z <- .transport_fixture()
    e <- external_data(z$trial$X, Y = z$trial$Y)
    ef <- fit_external_arms(e, learner_ols(), arm_ext = -1)
    tp <- transport(ef, z$trial)
    expect_null(ef$plus); expect_true(all(is.na(tp$q_plus)))
    expect_true(all(is.finite(tp$q_minus)))
})

test_that("pooled PLS agrees numerically with the CALM sklearn encoder", {
    # Reference: Python sklearn.cross_decomposition.PLSRegression(n_components=2,
    # scale=False), after StandardScaler, evaluated on the exact analytic design
    # below. Computed independently with the installed sklearn on 2026-09-14.
    X <- cbind(Z1 = seq(-2, 2, length.out = 18), Z2 = cos(1:18), V = sin((1:18) * .3))
    Y <- 1 + 2 * X[, 1] - .5 * X[, 2] + .7 * X[, 3] + .2 * cos((1:18) * .7)
    encoder <- .roscar_fit_encoder(X, Y, rep(c(-1, 1), 9), 2, FALSE)
    expected <- matrix(c(.768031679896369, -.11909561121625895, -.6292404739561716,
                         .5781891077657864, -.5300067847044693, .6301140509787688), 3, 2)
    expect_equal(unname(encoder$rotation), expected, tolerance = 1e-10)
})

test_that("CALM selection and mapping depend only on external outcomes", {
    z <- .transport_fixture(); ef <- fit_external_arms(z$ext, learner_ridge(lambda = .01))
    opt <- list(imputer = learner_ridge(lambda = .01), embedding_learner = learner_ridge(lambda = .01), validation_folds = 3, seed = 11)
    tp <- do.call(transport, c(list(ef, z$trial, method = "embed"), opt))
    changed <- z$trial; changed$Y <- changed$Y + seq_along(changed$Y) * 100
    changed$A <- -changed$A
    check <- do.call(transport, c(list(ef, changed, method = "embed"), opt))
    expect_identical(tp$metadata$embedding_validation$embed_dim, 1:3)
    expect_identical(tp$q, check$q)
    expect_identical(tp$encoder, check$encoder)
    expect_identical(tp$calibration_X, z$trial$X)
    expect_false(tp$metadata$treatment_in_encoder)
    expect_false(tp$metadata$pls_by_arm)
    expect_equal(tp$q, tp$predict(z$trial$X)$q)
    native_h <- .roscar_encode(tp$encoder, z$ext$X)
    expect_equal(tp$external_prediction, .roscar_external_predict(tp$ext_fit, native_h)$q)
    arm <- do.call(transport, c(list(ef, z$trial, method = "embed", embed_dim = 2, pls_by_arm = TRUE), opt))
    expect_true(arm$metadata$pls_by_arm)
    expect_lte(arm$metadata$actual_dimension, 3L)
    expect_true(all(is.finite(arm$q)))
})

test_that("the final residual fit retains its cross-fitted training offset", {
    z <- .transport_fixture()
    fit <- borrow_cate(z$trial, z$ext, recipe = "C", basis = ~ Z1 + U,
                       learners = list(external = learner_ols(),
                         calibration = learner_ols(), trial = learner_ols(),
                         imputer = learner_ols()), K = 3, seed = 8)
    expect_equal(fit$final$offset,
                  fit$heldout$mu_cal_plus - fit$heldout$mu_cal_minus)
    expected <- fit$final$learner$predict(fit$final$model,
                  .basis_predict(fit$final$design, z$trial$X)) + fit$final$offset
    expect_equal(as.numeric(predict(fit$final)), expected)
    # Overall prediction uses the same ensemble rule for every requested grid,
    # including the original trial grid used by conditional bootstrap inference.
    pred <- predict(fit, z$trial$X)
    expect_true(all(is.finite(pred)))
    expect_equal(pred, predict(fit$final, z$trial$X,
                               offset = .preliminary_predict(fit, z$trial$X)))
})
