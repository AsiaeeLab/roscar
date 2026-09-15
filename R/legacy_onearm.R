# Compatibility port of JMLR release AsiaeeLab/r-oscar,
# R/02_all_methods_linear.R::estimate_cate_r_oscar_1arm() and
# estimate_cate_r_oscar(), commit cfb70dfe6c1da1538c484f6ef4d7f8ebd0b50592.
# Original authors include Amir Asiaee, Cole Beck, and their collaborators;
# credit and GPL-3 provenance are retained in DESCRIPTION and inst/CITATION.

#' Legacy JMLR one-arm R-OSCAR linear estimator
#'
#' This compatibility port preserves the JMLR implementation's in-sample
#' calibration, default glmnet cross-validation, and lasso final correction.
#' Call `set.seed()` before fitting to reproduce its randomized tuning folds.
#' For grouped cross-fitting, known observed-arm probabilities, configurable
#' learners, and full bootstrap inference use [borrow_cate()] with Recipe B.
#' Different defaults mean the two interfaces do not generally give identical
#' finite-sample estimates.
#'
#' The external control regression is supplied as a coefficient vector; this
#' function fits the trial treated-arm regression, calibrates the external
#' controls, constructs the opposite-arm-weighted baseline, and fits a lasso
#' correction to the preliminary contrast. The final target is the trial CATE.
#' @param X Finite numeric trial covariate matrix, with at least two columns
#'   because the legacy glmnet engine requires them.
#' @param A Trial treatment using the original 0/1 coding, containing both arms.
#' @param Y Numeric trial outcome vector.
#' @param propensity_vec Probability of treatment 1, one per trial row, strictly
#'   between zero and one. This differs from `trial_data()` observed-arm pi.
#' @param mu_x_a_coefs_obs_control External control regression coefficients,
#'   intercept followed by one coefficient per X column.
#' @param init_cate_coefs Optional preliminary contrast coefficients. By default
#'   these are the treated trial coefficients minus calibrated control coefficients.
#' @param normalize_weights Retained compatibility option. Normalization is
#'   algebraically undone in the working response, preserving the original code.
#' @return A list with final and correction coefficients, prediction functions,
#'   fitted CATE values, treated trial and calibrated external control coefficients,
#'   and the two-arm outcome prediction matrix in control/treated column order.
#' @export
estimate_cate_r_oscar_1arm <- function(X, A, Y, propensity_vec,
                                      mu_x_a_coefs_obs_control,
                                      init_cate_coefs = NULL,
                                      normalize_weights = TRUE) {
    if (!is.matrix(X) || !is.numeric(X) || anyNA(X) || any(!is.finite(X)) || ncol(X) < 2L)
        stop("X must be a finite numeric matrix with at least two columns.", call. = FALSE)
    if (length(A) != nrow(X) || anyNA(A) || !setequal(unique(A), c(0, 1)))
        stop("A must contain 0 and 1 with one value per row.", call. = FALSE)
    if (!is.numeric(Y) || length(Y) != nrow(X) || anyNA(Y) || any(!is.finite(Y)))
        stop("Y must contain one finite numeric value per row.", call. = FALSE)
    if (!is.numeric(propensity_vec) || length(propensity_vec) != nrow(X) ||
        anyNA(propensity_vec) || any(!is.finite(propensity_vec)) || any(propensity_vec <= 0 | propensity_vec >= 1))
        stop("propensity_vec must contain positive-arm probabilities strictly between zero and one.", call. = FALSE)
    mu_x_a_coefs_obs_control <- as.numeric(mu_x_a_coefs_obs_control)
    if (length(mu_x_a_coefs_obs_control) != ncol(X) + 1L || any(!is.finite(mu_x_a_coefs_obs_control)))
        stop("External control coefficients must contain an intercept and one finite coefficient per predictor.", call. = FALSE)
    control_idx <- which(A == 0); treated_idx <- which(A == 1)
    if (length(control_idx) < 2L || length(treated_idx) < 2L)
        stop("R-OSCAR-1arm requires at least two RCT observations in each treatment arm.", call. = FALSE)

    treated_model_rct <- glmnet::cv.glmnet(x = X[treated_idx, , drop = FALSE], y = Y[treated_idx])
    treated_rct_coefs <- as.numeric(stats::coef(treated_model_rct, s = "lambda.min"))
    mu_treated_rct <- function(x) drop(cbind(1, x) %*% treated_rct_coefs)
    control_offset <- drop(cbind(1, X[control_idx, , drop = FALSE]) %*% mu_x_a_coefs_obs_control)
    control_cal_model <- glmnet::cv.glmnet(x = X[control_idx, , drop = FALSE],
                                          y = Y[control_idx], offset = control_offset)
    control_delta_coefs <- as.numeric(stats::coef(control_cal_model, s = "lambda.min"))
    control_cal_coefs <- mu_x_a_coefs_obs_control + control_delta_coefs
    mu_control_cal <- function(x) drop(cbind(1, x) %*% control_cal_coefs)
    outcome_function <- function(x) {
        out <- cbind(mu_control_cal(x), mu_treated_rct(x))
        colnames(out) <- c("0", "1")
        out
    }
    m_of_x_mat <- outcome_function(X)
    if (is.null(init_cate_coefs)) init_cate_coefs <- treated_rct_coefs - control_cal_coefs
    else init_cate_coefs <- as.numeric(init_cate_coefs)
    if (length(init_cate_coefs) != ncol(X) + 1L || any(!is.finite(init_cate_coefs)))
        stop("init_cate_coefs must contain one finite intercept and coefficient per predictor.", call. = FALSE)
    cate <- .legacy_r_oscar_final(X, A, Y, propensity_vec, init_cate_coefs,
                                  m_of_x_mat, normalize_weights)
    cate$treated_rct_coefs <- treated_rct_coefs
    cate$control_obs_coefs <- mu_x_a_coefs_obs_control
    cate$control_delta_coefs <- control_delta_coefs
    cate$control_cal_coefs <- control_cal_coefs
    cate$m_of_x_mat <- m_of_x_mat
    cate$outcome_function <- outcome_function
    cate
}

.legacy_r_oscar_final <- function(X, A, Y, propensity_vec, init_cate_coefs,
                                  m_of_x_mat, normalize_weights = TRUE) {
    propens_weights <- ifelse(A == 1, 1 / propensity_vec, 1 / (1 - propensity_vec))
    if (normalize_weights) {
        mean_propens <- mean(propens_weights)
        propens_weights <- propens_weights / mean_propens
    } else mean_propens <- 1
    m_of_x_avg <- rowSums(m_of_x_mat * cbind(propensity_vec, 1 - propensity_vec))
    init_cate_est <- drop(cbind(1, X) %*% init_cate_coefs)
    y_tilde <- ((2 * A - 1) * (Y - m_of_x_avg) * propens_weights) * mean_propens - init_cate_est
    cate_model <- glmnet::cv.glmnet(x = X, y = y_tilde)
    cate_delta_coefficients <- stats::predict(cate_model, type = "coef", s = "lambda.min")
    cate_coefficients <- cate_delta_coefficients + init_cate_coefs
    fitted_cate <- unname(stats::predict(cate_model, newx = X, type = "response", s = "lambda.min")) + init_cate_est
    return_cate <- function(x) drop(unname(cbind(1, x) %*% cate_coefficients))
    list(cate_coefficients = cate_coefficients, cate_delta_coefficients = cate_delta_coefficients,
         cate_function = return_cate, fitted_cate = fitted_cate)
}
