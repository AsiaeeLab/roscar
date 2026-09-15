# Tutorial pipeline. Origins: ROSCAR/R/model_roscar.R and JMLR
# R/02_all_methods_linear.R::estimate_cate_r_oscar_1arm (Asiaee et al.).

.roscar_seed <- function(seed, code) {
  if (is.null(seed)) return(force(code))
  had <- exists(".Random.seed", .GlobalEnv, inherits = FALSE)
  if (had) old <- get(".Random.seed", .GlobalEnv)
  on.exit(if (had) assign(".Random.seed", old, .GlobalEnv) else
    if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv))
  set.seed(seed)
  force(code)
}

.subset_trial <- function(trial, i) {
  out <- trial
  out$X <- trial$X[i, , drop = FALSE]
  for (nm in c("A", "Y", "pi", "p_plus", "id", "strata", "weights"))
    if (!is.null(trial[[nm]])) out[[nm]] <- trial[[nm]][i]
  out
}

.check_prediction <- function(x, n, label = "prediction") {
  x <- as.numeric(x)
  if (length(x) != n || any(!is.finite(x)))
    stop(label, " must contain one finite value per row.")
  x
}

#' Opposite-arm weighted personalized baseline
#' @param mu_cal_plus,mu_cal_minus Calibrated predictions in the positive and
#'   negative treatment arms, one value per evaluation row.
#' @param pi Probability of assignment to the positive arm, not the observed-arm
#'   probability stored in `trial$pi`; use `trial$p_plus` here.
#' @return Numeric baseline, with opposite-arm weights.
#' @export
personalized_baseline <- function(mu_cal_plus, mu_cal_minus, pi) {
  n <- length(mu_cal_plus)
  plus <- .check_prediction(mu_cal_plus, n)
  minus <- .check_prediction(mu_cal_minus, n)
  if (length(pi) == 1L) pi <- rep(pi, n)
  if (length(pi) != n || any(!is.finite(pi) | pi <= 0 | pi >= 1))
    stop("pi must give positive-arm probabilities strictly between zero and one.")
  (1 - pi) * plus + pi * minus
}

#' Randomization-based pseudo-outcome
#' @param trial Validated trial from [trial_data()].
#' @param m_hat Fixed or honestly trained baseline, one value per trial row.
#' @return Numeric `A * (Y - m_hat) / pi`, with observed-arm probability `pi`.
#' @export
pseudo_outcome <- function(trial, m_hat) {
  if (!inherits(trial, "roscar_trial")) stop("Use trial_data() for trial.")
  if (length(m_hat) == 1L) m_hat <- rep(m_hat, length(trial$Y))
  m_hat <- .check_prediction(m_hat, length(trial$Y), "m_hat")
  trial$A * (trial$Y - m_hat) / trial$pi
}

.arm_fit <- function(trial, X, arm, learner, q = NULL, scale = "mean") {
  if (!is.null(q) && scale == "mean" && identical(learner$family, "binomial"))
    stop("A binomial calibration learner requires scale = 'link'.")
  i <- which(trial$A == arm)
  if (length(unique(trial$id[i])) < 2L)
    stop("Every arm training sample needs at least two independent units.")
  off <- if (is.null(q)) NULL else q[i]
  if (scale == "link") {
    if (!all(trial$Y %in% c(0, 1))) stop("Link calibration requires binary Y.")
    if (!identical(learner$family, "binomial"))
      stop("Link calibration requires a learner with family = 'binomial'.")
    if (!is.null(off)) off <- stats::qlogis(pmin(pmax(off, 1e-6), 1 - 1e-6))
  }
  learner$fit(X[i, , drop = FALSE], trial$Y[i],
              weights = trial$weights[i], offset = off, id = trial$id[i])
}

.arm_predict <- function(model, learner, X, q = NULL, scale = "mean") {
  pred <- .check_prediction(learner$predict(model, X), nrow(X))
  if (scale == "link" || identical(learner$family, "binomial")) {
    off <- if (is.null(q)) 0 else stats::qlogis(pmin(pmax(q, 1e-6), 1 - 1e-6))
    return(stats::plogis(off + pred))
  }
  pred + if (is.null(q)) 0 else q
}

#' Cross-fit an external prediction's trial calibration
#' @param trial Validated trial.
#' @param q External arm mean prediction on every trial row, independent of trial
#'   outcomes. For link calibration these are probabilities.
#' @param arm Arm to calibrate, -1 or +1 (0 is accepted as control).
#' @param learner Discrepancy learner. For link calibration specify a binomial
#'   learner, for example `learner_ridge(family = "binomial")`.
#' @param scale Calibration on the mean scale or logistic link scale.
#' @param folds Integer labels from [make_stratified_folds()]. Copies of an ID
#'   must have the same label. At least two folds are required.
#' @param X Optional calibration design, defaulting to trial covariates.
#' @return List of held-out predictions, fitted corrections, and fold labels.
#' @export
calibrate_in_trial <- function(trial, q, arm, learner = learner_lasso(),
                               scale = c("mean", "link"), folds,
                               X = trial$X) {
  scale <- match.arg(scale)
  arm <- if (identical(as.numeric(arm), 0)) -1 else arm
  if (length(arm) != 1L || !arm %in% c(-1, 1)) stop("arm must be -1 or +1.")
  q <- .check_prediction(q, length(trial$Y), "q")
  .validate_trial_folds(trial, folds)
  prediction <- rep(NA_real_, length(q))
  fits <- list()
  for (k in sort(unique(folds))) {
    tr <- which(folds != k); te <- which(folds == k)
    model <- .arm_fit(.subset_trial(trial, tr), X[tr, , drop = FALSE], arm,
                      learner, q[tr], scale)
    prediction[te] <- .arm_predict(model, learner, X[te, , drop = FALSE], q[te], scale)
    fits[[as.character(k)]] <- model
  }
  list(prediction = prediction, fits = fits, folds = folds, learner = learner,
       scale = scale, arm = arm)
}

.validate_trial_folds <- function(trial, folds) {
  if (length(folds) != length(trial$Y) || anyNA(folds) ||
      length(unique(folds)) < 2L) stop("folds must supply at least two complete folds.")
  if (any(vapply(split(folds, trial$id), function(z) length(unique(z)) != 1L,
                 logical(1)))) stop("All copies of each id must share one fold.")
  for (k in unique(folds)) {
    t <- table(factor(trial$A[folds != k], levels = c(-1, 1)))
    if (any(t < 2L)) stop("Each fold training sample needs at least two rows per arm.")
  }
  invisible(TRUE)
}

.basis_train <- function(basis, X) {
  if (!inherits(basis, "formula") || length(basis) != 2L)
    stop("basis must be a one-sided formula, such as ~ X1 + X2.")
  mf <- stats::model.frame(basis, data = as.data.frame(X), na.action = stats::na.fail)
  tt <- attr(mf, "terms")
  if (attr(tt, "intercept") != 1L) stop("The effect basis must include an intercept.")
  mm <- stats::model.matrix(tt, mf)
  list(X = mm[, colnames(mm) != "(Intercept)", drop = FALSE], terms = tt,
       columns = colnames(mm), contrasts = attr(mm, "contrasts"))
}

.basis_predict <- function(object, X) {
  mf <- stats::model.frame(object$terms, as.data.frame(X), na.action = stats::na.fail)
  mm <- stats::model.matrix(object$terms, mf, contrasts.arg = object$contrasts)
  if (!identical(colnames(mm), object$columns)) stop("Effect basis columns changed.")
  mm[, colnames(mm) != "(Intercept)", drop = FALSE]
}

#' Fit a prespecified effect regression
#' @param trial Validated trial.
#' @param psi Honestly constructed numeric pseudo-outcomes.
#' @param basis One-sided effect formula with intercept, e.g. `~ X1 + X2`.
#'   Spline knots are fixed by the original fit for prediction and bootstrap.
#' @param offset Optional preliminary contrast on training rows. Supply its
#'   corresponding new-row values to the predict method.
#' @param learner Final squared-loss learner, unpenalized least squares by default.
#' @return An object of class `roscar_cate` with fit and fixed basis specification.
#' @export
fit_cate <- function(trial, psi, basis = ~ ., offset = NULL, learner = learner_ols()) {
  psi <- .check_prediction(psi, length(trial$Y), "psi")
  if (identical(learner$family, "binomial")) stop("Final pseudo-outcomes require squared loss.")
  if (!is.null(offset)) offset <- .check_prediction(offset, length(psi), "offset")
  b <- .basis_train(basis, trial$X)
  m <- learner$fit(b$X, psi, weights = trial$weights, offset = offset, id = trial$id)
  structure(list(model = m, learner = learner, design = b, basis = basis,
                 offset = offset, psi = psi, trial = trial), class = "roscar_cate")
}

#' @rdname fit_cate
#' @param object A fitted `roscar_cate` or `roscar_fit`.
#' @param newdata New covariate matrix/data frame; defaults to training covariates.
#' @param ... Reserved for method extensions.
#' @export
predict.roscar_cate <- function(object, newdata = object$trial$X, offset = NULL, ...) {
  if (is.null(offset) && !is.null(object$offset)) {
    if (identical(newdata, object$trial$X)) offset <- object$offset else
      stop("Supply the preliminary contrast as offset for new rows.")
  }
  p <- object$learner$predict(object$model, .basis_predict(object$design, newdata))
  p <- .check_prediction(p, nrow(newdata))
  if (!is.null(offset)) p <- p + .check_prediction(offset, length(p), "offset")
  p
}

.resolve_learners <- function(learners, seed = NULL) {
  base <- list(external = learner_lasso(seed = seed),
               calibration = learner_lasso(seed = seed),
               trial = learner_lasso(seed = seed), final = learner_ols(),
               imputer = learner_ridge(seed = seed))
  bad <- setdiff(names(learners), c(names(base), "trial_plus", "trial_minus", "rlearner"))
  if (length(bad)) stop("Unknown learner role: ", paste(bad, collapse = ", "))
  for (nm in names(learners)) base[[nm]] <- learners[[nm]]
  if (is.null(base$trial_plus)) base$trial_plus <- base$trial
  if (is.null(base$trial_minus)) base$trial_minus <- base$trial
  if (is.null(base$rlearner)) base$rlearner <- learner_lasso(seed = seed)
  base
}

#' Borrow calibrated outcome predictions for a trial CATE
#'
#' Nuisance fits and tuning exclude each evaluation unit. The final regression
#' uses all held-out pseudo-outcomes; its training predictions are not an outer
#' evaluation of CATE accuracy. Recipe C uses a preliminary-contrast offset by
#' default; direct effect regression is the default for the other recipes.
#'
#' @param trial Trial from [trial_data()], with observed-arm probabilities, IDs,
#'   strata, and optional positive analysis weights.
#' @param ext External source from [external_data()].
#' @param recipe A (matched, two arms), B (one borrowed arm), C (MR-OSCAR
#'   imputation), or D (linear CALM with externally supervised PLS).
#' @param learners Named list of external, calibration, trial, final, and imputer
#'   learners. `trial_plus` and `trial_minus` optionally override individual arms.
#' @param K Number of grouped, arm-stratified folds; default 5.
#' @param B Number of full trial bootstrap resamples; default 0; paper examples 500.
#' @param grid Matrix/data frame of target covariates; defaults to trial rows.
#' @param seed Integer seed for folds and default learners.
#' @param basis Prespecified one-sided effect formula, with intercept.
#' @param arm_ext Borrowed arm for Recipe B, default -1; 0 also means control.
#' @param method Transport comparator: `"shared_only"` implements SR-OSCAR;
#'   otherwise transport follows the selected recipe.
#' @param shared,trial_only,external_only Optional column-name covariate blocks.
#' @param embed_dim PLS dimension; NULL selects 1--3 by external validation.
#' @param pls_by_arm Fit arm-specific PLS directions instead of the pooled default.
#' @param scale Mean-scale or logistic link-scale calibration. Link calibration
#'   needs binary outcome learners and was not evaluated in the paper simulations.
#' @param offset Use the cross-fitted preliminary-contrast correction. Defaults
#'   to TRUE for Recipe C and FALSE otherwise.
#' @param folds Optional fixed grouped trial fold labels, reused across methods.
#' @param subgroups Named logical/index vectors on `grid` for average effects.
#' @param ... Additional transport settings. Unknown settings produce an error.
#' @return A `roscar_fit` with folds, heldout intermediate predictions, final
#'   model, paired `trial_only` fit, transport metadata, and optional bootstrap.
#' @export
borrow_cate <- function(trial, ext, recipe = c("A", "B", "C", "D"),
                        learners = list(), K = 5, B = 0, grid = NULL, seed = NULL,
                        basis = ~ ., arm_ext = -1, method = NULL,
                        shared = NULL, trial_only = NULL, external_only = NULL,
                        embed_dim = NULL, pls_by_arm = FALSE,
                        scale = c("mean", "link"), offset = NULL, folds = NULL,
                        subgroups = NULL, ...) {
  recipe <- match.arg(recipe); scale <- match.arg(scale)
  if (is.null(offset)) offset <- identical(recipe, "C")
  args <- list(trial = trial, ext = ext, recipe = recipe, learners = learners,
               K = K, B = 0, grid = grid, seed = seed, basis = basis, arm_ext = arm_ext,
               method = method, shared = shared, trial_only = trial_only,
               external_only = external_only, embed_dim = embed_dim,
               pls_by_arm = pls_by_arm, scale = scale, offset = offset,
               folds = NULL, subgroups = subgroups)
  dots <- list(...)
  if (length(dots)) stop("Unused arguments: ", paste(names(dots), collapse = ", "))
  .roscar_seed(seed, {
    ll <- .resolve_learners(learners, seed)
    if (scale == "mean" && identical(ll$calibration$family, "binomial"))
      stop("A binomial calibration learner requires scale = 'link'.")
    ef_ext <- ext
    if (recipe == "B") {
      arm_ext <- if (arm_ext == 0) -1 else arm_ext
      if (!arm_ext %in% c(-1, 1)) stop("arm_ext must be -1 or +1.")
      if (!is.null(ext$A)) {
        ii <- which(ext$A == arm_ext)
        if (!length(ii)) stop("The selected external arm has no observations.")
        ef_ext$X <- ext$X[ii, , drop = FALSE]; ef_ext$Y <- ext$Y[ii]
        ef_ext$A <- rep(arm_ext, length(ii))
      }
    } else if (is.null(ext$A) || length(unique(ext$A)) < 2L) {
      stop("Recipes A, C, D require both external arms; use Recipe B for one arm.")
    }
    if (identical(method, "shared_only")) {
      sh <- if (is.null(shared)) intersect(colnames(trial$X), colnames(ext$X)) else shared
      if (!length(sh)) stop("shared_only needs shared covariates.")
      ef_ext$X <- ef_ext$X[, sh, drop = FALSE]
    } else if (!is.null(method) && !method %in% c("identity", "impute", "embed"))
      stop("Unknown transport method.")
    ef <- fit_external_arms(ef_ext, ll$external, arm_ext = arm_ext)
    tm <- if (identical(method, "shared_only")) "identity" else
      switch(recipe, A = "identity", B = "identity", C = "impute", D = "embed")
    tp <- transport(ef, trial, method = tm, shared = shared,
                    trial_only = trial_only, external_only = external_only,
                    imputer = ll$imputer, embed_dim = embed_dim,
                    pls_by_arm = pls_by_arm, seed = seed)
    out <- .fit_pipeline(trial, ll, K, folds, seed, basis, offset, scale, tp,
                          recipe = recipe, arm_ext = arm_ext)
    out$ext <- ext; out$transport <- tp; out$call_args <- args
    out$subgroups <- subgroups
    if (B > 0) out$bootstrap <- bootstrap_cate(out, B, grid, seed, subgroups)
    out
  })
}

.fit_pipeline <- function(trial, ll, K, folds, seed, basis, offset, scale,
                           tp = NULL, recipe = "racer", arm_ext = -1,
                           augmentation = "racer", fixed_baseline = NULL) {
  if (!inherits(trial, "roscar_trial")) stop("Use trial_data() for trial.")
  n <- length(trial$Y)
  if (is.null(trial$weights)) trial$weights <- rep(1, n)
  if (is.null(folds)) folds <- make_stratified_folds(trial$A, K, trial$strata, trial$id, seed)
  .validate_trial_folds(trial, folds)
  arms <- c(plus = 1, minus = -1)
  cal <- rct <- matrix(NA_real_, n, 2, dimnames = list(NULL, names(arms)))
  q <- if (is.null(tp)) cal else cbind(plus = tp$q_plus, minus = tp$q_minus)
  cx <- if (is.null(tp)) trial$X else tp$calibration_X
  mods <- list()
  for (k in sort(unique(folds))) {
    tr <- which(folds != k); te <- which(folds == k)
    dat <- .subset_trial(trial, tr); fm <- list()
    for (nm in names(arms)) {
      arm <- arms[[nm]]; tl <- ll[[paste0("trial_", nm)]]
      rmod <- .arm_fit(dat, trial$X[tr, , drop = FALSE], arm, tl)
      rct[te, nm] <- .arm_predict(rmod, tl, trial$X[te, , drop = FALSE])
      borrowed <- !is.null(tp) && !all(is.na(q[, nm]))
      cmod <- NULL
      if (borrowed) {
        cmod <- .arm_fit(dat, cx[tr, , drop = FALSE], arm,
                        ll$calibration, q[tr, nm], scale)
        cal[te, nm] <- .arm_predict(cmod, ll$calibration,
                                    cx[te, , drop = FALSE], q[te, nm], scale)
      } else cal[te, nm] <- rct[te, nm]
      fm[[nm]] <- list(trial = rmod, cal = cmod, borrowed = borrowed)
    }
    mods[[as.character(k)]] <- fm
  }
  # Hybrid uncalibrated baseline retains the exact same trial-only missing arm.
  qhybrid <- q
  for (nm in names(arms)) if (all(is.na(qhybrid[, nm]))) qhybrid[, nm] <- rct[, nm]
  p <- trial$p_plus
  mcal <- personalized_baseline(cal[, 1], cal[, 2], p)
  mrct <- personalized_baseline(rct[, 1], rct[, 2], p)
  mq <- personalized_baseline(qhybrid[, 1], qhybrid[, 2], p)
  m <- if (is.null(tp)) switch(augmentation, none = rep(0, n),
             oracle = .check_prediction(fixed_baseline(trial$X), n), racer = mrct) else mcal
  psi <- pseudo_outcome(trial, m)
  tau0 <- if (offset) cal[, 1] - cal[, 2] else NULL
  final <- fit_cate(trial, psi, basis, tau0, ll$final)
  hh <- data.frame(fold = folds, A = trial$A, pi = trial$pi,
      q_plus = qhybrid[, 1], q_minus = qhybrid[, 2],
      mu_cal_plus = cal[, 1], mu_cal_minus = cal[, 2],
      mu_trial_plus = rct[, 1], mu_trial_minus = rct[, 2],
      baseline = m, pseudo_outcome = psi, baseline_trial = mrct, baseline_external = mq,
      psi_none = pseudo_outcome(trial, 0), psi_trial = pseudo_outcome(trial, mrct),
      psi_external = pseudo_outcome(trial, mq))
  out <- structure(list(trial = trial, learners = ll, folds = folds, heldout = hh,
    final = final, fold_models = mods, recipe = recipe, offset = offset,
    scale = scale, basis = basis, transport = tp, seed = seed), class = "roscar_fit")
  if (!is.null(tp) || augmentation != "racer") {
    ref <- out; ref$recipe <- "racer"; ref$transport <- NULL
    ref$heldout$baseline <- mrct; ref$heldout$pseudo_outcome <- hh$psi_trial
    ref$heldout$q_plus <- ref$heldout$mu_cal_plus <- rct[, 1]
    ref$heldout$q_minus <- ref$heldout$mu_cal_minus <- rct[, 2]
    ref$heldout$baseline_external <- mrct
    ref$heldout$psi_external <- hh$psi_trial
    ref$final <- fit_cate(trial, hh$psi_trial, basis,
                         if (offset) rct[, 1] - rct[, 2] else NULL, ll$final)
    ref$trial_only <- NULL
    ref$call_args <- list(trial = trial, learners = ll, K = K, B = 0,
      seed = seed, basis = basis, offset = offset, augmentation = "racer")
    out$trial_only <- ref
  }
  out
}

#' Trial-only pseudo-outcome CATE estimators
#' @inheritParams borrow_cate
#' @param augmentation `"racer"` uses cross-fitted trial outcome models;
#'   `"none"` uses zero baseline; `"oracle"` is for simulation benchmarks only.
#' @param fixed_baseline For oracle augmentation, a function of covariates trained
#'   without trial outcomes (usually the known population optimum in simulation).
#' @return A `roscar_fit`, with the same prediction and inference interface.
#' @export
rct_only_cate <- function(trial, learners = list(), K = 5, B = 0, grid = NULL,
                          seed = NULL, basis = ~ ., offset = FALSE, folds = NULL,
                          augmentation = c("racer", "none", "oracle"),
                          fixed_baseline = NULL, subgroups = NULL, ...) {
  augmentation <- match.arg(augmentation)
  if (length(list(...))) stop("Unused trial-only arguments.")
  if (augmentation == "oracle" && !is.function(fixed_baseline))
    stop("oracle requires fixed_baseline(X).")
  .roscar_seed(seed, {
    ll <- .resolve_learners(learners, seed)
    out <- .fit_pipeline(trial, ll, K, folds, seed, basis, offset, "mean",
                          augmentation = augmentation, recipe = augmentation,
                          fixed_baseline = fixed_baseline)
    out$call_args <- list(trial = trial, learners = learners, K = K, B = 0,
      seed = seed, basis = basis, offset = offset, augmentation = augmentation,
      fixed_baseline = fixed_baseline, subgroups = subgroups)
    out$subgroups <- subgroups
    if (B > 0) out$bootstrap <- bootstrap_cate(out, B, grid, seed, subgroups)
    out
  })
}

.preliminary_predict <- function(object, X, trial_only = FALSE) {
  z <- if (is.null(object$transport) || trial_only) NULL else object$transport$predict(X)
  all <- vapply(object$fold_models, function(fm) {
    ap <- lapply(c("plus", "minus"), function(nm) {
      if (is.null(z) || !fm[[nm]]$borrowed) {
        .arm_predict(fm[[nm]]$trial, object$learners[[paste0("trial_", nm)]], X)
      } else .arm_predict(fm[[nm]]$cal, object$learners$calibration,
                           z$calibration_X, z[[paste0("q_", nm)]], object$scale)
    })
    ap[[1]] - ap[[2]]
  }, numeric(nrow(X)))
  rowMeans(matrix(all, nrow = nrow(X)))
}

#' @rdname borrow_cate
#' @param object A fitted `roscar_fit`.
#' @param newdata New covariate matrix or data frame.
#' @export
predict.roscar_fit <- function(object, newdata = object$trial$X, ...) {
  if (!is.null(object$prediction_function)) return(object$prediction_function(newdata))
  off <- if (object$offset) .preliminary_predict(object, newdata) else NULL
  stats::predict(object$final, newdata, offset = off)
}

#' @rdname borrow_cate
#' @param x A fitted object to print.
#' @export
print.roscar_fit <- function(x, ...) {
  cat("roscar: ", x$recipe, "; ", length(x$trial$Y), " trial rows; ",
      length(unique(x$folds)), " grouped folds\n", sep = "")
  cat("Effect basis: ", paste(deparse(x$basis), collapse = " "), "\n", sep = "")
  cat("Mean fitted effect: ", format(mean(stats::predict(x)), digits = 5), "\n", sep = "")
  if (!is.null(x$bootstrap)) cat("Bootstrap: ", x$bootstrap$successful, "/",
                                x$bootstrap$attempted, " successful\n", sep = "")
  invisible(x)
}
