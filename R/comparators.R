#' Compare trial and external-prediction effect estimators
#'
#' All methods predict the same supplied grid and use the same prespecified
#' effect basis where applicable. The R-learner fits a cross-fitted trial outcome
#' nuisance and regresses outcome residuals on randomized treatment residuals.
#' Causal forest uses grf's own pointwise variance estimates. Other methods use
#' the conditional case bootstrap when B is positive; B = 0 computes no interval.
#' Failures and unsupported configurations are returned explicitly.
#' @inheritParams borrow_cate
#' @param methods Names from `none`, `racer`, `uncalibrated`, `oracle`,
#'   `interaction_ols`, `rlearner`, `causal_forest`, `procova_interaction`,
#'   `pooled`, `A`, `B`, `C`, `D`, `shared_only`.
#' @param oracle_baseline Known baseline function of trial covariates, simulations only.
#' @return Named list; each method has `fit`, `prediction`, `interval`,
#'   `subgroups`, `status`, `error`, and `interval_method`.
#' @export
compare_methods <- function(trial, ext = NULL,
                            methods = c("none", "racer", "A"),
                            grid = trial$X, basis = ~ ., learners = list(),
                            K = 5, B = 0, seed = NULL, subgroups = NULL,
                            oracle_baseline = NULL, ...) {
  known <- c("none", "racer", "uncalibrated", "oracle", "interaction_ols", "rlearner",
             "causal_forest", "procova_interaction", "pooled", "A", "B", "C", "D", "shared_only")
  if (any(!methods %in% known)) stop("Unknown method(s): ", paste(setdiff(methods, known), collapse = ", "))
  if (anyDuplicated(methods)) stop("methods must be unique.")
  ll <- .resolve_learners(learners, seed)
  folds <- make_stratified_folds(trial$A, K, trial$strata, trial$id, seed)
  extra <- list(...)
  fitted <- list()
  for (method in methods) {
    result <- tryCatch({
      fit <- if (method %in% c("none", "racer", "oracle")) {
        rct_only_cate(trial, learners, K, seed = seed, basis = basis, folds = folds,
                       augmentation = method, fixed_baseline = oracle_baseline)
      } else if (method %in% c("A", "B", "C", "D", "shared_only", "uncalibrated")) {
        rec <- method
        if (method == "shared_only") rec <- "C"
        if (method == "uncalibrated") rec <- if (is.null(ext$A) || length(unique(ext$A)) == 1L) "B" else
          if (all(colnames(ext$X) %in% colnames(trial$X))) "A" else "C"
        ar <- c(list(trial = trial, ext = ext, recipe = rec, learners = learners,
                     K = K, seed = seed, basis = basis, folds = folds), extra)
        if (method == "shared_only") ar$method <- "shared_only"
        z <- do.call(borrow_cate, ar)
        if (method == "uncalibrated") z <- .uncalibrated_fit(z)
        z
      } else .comparison_fit(trial, ext, method, ll, K, folds, seed, basis)
      pred <- stats::predict(fit, grid)
      interval_method <- "not computed (B = 0)"
      ints <- data.frame(estimate = pred, lower = NA_real_, upper = NA_real_,
                         width = NA_real_, width_ratio = NA_real_)
      subs <- NULL
      if (method == "causal_forest") {
        pp <- stats::predict(fit$forest, as.matrix(grid), estimate.variance = TRUE, num.threads = 1)
        se <- sqrt(pmax(0, pp$variance.estimates))
        ints$lower <- pred - stats::qnorm(.975) * se
        ints$upper <- pred + stats::qnorm(.975) * se
        ints$width <- ints$upper - ints$lower
        interval_method <- "grf pointwise asymptotic normal interval"
      } else if (B > 0) {
        fit$bootstrap <- bootstrap_cate(fit, B, grid, seed, subgroups)
        ints <- fit$bootstrap$intervals; subs <- fit$bootstrap$subgroups
        interval_method <- fit$bootstrap$interval_method
      }
      if (is.null(subs) && length(subgroups)) {
        sg <- .subgroup_indices(subgroups, nrow(grid))
        subs <- data.frame(subgroup = names(sg),
          estimate = vapply(sg, function(i) mean(pred[i]), numeric(1)),
          lower = NA_real_, upper = NA_real_)
      }
      list(fit = fit, prediction = pred, interval = ints, subgroups = subs,
           status = "success", error = NA_character_, interval_method = interval_method)
    }, error = function(e) list(fit = NULL, prediction = rep(NA_real_, nrow(grid)),
       interval = NULL, subgroups = NULL,
       status = if (grepl("Install|unavailable|requires shared|rank deficient", conditionMessage(e))) "unavailable" else "failed",
       error = conditionMessage(e), interval_method = "unavailable"))
    fitted[[method]] <- result
  }
  fitted
}

.uncalibrated_fit <- function(z) {
  z$recipe <- "uncalibrated"; z$offset <- FALSE
  z$heldout$baseline <- z$heldout$baseline_external
  z$heldout$pseudo_outcome <- z$heldout$psi_external
  z$heldout$mu_cal_plus <- z$heldout$q_plus
  z$heldout$mu_cal_minus <- z$heldout$q_minus
  z$final <- fit_cate(z$trial, z$heldout$psi_external, z$basis, learner = z$learners$final)
  base <- z; base$refit <- NULL
  z$refit <- function(trial, seed) .uncalibrated_fit(.rerun_fit(base, trial, seed))
  z
}

.comparison_fit <- function(trial, ext, method, ll, K, folds, seed, basis,
                            external_resource = NULL) {
  ref <- rct_only_cate(trial, learners = ll, K = K, seed = seed, basis = basis, folds = folds)
  out <- ref; out$recipe <- method; out$trial_only <- ref
  if (is.null(trial$weights)) trial$weights <- rep(1, length(trial$Y))
  if (method == "rlearner") {
    pred_y <- rep(NA_real_, length(trial$Y))
    for (k in unique(folds)) {
      tr <- which(folds != k); te <- which(folds == k)
      # Penalized outcome nuisance, with known randomized propensity.
      nuisance <- ll$rlearner
      model <- nuisance$fit(trial$X[tr, , drop = FALSE], trial$Y[tr],
                             weights = trial$weights[tr], id = trial$id[tr])
      pred_y[te] <- nuisance$predict(model, trial$X[te, , drop = FALSE])
    }
    wres <- as.numeric(trial$A == 1) - trial$p_plus
    dat <- trial; dat$weights <- trial$weights * wres^2
    ff <- fit_cate(dat, (trial$Y - pred_y) / wres, basis, learner = ll$final)
    out$final <- ff
    out$prediction_function <- function(X) stats::predict(ff, X)
  } else if (method == "causal_forest") {
    if (!requireNamespace("grf", quietly = TRUE)) stop("Install grf for causal_forest.")
    if (anyDuplicated(trial$id)) {
      forest <- grf::causal_forest(trial$X, trial$Y, as.numeric(trial$A == 1),
        W.hat = trial$p_plus, clusters = as.integer(factor(trial$id)),
        sample.weights = trial$weights, seed = if (is.null(seed)) 42L else seed, num.threads = 1)
    } else forest <- grf::causal_forest(trial$X, trial$Y, as.numeric(trial$A == 1),
        W.hat = trial$p_plus, sample.weights = trial$weights,
        seed = if (is.null(seed)) 42L else seed, num.threads = 1)
    out$forest <- forest
    out$prediction_function <- function(X) as.numeric(stats::predict(forest, as.matrix(X), num.threads = 1)$predictions)
  } else {
    b <- .basis_train(basis, trial$X)
    bx <- cbind(`(Intercept)` = 1, b$X)
    nx <- trial$X; Y <- trial$Y; A <- as.numeric(trial$A == 1)
    ww <- trial$weights; study <- NULL; prog <- NULL
    if (method == "procova_interaction") {
      if (is.null(ext)) stop("procova_interaction requires external data.")
      sh <- intersect(colnames(trial$X), colnames(ext$X))
      if (!length(sh)) stop("procova_interaction requires shared covariates.")
      ex <- ext; ex$X <- ext$X[, sh, drop = FALSE]
      if (is.null(external_resource)) {
        ef <- fit_external_arms(ex, ll$external)
        external_resource <- transport(ef, trial, "identity")
      }
      native <- external_resource$predict(trial$X)
      q <- cbind(native$q_plus, native$q_minus)
      prog <- rowMeans(q, na.rm = TRUE)
      nx <- cbind(b$X, external_prognosis = prog)
    }
    if (method == "pooled") {
      if (is.null(ext)) stop("pooled requires external data.")
      required <- colnames(trial$X)
      if (!all(required %in% colnames(ext$X))) stop("pooled unavailable: effect and outcome covariates must be shared.")
      ex <- ext$X[, required, drop = FALSE]
      nx <- rbind(nx, ex); Y <- c(Y, ext$Y)
      A <- c(A, if (is.null(ext$A)) rep(0, length(ext$Y)) else as.numeric(ext$A == 1))
      bx <- rbind(bx, cbind(1, .basis_predict(b, ex)))
      study <- c(rep(0, length(trial$Y)), rep(1, length(ext$Y)))
      ww <- c(ww, rep(1, length(ext$Y)))
    }
    # Every treatment interaction needs its corresponding outcome main term,
    # including transformed basis terms such as sin(X). Otherwise a shared
    # nonlinear prognosis can be misallocated to an A=1 interaction.
    main <- cbind(bx, nx)
    if (!is.null(study)) main <- cbind(main, study = study)
    # A linear external score can be redundant with declared basis main effects.
    # Remove only redundant nuisance columns; every effect interaction is kept.
    qr_main <- qr(main)
    if (qr_main$rank < ncol(main))
      main <- main[, qr_main$pivot[seq_len(qr_main$rank)], drop = FALSE]
    design <- cbind(main, bx * A)
    lmfit <- stats::lm.wfit(design, Y, w = ww)
    if (lmfit$rank < ncol(design)) stop("Comparison outcome design is rank deficient: the declared treatment interactions are not identifiable; retain the unavailable result or prespecify a simpler basis.")
    effect_co <- utils::tail(lmfit$coefficients, ncol(bx))
    out$outcome_model <- lmfit
    out$prediction_function <- function(X) as.numeric(cbind(1, .basis_predict(b, X)) %*% effect_co)
  }
  # Refit the whole comparator and its paired RACER on the same bootstrap trial.
  out$refit <- function(dat, s) .comparison_fit(dat, ext, method, ll, K,
           make_stratified_folds(dat$A, K, dat$strata, dat$id, s), s,
           out$final$design$terms, external_resource = external_resource)
  out
}
