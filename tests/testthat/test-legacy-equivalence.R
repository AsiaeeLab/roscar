# These oracles use the algebraically equivalent arm-residual representation
# of the AIPW score, rather than the implementation's centered pseudo-response:
# psi(m*) - (mu1-mu0) = A01*(Y-mu1)/p - (1-A01)*(Y-mu0)/(1-p).
# Source: AsiaeeLab/r-oscar/R/02_all_methods_linear.R (JMLR release) and
# couthcommander/ROSCAR/R/model_roscar.R. Default glmnet CV and set.seed are
# matched. This avoids brittle coefficient snapshots tied to one glmnet version.

.legacy_bundled_example <- function() {
    d <- new.env(parent = emptyenv())
    if (requireNamespace("roscar", quietly = TRUE)) {
        utils::data(list = c("rct", "os"), package = "roscar", envir = d)
    } else {
        load(testthat::test_path("..", "..", "data", "rct.rda"), envir = d)
        load(testthat::test_path("..", "..", "data", "os.rda"), envir = d)
    }
    # A fixed, explicitly documented subset keeps the regression test small.
    # Outcomes and predictors are the actual bundled example, without simulation.
    list(rct = list(X = d$rct$X[1:200, 1:8], A = d$rct$A[1:200], Y = d$rct$Y[1:200]),
         os = list(X = d$os$X[1:600, 1:8], A = d$os$A[1:600], Y = d$os$Y[1:600]))
}

.legacy_cv_coefficient <- function(X, y) {
    as.numeric(stats::coef(glmnet::cv.glmnet(X, y), s = "lambda.min"))
}

.legacy_residual_oracle <- function(rct, os = NULL, control_coef = NULL, p,
                                   initial_coef = NULL) {
    X <- rct$X; XX <- cbind(1, X)
    if (is.null(control_coef)) {
        b <- vapply(0:1, function(a) {
            i <- os$A == a
            .legacy_cv_coefficient(os$X[i, , drop = FALSE], os$Y[i])
        }, numeric(ncol(X) + 1L))
        for (a in 0:1) {
            i <- rct$A == a
            # Regress the response residual directly; original uses glmnet offset.
            b[, a + 1L] <- b[, a + 1L] + .legacy_cv_coefficient(
                X[i, , drop = FALSE], rct$Y[i] - drop(XX[i, , drop = FALSE] %*% b[, a + 1L]))
        }
    } else {
        i1 <- rct$A == 1; i0 <- !i1
        b1 <- .legacy_cv_coefficient(X[i1, , drop = FALSE], rct$Y[i1])
        b0 <- control_coef + .legacy_cv_coefficient(X[i0, , drop = FALSE],
                  rct$Y[i0] - drop(XX[i0, , drop = FALSE] %*% control_coef))
        b <- cbind(b0, b1)
    }
    mu <- XX %*% b
    contrast <- b[, 2] - b[, 1]
    # This score identity independently checks the opposite-arm weights, sign,
    # propensity denominator, and subtraction of the preliminary contrast.
    score <- ifelse(rct$A == 1, (rct$Y - mu[, 2]) / p,
                     -(rct$Y - mu[, 1]) / (1 - p))
    if (is.null(initial_coef)) initial_coef <- contrast
    score <- score + drop(XX %*% (contrast - initial_coef))
    final <- initial_coef + .legacy_cv_coefficient(X, score)
    list(coefficient = final, outcome = mu, fitted = drop(XX %*% final))
}

test_that("retained Cole R-OSCAR matches an independent arm-residual oracle", {
    z <- .legacy_bundled_example(); p <- rep(mean(z$rct$A), length(z$rct$A))
    set.seed(1901)
    actual <- model_roscar(z$rct, z$os)$r_oscar
    set.seed(1901)
    reference <- .legacy_residual_oracle(z$rct, z$os, p = p)
    expect_equal(as.numeric(actual$cate_coefficients), reference$coefficient, tolerance = 1e-7)
    expect_equal(as.numeric(actual$fitted_cate), reference$fitted, tolerance = 1e-7)
    expect_equal(actual$cate_function(z$rct$X[1:3, , drop = FALSE]), reference$fitted[1:3], tolerance = 1e-7)
})

test_that("JMLR one-arm port matches the independent oracle with unequal pi", {
    z <- .legacy_bundled_example()
    set.seed(1902)
    cc <- .legacy_cv_coefficient(z$os$X[z$os$A == 0, , drop = FALSE], z$os$Y[z$os$A == 0])
    # Vary the known propensity by covariates to exercise observed-arm inverses.
    p <- plogis(-.3 + .15 * z$rct$X[, 1])
    set.seed(1903)
    actual <- estimate_cate_r_oscar_1arm(z$rct$X, z$rct$A, z$rct$Y, p, cc)
    set.seed(1903)
    reference <- .legacy_residual_oracle(z$rct, control_coef = cc, p = p)
    expect_equal(as.numeric(actual$cate_coefficients), reference$coefficient, tolerance = 1e-7)
    expect_equal(unname(actual$m_of_x_mat), unname(reference$outcome), tolerance = 1e-8)
    expect_equal(as.numeric(actual$cate_function(z$rct$X)), reference$fitted, tolerance = 1e-7)
    expect_identical(colnames(actual$m_of_x_mat), c("0", "1"))
    expect_equal(actual$control_cal_coefs, actual$control_obs_coefs + actual$control_delta_coefs)
})

test_that("legacy weight normalization cancels and custom initial contrasts work", {
    z <- .legacy_bundled_example(); p <- rep(.35, length(z$rct$A))
    cc <- c(.5, rep(.1, ncol(z$rct$X))); init <- rep(0, length(cc))
    set.seed(1904)
    a <- estimate_cate_r_oscar_1arm(z$rct$X, z$rct$A, z$rct$Y, p, cc, init,
                                   normalize_weights = TRUE)
    set.seed(1904)
    b <- estimate_cate_r_oscar_1arm(z$rct$X, z$rct$A, z$rct$Y, p, cc, init,
                                   normalize_weights = FALSE)
    expect_equal(as.numeric(a$cate_coefficients), as.numeric(b$cate_coefficients), tolerance = 1e-8)
    set.seed(1904)
    reference <- .legacy_residual_oracle(z$rct, control_coef = cc, p = p, initial_coef = init)
    expect_equal(as.numeric(a$cate_coefficients), reference$coefficient, tolerance = 1e-7)
    expect_error(estimate_cate_r_oscar_1arm(z$rct$X, 2 * z$rct$A - 1, z$rct$Y, p, cc), "0 and 1")
})
