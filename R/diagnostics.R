# Prediction diagnostics port the weighted statistic from JMLR
# r-oscar/R/06_diagnostic.R::borrow_diagnostic and borrow_diagnostic_1arm.
# Unlike its fixed-score bootstrap, reported bounds here refit trial nuisances.

.calibration_bins <- function(pred, y, arm, stage, bins, binary) {
  breaks <- unique(stats::quantile(pred, seq(0, 1, length.out = bins + 1), names = FALSE))
  grp <- if (length(breaks) < 2) rep(1L, length(pred)) else
    cut(pred, breaks, include.lowest = TRUE, labels = FALSE)
  do.call(rbind, lapply(split(seq_along(y), grp), function(i) {
    nn <- length(i); yy <- mean(y[i]); pp <- mean(pred[i])
    if (binary) {
      zz <- stats::qnorm(.975); den <- 1 + zz^2 / nn
      center <- (yy + zz^2 / (2 * nn)) / den
      half <- zz * sqrt(yy * (1 - yy) / nn + zz^2 / (4 * nn^2)) / den
      lo <- center - half; hi <- center + half
    } else {
      se <- if (nn > 1) stats::sd(y[i]) / sqrt(nn) else NA_real_
      lo <- yy - stats::qnorm(.975) * se; hi <- yy + stats::qnorm(.975) * se
    }
    data.frame(arm = arm, stage = stage, n = nn, predicted = pp,
                observed = yy, lower = lo, upper = hi)
  }))
}

.support_summary <- function(X, source) {
  continuous <- categorical <- list()
  for (nm in colnames(X)) {
    x <- X[, nm]
    if (length(unique(x)) <= 10) {
      z <- as.data.frame(table(x), stringsAsFactors = FALSE)
      names(z) <- c("level", "n"); z$covariate <- nm; z$source <- source
      categorical[[nm]] <- z
    } else {
      q <- stats::quantile(x, c(0, .1, .25, .5, .75, .9, 1), names = FALSE)
      continuous[[nm]] <- data.frame(source = source, covariate = nm,
                    min = q[1], p10 = q[2], p25 = q[3], median = q[4],
                    p75 = q[5], p90 = q[6], max = q[7])
    }
  }
  list(continuous = if (length(continuous)) do.call(rbind, continuous) else data.frame(),
       categorical = if (length(categorical)) do.call(rbind, categorical) else data.frame())
}

#' Inspect honest outcome predictions and borrowing diagnostics
#' @param fit A fitted `roscar_fit` from [borrow_cate()].
#' @param B Full trial-refitting bootstrap resamples for diagnostic bounds.
#'   Default zero uses an existing stored bootstrap or returns uncomputed bounds.
#' @param seed Seed for diagnostic bootstrap.
#' @param groups Optional site/subgroup labels on trial rows. Pooled results are
#'   always returned; subgroup bounds use the same resampled full pipeline.
#' @param bins Number of quantile bins for calibration, default five.
#' @return A `roscar_diagnostics` list: source support summaries, prognostic score
#'   densities, aggregate calibration bins, row-level residuals and losses,
#'   four-baseline pseudo-outcome variances, arm losses, borrowing table, width
#'   ratios, and negative-transfer flag. Row-level elements must not be exported
#'   from protected-data analyses. Bounds are diagnostic prediction evidence,
#'   not a test of CATE validity or a proven variance reduction.
#' @export
diagnose <- function(fit, B = 0, seed = fit$seed, groups = NULL, bins = 5) {
  h <- fit$heldout; t <- fit$trial
  if (is.null(h)) stop("This fit has no held-out arm predictions.")
  if (length(bins) != 1 || !is.finite(bins) || bins < 1) stop("bins must be positive.")
  binary <- all(t$Y %in% c(0, 1))
  calibration <- do.call(rbind, lapply(c(-1, 1), function(a) {
    i <- which(t$A == a); nm <- if (a == 1) "plus" else "minus"
    rbind(.calibration_bins(h[[paste0("q_", nm)]][i], t$Y[i], a, "external", bins, binary),
          .calibration_bins(h[[paste0("mu_cal_", nm)]][i], t$Y[i], a, "calibrated", bins, binary),
          .calibration_bins(h[[paste0("mu_trial_", nm)]][i], t$Y[i], a, "trial_only", bins, binary))
  }))
  mu_t <- ifelse(t$A == 1, h$mu_trial_plus, h$mu_trial_minus)
  mu_c <- ifelse(t$A == 1, h$mu_cal_plus, h$mu_cal_minus)
  mu_q <- ifelse(t$A == 1, h$q_plus, h$q_minus)
  row_loss <- data.frame(A = t$A, trial = (t$Y - mu_t)^2,
                         external = (t$Y - mu_q)^2, calibrated = (t$Y - mu_c)^2)
  row_loss$difference <- row_loss$trial - row_loss$calibrated
  row_loss$weighted_difference <- (1 - t$pi)^2 * row_loss$difference
  arm_losses <- stats::aggregate(row_loss[, c("trial", "external", "calibrated")],
                                   list(arm = t$A), mean)
  variance <- data.frame(baseline = c("none", "trial_only", "external", "calibrated"),
    variance = vapply(h[, c("psi_none", "psi_trial", "psi_external", "pseudo_outcome")],
                      stats::var, numeric(1)), row.names = NULL)
  supp <- list(trial = .support_summary(t$X, "trial"))
  if (!is.null(fit$ext)) supp$external <- .support_summary(fit$ext$X, "external")
  densities <- list()
  available <- c("plus", "minus")
  if (!is.null(fit$transport$external_prediction)) {
    native <- fit$transport$external_prediction
    available <- colnames(native)[colSums(is.finite(native)) > 0]
  }
  score_t <- rowMeans(h[, paste0("q_", available), drop = FALSE])
  if (stats::sd(score_t) > 0) {
    dd <- stats::density(score_t)
    densities$trial <- data.frame(source = "trial", score = dd$x, density = dd$y)
  }
  # Score external rows in their own observed representation when possible.
  if (!is.null(fit$transport$external_prediction)) {
    qe <- fit$transport$external_prediction
    score_e <- rowMeans(qe, na.rm = TRUE)
    if (all(is.finite(score_e)) && stats::sd(score_e) > 0) {
      dd <- stats::density(score_e)
      densities$external <- data.frame(source = "external", score = dd$x, density = dd$y)
    }
  }
  boot <- fit$bootstrap
  if (B > 0 && (is.null(boot) || boot$attempted != B || !identical(groups, boot$groups)))
    boot <- bootstrap_cate(fit, B, grid = t$X[1, , drop = FALSE], seed = seed, groups = groups)
  val <- .diagnostic_values(fit, groups)
  gn <- sub("\\.weighted$", "", names(val)[grepl("\\.weighted$", names(val))])
  bt <- do.call(rbind, lapply(gn, function(g) {
    wn <- paste0(g, ".weighted"); cn <- paste0(g, ".control")
    wd <- cd <- numeric()
    if (!is.null(boot)) {
      if (wn %in% colnames(boot$diagnostic_draws)) wd <- boot$diagnostic_draws[, wn]
      if (cn %in% colnames(boot$diagnostic_draws)) cd <- boot$diagnostic_draws[, cn]
    }
    quant <- function(x, p) if (sum(is.finite(x)) >= 2) unname(stats::quantile(x[is.finite(x)], p)) else NA_real_
    idx <- if (g == "pooled") rep(TRUE, length(t$Y)) else as.character(groups) == sub("^group:", "", g)
    data.frame(group = sub("^group:", "", g), n = sum(idx), estimate = val[[wn]],
      lower_bound = quant(wd, .05), control_estimate = val[[cn]],
      control_lower = quant(cd, .025), control_upper = quant(cd, .975))
  }))
  negative <- variance$variance[4] > variance$variance[2] ||
    any(is.finite(bt$lower_bound) & bt$estimate < 0)
  structure(list(support = supp, prognosis_density = densities,
    calibration_binned = calibration, calibration = calibration,
    residuals = data.frame(A = t$A, baseline_risk = mu_q,
                            residual = t$Y - mu_c, as.data.frame(t$X)),
    variance = variance, pseudo_outcome_variances = variance,
    row_loss = row_loss, arm_losses = arm_losses,
    borrowing = list(table = bt, bootstrap = boot,
      method = "opposite-arm squared-probability weighted held-out loss difference; full trial refitting"),
    width_ratios = if (!is.null(fit$bootstrap)) fit$bootstrap$intervals$width_ratio else NULL,
    negative_transfer = negative), class = "roscar_diagnostics")
}

#' @rdname diagnose
#' @param x A diagnostics object.
#' @param ... Additional graphical arguments (reserved).
#' @export
plot.roscar_diagnostics <- function(x, ...) {
  old <- graphics::par(mfrow = c(2, 2), mar = c(4, 4, 2.3, 1),
                        family = "sans", cex = .8)
  on.exit(graphics::par(old))
  cols <- c(external = "#7F8C8D", calibrated = "#E67E22", trial_only = "#1B4F72")
  cc <- x$calibration_binned
  lim <- range(c(cc$predicted, cc$observed, cc$lower, cc$upper), na.rm = TRUE)
  graphics::plot(cc$predicted, cc$observed, col = cols[cc$stage], pch = ifelse(cc$arm == 1, 16, 17),
    xlim = lim, ylim = lim, xlab = "Predicted outcome", ylab = "Observed mean",
    main = "A  Outcome Calibration")
  graphics::segments(cc$predicted, cc$lower, cc$predicted, cc$upper, col = cols[cc$stage])
  graphics::abline(0, 1, lty = 2, col = "#7F8C8D")
  graphics::legend("topleft", names(cols), col = cols, pch = 16, bty = "n", cex = .7)
  vv <- x$variance
  graphics::barplot(vv$variance, names.arg = c("None", "Trial", "External", "Calibrated"),
    col = c("#7F8C8D", "#1B4F72", "#85C1E9", "#E67E22"), border = NA,
    ylab = "Pseudo-outcome variance", main = "B  Baseline Comparison")
  rr <- x$residuals
  graphics::plot(rr$baseline_risk, rr$residual, pch = 16, col = grDevices::adjustcolor("#1B4F72", .5),
    xlab = "External predicted risk", ylab = "Calibration residual", main = "C  Residual Pattern")
  graphics::abline(h = 0, lty = 2, col = "#7F8C8D")
  bt <- x$borrowing$table
  lim <- range(c(0, bt$estimate, bt$lower_bound), na.rm = TRUE)
  if (diff(lim) == 0) lim <- lim + c(-1, 1)
  graphics::plot(seq_len(nrow(bt)), bt$estimate, ylim = lim, xaxt = "n", pch = 16,
    col = "#E67E22", xlab = "Analysis group", ylab = "Weighted loss improvement",
    main = "D  Borrowing Diagnostic")
  graphics::axis(1, seq_len(nrow(bt)), bt$group)
  graphics::segments(seq_len(nrow(bt)), bt$lower_bound, seq_len(nrow(bt)), bt$estimate,
                      col = "#E67E22")
  graphics::abline(h = 0, lty = 2, col = "#7F8C8D")
  invisible(x)
}

#' Compatibility wrappers for JMLR borrowing diagnostics
#' @param X_rct,A_rct,Y_rct Trial covariates, treatment, and outcomes.
#' @param propensity_rct Probability of assignment to treatment +1 (legacy
#'   convention, unlike observed-arm `trial_data(pi=)` input).
#' @param X_obs,A_obs,Y_obs External covariates, treatment, and outcomes.
#' @param K Number of trial folds.
#' @param B Full trial bootstrap resamples.
#' @param alpha Error probability; these wrappers currently support 0.05.
#' @param seed Random seed.
#' @return Legacy fields decision, D_mean, CI, D_per_subject, plus diagnostics.
#' @export
borrow_diagnostic <- function(X_rct, A_rct, Y_rct, propensity_rct,
                               X_obs, A_obs, Y_obs, K = 5, B = 1000,
                               alpha = .05, seed = NULL) {
  if (alpha != .05) stop("Use bootstrap_cate(alpha=) for a different confidence level.")
  ar <- .roscar_arm(A_rct)
  tr <- trial_data(X_rct, ar, Y_rct, pi = ifelse(ar == 1, propensity_rct, 1 - propensity_rct))
  ex <- external_data(X_obs, A_obs, Y_obs)
  f <- borrow_cate(tr, ex, "A", K = K, seed = seed)
  dg <- diagnose(f, B, seed)
  tt <- dg$borrowing$table[1, ]
  list(decision = if (is.finite(tt$lower_bound) && tt$lower_bound > 0) "R-OSCAR" else "RACER",
       D_mean = tt$estimate, CI = c(lower = tt$lower_bound, upper = Inf),
       D_per_subject = dg$row_loss$weighted_difference, diagnostics = dg)
}

#' @rdname borrow_diagnostic
#' @param X_obs_control,Y_obs_control External control data.
#' @export
borrow_diagnostic_1arm <- function(X_rct, A_rct, Y_rct, propensity_rct,
                                    X_obs_control, Y_obs_control, K = 5, B = 1000,
                                    alpha = .05, seed = NULL) {
  if (alpha != .05) stop("Use bootstrap_cate(alpha=) for a different confidence level.")
  ar <- .roscar_arm(A_rct)
  tr <- trial_data(X_rct, ar, Y_rct, pi = ifelse(ar == 1, propensity_rct, 1 - propensity_rct))
  ex <- external_data(X_obs_control, Y = Y_obs_control)
  f <- borrow_cate(tr, ex, "B", K = K, seed = seed)
  dg <- diagnose(f, B, seed); tt <- dg$borrowing$table[1, ]
  list(decision = if (is.finite(tt$lower_bound) && tt$lower_bound > 0) "R-OSCAR" else "RACER",
       D_mean = tt$estimate, CI = c(lower = tt$lower_bound, upper = Inf),
       D_per_subject = dg$row_loss$weighted_difference,
       control_CI = c(lower = tt$control_lower, upper = tt$control_upper), diagnostics = dg)
}
