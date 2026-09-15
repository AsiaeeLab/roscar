#' Fit externally observed treatment-arm outcome regressions
#' @param ext An [external_data()] object.
#' @param learner A regression learner; default ridge with cross-validation.
#' @param arm_ext The arm represented when external A is missing, default -1.
#' @return An object of class `roscar_external_fit` containing the external
#'   data, learner, and fitted `plus` and `minus` arm models. Unobserved arms
#'   remain NULL and are subsequently fitted from trial training folds.
#' @export
fit_external_arms <- function(ext, learner = learner_ridge(), arm_ext = -1) {
    .roscar_check_learner(learner)
    if (!inherits(ext, "roscar_external"))
        ext <- external_data(ext$X, ext$A, ext$Y)
    arm_ext <- .roscar_arm(arm_ext)
    if (length(arm_ext) != 1L) stop("arm_ext must designate one treatment arm.", call. = FALSE)
    A <- if (is.null(ext$A)) rep(arm_ext, length(ext$Y)) else ext$A
    fits <- list(plus = NULL, minus = NULL)
    for (a in c(1, -1)) {
        ix <- which(A == a)
        if (length(ix)) fits[[if (a == 1) "plus" else "minus"]] <-
            learner$fit(ext$X[ix, , drop = FALSE], ext$Y[ix], id = ix)
    }
    structure(list(plus = fits$plus, minus = fits$minus, models = fits,
                   ext = ext, A = A, learner = learner, arm_ext = arm_ext,
                   columns = colnames(ext$X)), class = "roscar_external_fit")
}

.roscar_external_predict <- function(ext_fit, X) {
    n <- nrow(X)
    out <- lapply(c("plus", "minus"), function(nm) {
        m <- ext_fit$models[[nm]]
        if (is.null(m)) return(rep(NA_real_, n))
        pred <- as.numeric(ext_fit$learner$predict(m, X))
        if (identical(ext_fit$learner$family, "binomial")) pred <- stats::plogis(pred)
        if (length(pred) != n || any(!is.finite(pred))) stop("External learner returned invalid predictions.", call. = FALSE)
        pred
    })
    names(out) <- c("q_plus", "q_minus")
    out$q <- cbind(plus = out$q_plus, minus = out$q_minus)
    out
}

.roscar_transport_blocks <- function(ext, trial, shared, trial_only, external_only) {
    first <- function(...) {
        for (x in list(...)) if (!is.null(x)) return(x)
        NULL
    }
    shared <- first(shared, trial$blocks$shared, ext$blocks$shared,
                    intersect(colnames(trial$X), colnames(ext$X)))
    shared <- .roscar_columns(shared, ext$X, "shared")
    if (!length(shared) || !all(shared %in% colnames(trial$X)))
        stop("Mismatch transport requires shared measured covariates in both sources.", call. = FALSE)
    trial_only <- first(trial_only, trial$blocks$trial_only, setdiff(colnames(trial$X), shared))
    external_only <- first(external_only, ext$blocks$external_only, setdiff(colnames(ext$X), shared))
    trial_only <- .roscar_columns(trial_only, trial$X, "trial_only")
    external_only <- .roscar_columns(external_only, ext$X, "external_only")
    if (length(intersect(shared, trial_only)) || length(intersect(shared, external_only)) ||
        length(intersect(trial_only, external_only)) ||
        !setequal(c(shared, trial_only), colnames(trial$X)) ||
        !setequal(c(shared, external_only), colnames(ext$X)))
        stop("shared, trial_only, and external_only must form disjoint, complete source-specific covariate blocks.", call. = FALSE)
    list(shared = shared, trial_only = trial_only, external_only = external_only)
}

.roscar_fit_imputer <- function(ext, blocks, learner, K, seed) {
    .roscar_check_learner(learner)
    if (!is.null(learner$family) && learner$family != "gaussian")
        stop("The block imputation learner must fit Gaussian conditional means.", call. = FALSE)
    Z <- ext$X[, blocks$shared, drop = FALSE]
    V <- ext$X[, blocks$external_only, drop = FALSE]
    models <- lapply(seq_len(ncol(V)), function(j) learner$fit(Z, V[, j], id = seq_len(nrow(Z))))
    names(models) <- colnames(V)
    predict_block <- function(newX) {
        zz <- .roscar_predict_matrix(newX, blocks$shared)
        if (!ncol(V)) return(matrix(numeric(0), nrow(zz), 0L))
        ans <- vapply(models, function(m) as.numeric(learner$predict(m, zz)), numeric(nrow(zz)))
        matrix(ans, nrow = nrow(zz), dimnames = list(NULL, colnames(V)))
    }
    # This validation has no access to trial outcomes or covariate distributions.
    validation <- data.frame(variable = colnames(V), mse = rep(NA_real_, ncol(V)),
                              null_mse = rep(NA_real_, ncol(V)), r_squared = rep(NA_real_, ncol(V)))
    foldid <- NULL
    if (ncol(V) && nrow(Z) >= 4L && K >= 2L) {
        foldid <- make_stratified_folds(rep(1, nrow(Z)), K = min(K, nrow(Z)), seed = seed)
        hold <- null <- matrix(NA_real_, nrow(Z), ncol(V))
        for (fold in unique(foldid)) {
            tr <- which(foldid != fold); va <- which(foldid == fold)
            for (j in seq_len(ncol(V))) {
                fit <- learner$fit(Z[tr, , drop = FALSE], V[tr, j], id = tr)
                hold[va, j] <- learner$predict(fit, Z[va, , drop = FALSE])
                null[va, j] <- mean(V[tr, j])
            }
        }
        validation$mse <- colMeans((hold - V)^2)
        validation$null_mse <- colMeans((null - V)^2)
        validation$r_squared <- ifelse(validation$null_mse > 0,
                                        1 - validation$mse / validation$null_mse, NA_real_)
    }
    list(models = models, learner = learner, predict = predict_block,
         validation = validation, foldid = foldid)
}

# Univariate-response NIPALS PLS: copied mathematically from sklearn's
# PLSRegression(scale=FALSE), used by CALM's src/methods/mosaic_linear.py.
# Unlike the Python release's variance-of-CATE tuning wrapper, component count
# is selected only on external held-out outcome loss, as specified in the prompt.
.roscar_pls_rotation <- function(X, y, d) {
    xc <- X; yc <- y - mean(y)
    p <- ncol(X); W <- P <- matrix(0, p, d); used <- 0L
    for (j in seq_len(d)) {
        w <- as.numeric(crossprod(xc, yc)); norm <- sqrt(sum(w^2))
        if (!is.finite(norm) || norm < 1e-12) break
        w <- w / norm
        # Match sklearn's deterministic sign convention.
        if (w[which.max(abs(w))] < 0) w <- -w
        tt <- as.numeric(xc %*% w); den <- sum(tt^2)
        if (den < 1e-12) break
        pp <- as.numeric(crossprod(xc, tt)) / den
        yy <- sum(yc * tt) / den
        xc <- xc - tcrossprod(tt, pp); yc <- yc - tt * yy
        W[, j] <- w; P[, j] <- pp; used <- j
    }
    if (!used) return(matrix(numeric(0), p, 0L))
    W <- W[, seq_len(used), drop = FALSE]; P <- P[, seq_len(used), drop = FALSE]
    W %*% solve(crossprod(P, W))
}

.roscar_fit_encoder <- function(X, Y, A, d, by_arm) {
    center <- colMeans(X)
    scale <- sqrt(colMeans(sweep(X, 2L, center)^2))
    scale[!is.finite(scale) | scale < 1e-12] <- 1
    xs <- sweep(sweep(X, 2L, center), 2L, scale, "/")
    d <- min(d, qr(xs)$rank, nrow(X) - 1L)
    if (d < 1L) stop("PLS requires at least one nonconstant external predictor.", call. = FALSE)
    if (by_arm) {
        rotations <- lapply(sort(unique(A)), function(a) {
            ix <- which(A == a); xa <- xs[ix, , drop = FALSE]
            xa <- sweep(xa, 2L, colMeans(xa))
            da <- min(d, qr(xa)$rank, length(ix) - 1L)
            if (da < 1L) return(matrix(numeric(0), ncol(X), 0L))
            .roscar_pls_rotation(xa, Y[ix], da)
        })
        rotation <- do.call(cbind, rotations)
        if (ncol(rotation)) {
            dec <- qr(rotation)
            rotation <- qr.Q(dec)[, seq_len(dec$rank), drop = FALSE]
        }
    } else rotation <- .roscar_pls_rotation(xs, Y, d)
    if (!ncol(rotation)) {
        # A constant outcome has no supervised direction. An intercept-only
        # outcome model is the well-defined limit of a zero-dimensional encoder.
        rotation <- matrix(numeric(0), ncol(X), 0L)
    }
    colnames(rotation) <- if (ncol(rotation)) paste0("H", seq_len(ncol(rotation))) else NULL
    list(center = center, scale = scale, rotation = rotation, columns = colnames(X),
         requested_dim = d, dimension = ncol(rotation), pls_by_arm = by_arm)
}

.roscar_encode <- function(encoder, X) {
    xx <- .roscar_predict_matrix(X, encoder$columns)
    sweep(sweep(xx, 2L, encoder$center), 2L, encoder$scale, "/") %*% encoder$rotation
}

.roscar_embedding_select <- function(ext, A, learner, candidates, K, seed, by_arm) {
    K <- min(K, nrow(ext$X))
    foldid <- make_stratified_folds(A, K = K, seed = seed)
    if (any(vapply(unique(foldid), function(k) !all(unique(A) %in% A[foldid != k]), logical(1))))
        stop("Each external training fold must retain every available treatment arm.", call. = FALSE)
    losses <- matrix(NA_real_, length(candidates), length(unique(foldid)))
    for (k in seq_along(unique(foldid))) {
        f <- unique(foldid)[k]; tr <- which(foldid != f); va <- which(foldid == f)
        for (j in seq_along(candidates)) {
            encoder <- .roscar_fit_encoder(ext$X[tr, , drop = FALSE], ext$Y[tr], A[tr], candidates[j], by_arm)
            htr <- .roscar_encode(encoder, ext$X[tr, , drop = FALSE])
            hva <- .roscar_encode(encoder, ext$X[va, , drop = FALSE])
            arms <- fit_external_arms(external_data(htr, A[tr], ext$Y[tr]), learner)
            pred <- .roscar_external_predict(arms, hva)
            yhat <- ifelse(A[va] == 1, pred$q_plus, pred$q_minus)
            losses[j, k] <- mean(vapply(unique(A[va]), function(a) {
                ix <- A[va] == a
                mean((yhat[ix] - ext$Y[va[ix]])^2)
            }, numeric(1)))
        }
    }
    cv <- data.frame(embed_dim = candidates, mean_loss = rowMeans(losses),
                     se_loss = apply(losses, 1L, stats::sd) / sqrt(ncol(losses)))
    list(dimension = candidates[which.min(cv$mean_loss)], validation = cv, foldid = foldid)
}

#' Transport external predictions into trial covariate space
#'
#' Identity evaluates matched covariates. Imputation (MR-OSCAR, Recipe C)
#' predicts the external-only block from shared external covariates, evaluates
#' external arm regressions on the imputed-complete rows, and augments the
#' calibration design with that predicted block. `shared_only` implements the
#' SR-OSCAR comparator. Its calibration still retains every trial covariate.
#'
#' Embedding (linear CALM, Recipe D) follows
#' `di-borrowing-aligning/code/src/methods/mosaic_linear.py`: one PLS model on
#' pooled external outcomes, with treatment excluded from predictors, ridge
#' block prediction, external arm regressions in the embedding, and calibration
#' on the original trial covariates. `pls_by_arm = TRUE` combines arm-specific
#' directions after removing linear dependencies. Standardization uses only
#' external data. Automatic dimension selection evaluates one to three
#' components by equally weighted arm-specific external validation loss; all
#' encoder fitting, standardization, and outcome fitting are repeated within
#' those external validation folds.
#' @param ext_fit A fitted object from [fit_external_arms()].
#' @param trial A [trial_data()] object.
#' @param method One of `identity`, `impute`, `embed`, or `shared_only`.
#' @param shared,trial_only,external_only Covariate block names or indices;
#'   defaults come from the constructors or matching column names.
#' @param imputer Learner for each external-only covariate, default ridge.
#' @param embed_dim Fixed positive number of PLS components, or NULL to select
#'   among one to three components. With arm-specific PLS this is per arm.
#' @param pls_by_arm Use the optional arm-specific encoder, default FALSE.
#' @param embedding_learner Learner for external arm regressions in the
#'   embedding, default ridge.
#' @param validation_folds Number of external validation folds, default five.
#' @param seed Seed for external validation folds and default learners.
#' @return A `roscar_transport` list containing `q_plus`, `q_minus`, `q`,
#'   `calibration_X`, external validation metadata, and a `predict(newX)` closure
#'   returning the same predictions and calibration design for new trial rows.
#'   `external_prediction` contains plus/minus predictions on the native
#'   external covariates (or embedding) for source-support diagnostics.
#' @export
transport <- function(ext_fit, trial, method = c("identity", "impute", "embed", "shared_only"),
                      shared = NULL, trial_only = NULL, external_only = NULL,
                      imputer = learner_ridge(seed = seed), embed_dim = NULL,
                      pls_by_arm = FALSE, embedding_learner = learner_ridge(seed = seed),
                      validation_folds = 5, seed = NULL) {
    method <- match.arg(method)
    if (!inherits(ext_fit, "roscar_external_fit")) stop("ext_fit must come from fit_external_arms().", call. = FALSE)
    if (is.null(trial$X)) stop("trial must contain X.", call. = FALSE)
    trial$X <- .roscar_matrix(trial$X)
    trial_cols <- colnames(trial$X)
    ext <- ext_fit$ext
    metadata <- list(method = method, external_only_fitting = TRUE)
    imputation <- encoder <- NULL
    if (method == "identity") {
        if (!all(colnames(ext$X) %in% trial_cols))
            stop("Identity transport requires every external predictor in trial X; use impute or embed for mismatch.", call. = FALSE)
        mapped_fit <- ext_fit
        prediction <- function(newX) {
            xx <- .roscar_predict_matrix(newX, trial_cols)
            ans <- .roscar_external_predict(mapped_fit, xx[, colnames(ext$X), drop = FALSE])
            ans$calibration_X <- xx; ans
        }
    } else {
        blocks <- .roscar_transport_blocks(ext, trial, shared, trial_only, external_only)
        metadata$blocks <- blocks
        if (method == "shared_only") {
            mapped_fit <- fit_external_arms(external_data(ext$X[, blocks$shared, drop = FALSE], ext_fit$A, ext$Y), ext_fit$learner)
            prediction <- function(newX) {
                xx <- .roscar_predict_matrix(newX, trial_cols)
                ans <- .roscar_external_predict(mapped_fit, xx[, blocks$shared, drop = FALSE])
                ans$calibration_X <- xx; ans
            }
        } else {
            imputation <- .roscar_fit_imputer(ext, blocks, imputer, validation_folds, seed)
            metadata$imputation_validation <- imputation$validation
            complete <- function(xx) {
                vv <- imputation$predict(xx)
                ans <- cbind(xx[, blocks$shared, drop = FALSE], vv)
                ans[, colnames(ext$X), drop = FALSE]
            }
            if (method == "impute") {
                mapped_fit <- ext_fit
                # Extend Cole Beck's build_data() with the externally learned
                # block map; no trial outcomes enter either imputation function.
                calibration_design <- function(xx) {
                    r <- list(U = xx[, blocks$trial_only, drop = FALSE], Z = xx[, blocks$shared, drop = FALSE],
                              Y = rep(0, nrow(xx)), A = rep(1, nrow(xx)))
                    o <- list(V = ext$X[, blocks$external_only, drop = FALSE], Z = ext$X[, blocks$shared, drop = FALSE],
                              Y = ext$Y, A = ext_fit$A)
                    imp <- function(has_excl, has_shr, oth_shr, oth_excl) imputation$predict(has_shr)
                    zeros <- function(has_excl, has_shr, oth_shr, oth_excl)
                        matrix(0, nrow(has_shr), length(blocks$trial_only), dimnames = list(NULL, blocks$trial_only))
                    design <- build_data(r, o, RCT_imp_method = imp, OS_imp_method = zeros)$RCT$X
                    design[, c(trial_cols, blocks$external_only), drop = FALSE]
                }
                prediction <- function(newX) {
                    xx <- .roscar_predict_matrix(newX, trial_cols)
                    ans <- .roscar_external_predict(mapped_fit, complete(xx))
                    ans$calibration_X <- calibration_design(xx); ans
                }
            } else {
                .roscar_check_learner(embedding_learner)
                if (length(pls_by_arm) != 1L || is.na(pls_by_arm) || !is.logical(pls_by_arm))
                    stop("pls_by_arm must be TRUE or FALSE.", call. = FALSE)
                if (is.null(embed_dim)) {
                    candidates <- seq_len(min(3L, ncol(ext$X), nrow(ext$X) - 1L))
                    selected <- .roscar_embedding_select(ext, ext_fit$A, embedding_learner, candidates,
                                                        validation_folds, seed, pls_by_arm)
                    embed_dim <- selected$dimension
                    metadata$embedding_validation <- selected$validation
                    metadata$embedding_folds <- selected$foldid
                } else if (length(embed_dim) != 1L || is.na(embed_dim) || !is.finite(embed_dim) ||
                           embed_dim < 1L || embed_dim != as.integer(embed_dim))
                    stop("embed_dim must be a positive integer or NULL.", call. = FALSE)
                encoder <- .roscar_fit_encoder(ext$X, ext$Y, ext_fit$A, embed_dim, pls_by_arm)
                hx <- .roscar_encode(encoder, ext$X)
                mapped_fit <- fit_external_arms(external_data(hx, ext_fit$A, ext$Y), embedding_learner)
                metadata$embed_dim <- embed_dim; metadata$actual_dimension <- encoder$dimension
                metadata$pls_by_arm <- pls_by_arm; metadata$treatment_in_encoder <- FALSE
                metadata$encoder_center <- encoder$center; metadata$encoder_scale <- encoder$scale
                prediction <- function(newX) {
                    xx <- .roscar_predict_matrix(newX, trial_cols)
                    hh <- .roscar_encode(encoder, complete(xx))
                    ans <- .roscar_external_predict(mapped_fit, hh)
                    ans$calibration_X <- xx; ans$embedding <- hh; ans
                }
            }
        }
    }
    ans <- prediction(trial$X)
    ans$predict <- prediction; ans$metadata <- metadata; ans$ext_fit <- mapped_fit
    ans$imputation <- imputation; ans$encoder <- encoder
    native_X <- if (method == "embed") .roscar_encode(encoder, ext$X) else
        if (method == "shared_only") ext$X[, blocks$shared, drop = FALSE] else ext$X
    ans$external_prediction <- .roscar_external_predict(mapped_fit, native_X)$q
    structure(ans, class = "roscar_transport")
}
