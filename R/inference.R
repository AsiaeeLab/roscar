# Conditional case bootstrap, extending JMLR R/06_diagnostic.R::bootstrap_mean_ci.

.resample_units <- function(trial) {
  ids <- unique(as.character(trial$id))
  rows <- split(seq_along(trial$id), factor(as.character(trial$id), levels = ids))
  gs <- vapply(rows, function(i) as.character(trial$strata[i[1]]), character(1))
  draw <- unlist(lapply(split(seq_along(ids), gs), function(j)
    j[sample.int(length(j), length(j), replace = TRUE)]), use.names = FALSE)
  unlist(rows[draw], use.names = FALSE)
}

.rerun_fit <- function(fit, trial, seed) {
  if (!is.null(fit$refit)) return(fit$refit(trial, seed))
  a <- fit$call_args
  if (is.null(a)) stop("This fit lacks a reproducible pipeline specification.")
  a$trial <- trial; a$B <- 0; a$seed <- seed; a$folds <- NULL
  # Preserve the original prespecified basis, including fitted spline knots.
  a$basis <- fit$final$design$terms
  if (!is.null(fit$transport)) {
    tp <- fit$transport
    zz <- tp$predict(trial$X)
    for (nm in names(zz)) tp[[nm]] <- zz[[nm]]
    out <- .roscar_seed(seed, .fit_pipeline(trial, fit$learners, a$K, NULL,
      seed, a$basis, a$offset, a$scale, tp, fit$recipe, a$arm_ext))
    out$ext <- fit$ext; out$transport <- tp; out$call_args <- a
    out
  } else do.call(rct_only_cate, a[setdiff(names(a), c("ext"))])
}

.diagnostic_values <- function(fit, groups = NULL) {
  h <- fit$heldout; t <- fit$trial
  if (is.null(h)) return(numeric())
  mu_t <- ifelse(t$A == 1, h$mu_trial_plus, h$mu_trial_minus)
  mu_c <- ifelse(t$A == 1, h$mu_cal_plus, h$mu_cal_minus)
  d <- (t$Y - mu_t)^2 - (t$Y - mu_c)^2
  weighted <- (1 - t$pi)^2 * d
  aa <- if (!is.null(fit$call_args$arm_ext)) fit$call_args$arm_ext else -1
  if (aa == 0) aa <- -1
  selectors <- list(pooled = rep(TRUE, length(d)))
  if (!is.null(groups)) for (g in unique(as.character(groups)))
    selectors[[paste0("group:", g)]] <- as.character(groups) == g
  unlist(lapply(selectors, function(idx) {
    controls <- idx & t$A == aa
    c(weighted = mean(weighted[idx]),
      control = if (any(controls)) mean(d[controls]) else NA_real_)
  }))
}

.interval_table <- function(point, draws, reference_point = NULL, reference_draws = NULL,
                            alpha = 0.05) {
  quant <- function(dd) {
    if (is.null(dim(dd))) dd <- matrix(dd, ncol = 1L)
    t(vapply(seq_len(ncol(dd)), function(j) {
      v <- dd[, j]; v <- v[is.finite(v)]
      if (length(v) < 2L) return(c(NA_real_, NA_real_))
      unname(stats::quantile(v, c(alpha / 2, 1 - alpha / 2)))
    }, numeric(2)))
  }
  ci <- quant(draws)
  out <- data.frame(estimate = point, lower = ci[, 1], upper = ci[, 2],
                    width = ci[, 2] - ci[, 1])
  if (!is.null(reference_draws)) {
    rr <- quant(reference_draws)
    out$trial_estimate <- reference_point
    out$trial_lower <- rr[, 1]; out$trial_upper <- rr[, 2]
    out$trial_width <- rr[, 2] - rr[, 1]
    out$width_ratio <- ifelse(out$trial_width > 0, out$width / out$trial_width, NA_real_)
  }
  out
}

.subgroup_indices <- function(subgroups, n) {
  if (is.null(subgroups)) return(NULL)
  if (!is.list(subgroups) || is.null(names(subgroups)) || any(!nzchar(names(subgroups))))
    stop("subgroups must be a named list of row selectors on grid.")
  lapply(subgroups, function(i) {
    if (is.logical(i)) {
      if (length(i) != n || anyNA(i)) stop("Logical subgroup selectors must match grid.")
      i <- which(i)
    }
    if (!is.numeric(i) || !length(i) || anyNA(i) || any(i != as.integer(i)) ||
        any(i < 1 | i > n) || anyDuplicated(i)) stop("Invalid or empty subgroup selector.")
    as.integer(i)
  })
}

#' Conditional full-pipeline bootstrap for trial CATEs
#'
#' Resamples independent trial IDs within design strata, keeping the external
#' data and its fits fixed. All copies of a selected ID share cross-fitting and
#' tuning folds. Failed resamples are retained as failures and are not retried.
#' Intervals use successful paired resamples and are pointwise percentile
#' intervals conditional on the external prediction resource.
#' @param fit Fitted `roscar_fit`.
#' @param B Number of attempted case bootstrap resamples, at least two.
#' @param grid Fixed covariate matrix/data frame for prediction; defaults to the
#'   original trial rows (standardization to their empirical distribution).
#' @param seed Bootstrap seed.
#' @param subgroups Named logical/index vectors selecting rows of grid.
#' @param alpha Two-sided interval error probability, default 0.05.
#' @param groups Optional labels on original trial rows for diagnostic summaries.
#' @return List with intervals, paired draws, subgroup intervals/draws, diagnostic
#'   draws, resampling/fold audit, failures, attempted and successful counts.
#' @export
bootstrap_cate <- function(fit, B = 500, grid = NULL, seed = NULL,
                            subgroups = NULL, alpha = 0.05, groups = NULL) {
  if (!inherits(fit, "roscar_fit")) stop("fit must be a roscar_fit.")
  if (length(B) != 1L || is.na(B) || B < 2 || B != as.integer(B))
    stop("B must be an integer of at least two.")
  if (length(alpha) != 1L || !is.finite(alpha) || alpha <= 0 || alpha >= 1)
    stop("alpha must lie between zero and one.")
  if (is.null(grid)) grid <- fit$trial$X
  grid <- .roscar_matrix(grid)
  if (!is.null(groups) && (length(groups) != length(fit$trial$Y) || anyNA(groups)))
    stop("groups must contain one label per original trial row.")
  sg <- .subgroup_indices(subgroups, nrow(grid))
  .roscar_seed(seed, {
    # Generate every resampling index before model fitting changes RNG state.
    indices <- replicate(B, .resample_units(fit$trial), simplify = FALSE)
    seeds <- sample.int(.Machine$integer.max, B)
    draws <- reference <- matrix(NA_real_, B, nrow(grid))
    d0 <- .diagnostic_values(fit, groups)
    diagnostic <- matrix(NA_real_, B, length(d0), dimnames = list(NULL, names(d0)))
    failures <- rep(NA_character_, B); fold_audit <- vector("list", B)
    for (b in seq_len(B)) {
      i <- indices[[b]]
      ans <- tryCatch({
        z <- .rerun_fit(fit, .subset_trial(fit$trial, i), seeds[b])
        pr <- .check_prediction(stats::predict(z, grid), nrow(grid), "bootstrap prediction")
        rf <- if (is.null(z$trial_only)) z else z$trial_only
        rp <- .check_prediction(stats::predict(rf, grid), nrow(grid), "bootstrap reference prediction")
        dv <- .diagnostic_values(z, if (is.null(groups)) NULL else groups[i])
        list(z = z, pr = pr, rp = rp, dv = dv)
      }, error = function(e) e)
      if (inherits(ans, "error")) {
        failures[b] <- conditionMessage(ans)
      } else {
        draws[b, ] <- ans$pr; reference[b, ] <- ans$rp
        common <- intersect(names(ans$dv), colnames(diagnostic))
        diagnostic[b, common] <- ans$dv[common]
        fold_audit[[b]] <- data.frame(original_row = i,
          id = fit$trial$id[i], fold = ans$z$folds)
      }
    }
    success <- which(is.na(failures))
    ref_fit <- if (is.null(fit$trial_only)) fit else fit$trial_only
    point <- stats::predict(fit, grid); rp <- stats::predict(ref_fit, grid)
    intervals <- .interval_table(point, draws, rp, reference, alpha)
    sd <- sr <- si <- NULL
    if (length(sg)) {
      sd <- vapply(sg, function(i) rowMeans(draws[, i, drop = FALSE]), numeric(B))
      sr <- vapply(sg, function(i) rowMeans(reference[, i, drop = FALSE]), numeric(B))
      sp <- vapply(sg, function(i) mean(point[i]), numeric(1))
      rs <- vapply(sg, function(i) mean(rp[i]), numeric(1))
      si <- .interval_table(sp, sd, rs, sr, alpha); si$subgroup <- names(sg)
    }
    structure(list(intervals = intervals, draws = draws, trial_draws = reference,
      subgroups = si, subgroup_draws = sd, trial_subgroup_draws = sr,
      diagnostic_draws = diagnostic, diagnostic_point = d0, groups = groups,
      attempted = B, successful = length(success), successful_indices = success,
      failures = data.frame(resample = which(!is.na(failures)),
                             message = failures[!is.na(failures)]),
      fold_audit = fold_audit, seeds = seeds, grid = grid, alpha = alpha,
      interval_method = "pointwise conditional trial percentile bootstrap",
      external_fixed = TRUE), class = "roscar_bootstrap")
  })
}

#' Bootstrap interval for a mean
#' @param x Finite numeric values; missing values are omitted.
#' @param B Number of bootstrap draws.
#' @param alpha Error probability.
#' @param seed Random seed.
#' @param id,strata Independent units and design strata.
#' @param one_sided Return a one-sided lower bound and infinite upper bound.
#' @return Named vector lower and upper. This helper resamples fixed values;
#'   use [diagnose()] for full nuisance refitting in borrowing diagnostics.
#' @export
bootstrap_mean_ci <- function(x, B = 1000, alpha = 0.05, seed = NULL,
                               id = seq_along(x), strata = rep("all", length(x)),
                               one_sided = FALSE) {
  if (length(id) != length(x) || length(strata) != length(x)) stop("Lengths differ.")
  keep <- is.finite(x)
  x <- x[keep]; id <- id[keep]; strata <- strata[keep]
  if (!length(x) || B < 2) return(c(lower = NA_real_, upper = NA_real_))
  if (any(vapply(split(strata, id), function(z) length(unique(z)) != 1L, logical(1))))
    stop("IDs cannot cross strata.")
  .roscar_seed(seed, {
    b <- replicate(B, mean(x[.resample_units(list(id = id, strata = strata))]))
    c(lower = unname(stats::quantile(b, if (one_sided) alpha else alpha / 2)),
      upper = if (one_sided) Inf else unname(stats::quantile(b, 1 - alpha / 2)))
  })
}

#' Approximate fixed-nuisance sandwich covariance
#'
#' This clustered HC0 sandwich conditions on all learned nuisance stages and
#' any offset. It is an approximation and does not replace the full bootstrap.
#' Only an unpenalized, full-rank final linear regression is supported.
#' @param object A `roscar_fit` with an OLS final learner.
#' @param ... Unused.
#' @return Covariance matrix for the effect correction coefficients, with an
#'   attribute identifying the fixed-nuisance approximation.
#' @export
vcov.roscar_fit <- function(object, ...) {
  if (!is.null(object$prediction_function) && object$recipe != "rlearner")
    stop("A coefficient sandwich for this comparator is not implemented; use its reported interval method.")
  f <- object$final
  if (is.null(f) || !identical(f$learner$name, "ols") || f$learner$family != "gaussian")
    stop("The sandwich requires an unpenalized Gaussian linear final regression.")
  X <- cbind(`(Intercept)` = 1, f$design$X)
  w <- f$trial$weights; if (is.null(w)) w <- rep(1, nrow(X))
  e <- f$psi - stats::predict(f)
  bread <- tryCatch(solve(crossprod(X, w * X)), error = function(e)
    stop("The final design is rank deficient; sandwich unavailable."))
  score <- rowsum(X * (w * e), f$trial$id, reorder = FALSE)
  vv <- bread %*% crossprod(score) %*% bread
  attr(vv, "method") <- "clustered HC0; nuisance stages and offset treated as fixed (approximation)"
  vv
}
