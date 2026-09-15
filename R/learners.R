#' Regression learners for external prediction and trial calibration
#'
#' A learner is a list containing `fit(X, y, weights, offset, ...)` and
#' `predict(fit, X, ...)`. Gaussian learners fit y minus the supplied offset;
#' predictions contain only that fitted correction. The caller adds the offset.
#' Binomial learners return a linear-predictor correction, so the caller uses
#' `plogis(offset + prediction)`. Prediction never reuses training offsets.
#'
#' Penalized learners standardize predictors, retain an unpenalized intercept,
#' and select lambda by training-sample cross-validation. Supply `id` to `fit()`
#' to keep all copies of an independent unit together during tuning. The grid,
#' selected penalty, and tuning folds are retained in the fitted object.
#' Link-scale binary calibration is implemented but is not evaluated in the
#' paper's simulations. Random forests and SuperLearner provide Gaussian
#' residual regressions only; use a binomial GLM/GAM learner for link calibration.
#' @param lambda Positive penalty grid, defaulting to 25 log-spaced values from
#'   1e-4 to 1e2. A single value disables tuning.
#' @param nfolds Number of tuning folds, default five.
#' @param seed Optional tuning seed, with no change to the caller's RNG state.
#' @param family Either `"gaussian"` or `"binomial"`.
#' @param intercept Whether to include an unpenalized intercept.
#' @param k Basis size for each GAM smooth (automatically limited by the
#'   number of distinct observed covariate values).
#' @param num.trees Number of ranger regression trees.
#' @param SL.library SuperLearner library; its constituent packages must be
#'   installed by the user. Built-in wrappers resolve in the SuperLearner
#'   namespace; custom wrappers can supply their lookup environment through
#'   `env` in `...` (including the package's screening function `All`).
#' @param ... Additional options to the backend. Core response, offset, fold,
#'   and prediction-scale arguments are controlled by the interface.
#' @return A learner list with `fit`, `predict`, `name`, `family`, and settings.
#' @name learners
#' @export
learner_lasso <- function(lambda = 10^seq(-4, 2, length.out = 25), nfolds = 5,
                          seed = NULL, family = c("gaussian", "binomial"),
                          intercept = TRUE, ...) {
    .roscar_penalized(1, lambda, nfolds, seed, match.arg(family), intercept, list(...))
}

#' @rdname learners
#' @export
learner_ridge <- function(lambda = 10^seq(-4, 2, length.out = 25), nfolds = 5,
                          seed = NULL, family = c("gaussian", "binomial"),
                          intercept = TRUE, ...) {
    .roscar_penalized(0, lambda, nfolds, seed, match.arg(family), intercept, list(...))
}

.roscar_learner_input <- function(X, y, weights = NULL, offset = NULL, id = NULL) {
    X <- .roscar_matrix(X, length(y)); n <- length(y)
    if (!is.numeric(y) || anyNA(y) || any(!is.finite(y))) stop("y must be finite and numeric.", call. = FALSE)
    if (is.null(weights)) weights <- rep(1, n)
    if (is.null(offset)) offset <- rep(0, n)
    if (length(offset) == 1L) offset <- rep(offset, n)
    if (length(weights) != n || anyNA(weights) || any(!is.finite(weights)) || any(weights < 0) || !any(weights > 0))
        stop("weights must be finite, nonnegative, and have a positive sum.", call. = FALSE)
    if (length(offset) != n || anyNA(offset) || any(!is.finite(offset)))
        stop("offset must contain one finite value per outcome.", call. = FALSE)
    if (is.null(id)) id <- seq_len(n)
    if (length(id) != n || anyNA(id)) stop("id must have one nonmissing value per row.", call. = FALSE)
    list(X = X, y = as.numeric(y), weights = as.numeric(weights), offset = as.numeric(offset), id = id)
}

.roscar_predict_matrix <- function(X, columns) {
    X <- .roscar_matrix(X)
    if (!all(columns %in% colnames(X))) stop("Prediction data lack fitted covariate columns.", call. = FALSE)
    X[, columns, drop = FALSE]
}

.roscar_check_learner <- function(x) {
    if (!is.list(x) || !is.function(x$fit) || !is.function(x$predict))
        stop("learner must supply fit and predict functions.", call. = FALSE)
    invisible(x)
}

.roscar_penalized <- function(alpha, lambda, nfolds, seed, family, intercept, options) {
    if (!is.numeric(lambda) || !length(lambda) || anyNA(lambda) || any(!is.finite(lambda)) || any(lambda <= 0))
        stop("lambda must contain positive finite penalties.", call. = FALSE)
    if (length(nfolds) != 1L || is.na(nfolds) || nfolds < 3L || nfolds != as.integer(nfolds))
        stop("Penalized tuning requires nfolds >= 3.", call. = FALSE)
    lambda <- sort(unique(lambda), decreasing = TRUE)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, id = NULL, ...) {
        d <- .roscar_learner_input(X, y, weights, offset, id)
        if (family == "binomial" && any(!d$y %in% c(0, 1))) stop("Binomial outcomes must be zero or one.", call. = FALSE)
        # glmnet rejects no-variable/constant designs and constant responses.
        varying <- if (ncol(d$X)) apply(d$X, 2L, function(z) diff(range(z)) > 0) else logical(0)
        if (!any(varying) || length(unique(d$y - if (family == "gaussian") d$offset else 0)) < 2L) {
            if (!intercept && any(varying))
                stop("A constant response with intercept=FALSE is unsupported by glmnet; use learner_ols().", call. = FALSE)
            base <- if (intercept) learner_intercept(family = family) else learner_ols(family = family, intercept = FALSE)
            fallback_X <- if (intercept) d$X else d$X[, FALSE, drop = FALSE]
            return(list(fallback = base, model = base$fit(fallback_X, d$y, d$weights, d$offset),
                        columns = colnames(d$X), lambda = NA_real_, foldid = NULL, family = family))
        }
        if (!requireNamespace("glmnet", quietly = TRUE)) stop("Install glmnet to use this learner.", call. = FALSE)
        xm <- d$X[, varying, drop = FALSE]
        columns <- colnames(xm)
        padded <- ncol(xm) == 1L
        if (padded) xm <- cbind(xm, .roscar_zero = 0)
        args <- list(x = xm, y = if (family == "gaussian") d$y - d$offset else d$y,
                     weights = d$weights, family = family, alpha = alpha,
                     lambda = lambda, standardize = TRUE, intercept = intercept)
        if (family == "binomial") args$offset <- d$offset
        if (length(options)) {
            if (any(names(options) %in% names(args))) stop("Backend options duplicate core learner arguments.", call. = FALSE)
            args <- c(args, options)
        }
        unique_n <- length(unique(d$id)); foldid <- NULL
        if (length(lambda) > 1L && unique_n >= 3L) {
            cvK <- min(nfolds, unique_n)
            strat <- if (family == "binomial") d$y else rep(1, length(d$y))
            foldid <- make_stratified_folds(strat, K = cvK, id = d$id, seed = seed)
            # A binomial training split must contain both classes.
            if (family == "binomial" && any(vapply(unique(foldid), function(k)
                length(unique(d$y[foldid != k])) < 2L, logical(1))))
                stop("Too few independent observations in a binomial outcome class for grouped tuning.", call. = FALSE)
            cv <- do.call(glmnet::cv.glmnet, c(args, list(foldid = foldid,
                         type.measure = if (family == "binomial") "deviance" else "mse")))
            model <- cv$glmnet.fit; selected <- cv$lambda.min
            cv_loss <- data.frame(lambda = cv$lambda, loss = cv$cvm, se = cv$cvsd)
        } else {
            if (length(lambda) > 1L) stop("At least three independent units are required to tune lambda; supply one penalty for a smaller sample.", call. = FALSE)
            model <- do.call(glmnet::glmnet, args); selected <- lambda[1L]; cv_loss <- NULL
        }
        list(model = model, columns = columns, padded = padded, lambda = selected,
             lambda_grid = lambda, foldid = foldid, cv_loss = cv_loss, family = family)
    }
    pred_fun <- function(fit, X, ...) {
        if (!is.null(fit$fallback)) return(fit$fallback$predict(fit$model, X))
        xm <- .roscar_predict_matrix(X, fit$columns)
        if (fit$padded) xm <- cbind(xm, .roscar_zero = 0)
        args <- list(object = fit$model, newx = xm, s = fit$lambda, type = "link")
        if (fit$family == "binomial") args$newoffset <- rep(0, nrow(xm))
        as.numeric(do.call(stats::predict, args))
    }
    list(fit = fit_fun, predict = pred_fun, name = if (alpha == 1) "lasso" else "ridge",
         family = family, lambda = lambda, nfolds = nfolds, seed = seed, intercept = intercept)
}

#' @rdname learners
#' @export
learner_ols <- function(family = c("gaussian", "binomial"), intercept = TRUE) {
    family <- match.arg(family)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, ...) {
        d <- .roscar_learner_input(X, y, weights, offset)
        xm <- if (intercept) cbind(`(Intercept)` = 1, d$X) else d$X
        if (!ncol(xm)) return(list(coefficients = numeric(0), columns = colnames(d$X), intercept = FALSE))
        if (family == "gaussian") model <- stats::lm.wfit(xm, d$y - d$offset, w = d$weights)
        else {
            if (any(!d$y %in% c(0, 1))) stop("Binomial outcomes must be zero or one.", call. = FALSE)
            model <- stats::glm.fit(xm, d$y, weights = d$weights, offset = d$offset,
                                    family = stats::binomial(), intercept = intercept)
        }
        co <- model$coefficients; co[is.na(co)] <- 0
        list(coefficients = co, columns = colnames(d$X), intercept = intercept,
             rank = model$rank, family = family)
    }
    pred_fun <- function(fit, X, ...) {
        xm <- .roscar_predict_matrix(X, fit$columns)
        if (fit$intercept) xm <- cbind(`(Intercept)` = 1, xm)
        as.numeric(xm %*% fit$coefficients)
    }
    list(fit = fit_fun, predict = pred_fun, name = "ols", family = family, intercept = intercept)
}

#' @rdname learners
#' @export
learner_intercept <- function(family = c("gaussian", "binomial")) {
    family <- match.arg(family); base <- learner_ols(family = family)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, ...) {
        d <- .roscar_learner_input(X, y, weights, offset)
        base$fit(d$X[, FALSE, drop = FALSE], d$y, d$weights, d$offset)
    }
    pred_fun <- function(fit, X, ...) rep(as.numeric(fit$coefficients[1L]), nrow(.roscar_matrix(X)))
    list(fit = fit_fun, predict = pred_fun, name = "intercept", family = family)
}

#' @rdname learners
#' @export
learner_gam <- function(k = 5, family = c("gaussian", "binomial"), ...) {
    family <- match.arg(family); options <- list(...)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, ...) {
        if (!requireNamespace("mgcv", quietly = TRUE)) stop("Install mgcv to use learner_gam().", call. = FALSE)
        d <- .roscar_learner_input(X, y, weights, offset)
        cols <- colnames(d$X); dat <- as.data.frame(d$X)
        if (ncol(dat)) names(dat) <- paste0("x", seq_len(ncol(dat)))
        terms <- vapply(seq_len(ncol(d$X)), function(j) {
            distinct <- length(unique(d$X[, j]))
            if (distinct < 3L) return(if (distinct < 2L) "" else names(dat)[j])
            paste0("s(", names(dat)[j], ", k=", min(k, distinct), ")")
        }, character(1))
        terms <- terms[nzchar(terms)]
        dat$.y <- if (family == "gaussian") d$y - d$offset else d$y
        dat$.offset <- if (family == "gaussian") rep(0, length(y)) else d$offset
        dat$.weights <- d$weights
        # mgcv exposes smooth specification constructors in its namespace.
        form <- stats::as.formula(paste(".y ~", paste(c("1", terms, "offset(.offset)"), collapse = " + ")),
                                  env = asNamespace("mgcv"))
        model <- do.call(mgcv::gam, c(list(formula = form, data = dat, weights = dat$.weights,
                         family = if (family == "gaussian") stats::gaussian() else stats::binomial(),
                         method = "REML"), options))
        list(model = model, columns = cols)
    }
    pred_fun <- function(fit, X, ...) {
        dat <- as.data.frame(.roscar_predict_matrix(X, fit$columns))
        if (ncol(dat)) names(dat) <- paste0("x", seq_len(ncol(dat)))
        dat$.offset <- rep(0, nrow(dat))
        as.numeric(stats::predict(fit$model, newdata = dat, type = "link"))
    }
    list(fit = fit_fun, predict = pred_fun, name = "gam", family = family, k = k)
}

#' @rdname learners
#' @export
learner_rf <- function(num.trees = 500, seed = NULL, ...) {
    options <- list(...)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, ...) {
        d <- .roscar_learner_input(X, y, weights, offset)
        if (!ncol(d$X)) {
            base <- learner_intercept()
            return(list(fallback = base, model = base$fit(d$X, d$y, d$weights, d$offset)))
        }
        if (!requireNamespace("ranger", quietly = TRUE)) stop("Install ranger to use learner_rf().", call. = FALSE)
        model <- .roscar_with_seed(seed, do.call(ranger::ranger, c(list(x = as.data.frame(d$X),
                 y = d$y - d$offset, case.weights = d$weights, num.trees = num.trees,
                 seed = if (is.null(seed)) 0 else seed, num.threads = 1), options)))
        list(model = model, columns = colnames(d$X))
    }
    pred_fun <- function(fit, X, ...) {
        if (!is.null(fit$fallback)) return(fit$fallback$predict(fit$model, X))
        as.numeric(stats::predict(fit$model, data = as.data.frame(.roscar_predict_matrix(X, fit$columns)))$predictions)
    }
    list(fit = fit_fun, predict = pred_fun, name = "rf", family = "gaussian", seed = seed)
}

#' @rdname learners
#' @export
learner_sl <- function(SL.library = c("SL.mean", "SL.glm"), nfolds = 5,
                       seed = NULL, ...) {
    options <- list(...)
    fit_fun <- function(X, y, weights = NULL, offset = NULL, id = NULL, ...) {
        if (!requireNamespace("SuperLearner", quietly = TRUE)) stop("Install SuperLearner to use learner_sl().", call. = FALSE)
        d <- .roscar_learner_input(X, y, weights, offset, id)
        foldid <- make_stratified_folds(rep(1, length(y)), K = min(nfolds, length(unique(d$id))), id = d$id, seed = seed)
        validRows <- split(seq_along(y), foldid)
        dat <- as.data.frame(d$X)
        if (!ncol(dat)) dat <- data.frame(.constant = rep(0, length(y)))
        sl_options <- options
        if (is.null(sl_options$env)) sl_options$env <- asNamespace("SuperLearner")
        model <- .roscar_with_seed(seed, do.call(SuperLearner::SuperLearner, c(list(Y = d$y - d$offset,
                 X = dat, family = stats::gaussian(), SL.library = SL.library, obsWeights = d$weights,
                 id = d$id, cvControl = list(V = length(validRows), validRows = validRows)), sl_options)))
        list(model = model, columns = colnames(d$X), foldid = foldid)
    }
    pred_fun <- function(fit, X, ...) {
        dat <- as.data.frame(.roscar_predict_matrix(X, fit$columns))
        if (!ncol(dat)) dat <- data.frame(.constant = rep(0, nrow(dat)))
        as.numeric(stats::predict(fit$model, newdata = dat, onlySL = TRUE)$pred)
    }
    list(fit = fit_fun, predict = pred_fun, name = "sl", family = "gaussian", seed = seed)
}
