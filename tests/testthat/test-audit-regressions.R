.audit_example <- function() {
    set.seed(8333)
    X <- matrix(rnorm(360), 120, 3, dimnames = list(NULL, paste0("X", 1:3)))
    A <- rep(c(-1, 1), 60)
    Y <- 2 + X[, 1] + X[, 2] + A * (.5 + .2 * X[, 1]) + rnorm(120)
    list(trial = trial_data(X, A, Y, pi = .5),
         ext = external_data(X, A, Y + 1),
         learners = list(external = learner_ols(), trial = learner_ols(),
                         calibration = learner_intercept()))
}

test_that("comparator covariance never returns an unrelated RACER sandwich", {
    d <- .audit_example()
    fit <- compare_methods(d$trial, d$ext,
        methods = c("interaction_ols", "procova_interaction", "pooled", "rlearner"),
        learners = d$learners, basis = ~ X1, K = 3, seed = 13)
    for (nm in c("interaction_ols", "procova_interaction", "pooled")) {
        expect_identical(fit[[nm]]$status, "success")
        expect_error(vcov(fit[[nm]]$fit), "comparator")
    }
    expect_true(all(is.finite(vcov(fit$rlearner$fit))))
})

test_that("one-arm support uses the same external score in both sources", {
    d <- .audit_example()
    for (arm in c(-1, 1)) {
        fit <- borrow_cate(d$trial, d$ext, recipe = "B", arm_ext = arm,
                           learners = d$learners, basis = ~ X1, K = 3, seed = 13)
        dg <- diagnose(fit)
        col <- if (arm == 1) "q_plus" else "q_minus"
        expected <- stats::density(fit$heldout[[col]])
        expect_equal(dg$prognosis_density$trial$score, expected$x)
        expect_equal(dg$prognosis_density$trial$density, expected$y)
        row <- dg$row_loss
        expect_equal(dg$borrowing$table$estimate, mean((1 - d$trial$pi)^2 * row$difference))
        expect_equal(dg$borrowing$table$control_estimate, mean(row$difference[d$trial$A == arm]))
        expect_equal(row$difference[d$trial$A != arm], rep(0, sum(d$trial$A != arm)))
    }
})

test_that("prognostic-adjustment bootstrap freezes its external fitted resource", {
    d <- .audit_example(); count <- new.env(parent = emptyenv()); count$n <- 0L
    ols <- learner_ols()
    ext_learner <- list(name = "counted_ols", family = "gaussian",
      fit = function(X, y, ...) {
          count$n <- count$n + 1L
          ols$fit(X, y, ...)
      }, predict = ols$predict)
    d$learners$external <- ext_learner
    z <- compare_methods(d$trial, d$ext, "procova_interaction", grid = d$trial$X[1:3, , drop = FALSE],
                          learners = d$learners, basis = ~ X1, K = 3, B = 3, seed = 13)
    expect_identical(z$procova_interaction$status, "success")
    expect_equal(count$n, 2L)
    expect_equal(z$procova_interaction$fit$bootstrap$successful, 3L)
})

test_that("spline knots and paired comparator predictions survive bootstrap replay", {
    d <- .audit_example(); grid <- d$trial$X[1:3, , drop = FALSE]
    fits <- compare_methods(d$trial, d$ext,
       methods = c("racer", "interaction_ols", "procova_interaction", "pooled", "rlearner"),
       learners = d$learners, basis = ~ splines::ns(X1, df = 3), grid = grid,
       K = 3, B = 3, seed = 23)
    reference_indices <- fits$racer$fit$bootstrap$fold_audit[[1L]]$original_row
    for (nm in names(fits)) {
        expect_identical(fits[[nm]]$status, "success")
        fit <- fits[[nm]]$fit; boot <- fit$bootstrap
        i <- boot$fold_audit[[1L]]$original_row
        expect_equal(i, reference_indices)
        replay <- .rerun_fit(fit, .subset_trial(fit$trial, i), boot$seeds[1L])
        expect_equal(.basis_predict(fit$final$design, grid),
                      .basis_predict(replay$final$design, grid))
        expect_equal(as.numeric(predict(replay, grid)), as.numeric(boot$draws[1L, ]))
        paired <- if (is.null(replay$trial_only)) replay else replay$trial_only
        expect_equal(as.numeric(predict(paired, grid)), as.numeric(boot$trial_draws[1L, ]))
    }
})

test_that("standalone calibration rejects a probability offset on binomial mean scale", {
    d <- .audit_example(); d$trial$Y <- as.numeric(d$trial$Y > median(d$trial$Y))
    folds <- make_stratified_folds(d$trial$A, K = 3, seed = 13)
    expect_error(calibrate_in_trial(d$trial, rep(.4, 120), -1,
                  learner_intercept(family = "binomial"), scale = "mean", folds = folds),
                  "scale = 'link'")
})

test_that("the returned paired trial-only fit has coherent diagnostics and refitting", {
    d <- .audit_example()
    fit <- borrow_cate(d$trial, d$ext, learners = d$learners, basis = ~ X1,
                       K = 3, seed = 13, offset = TRUE)
    ref <- fit$trial_only
    expect_equal(ref$heldout$mu_cal_plus, ref$heldout$mu_trial_plus)
    expect_equal(ref$heldout$mu_cal_minus, ref$heldout$mu_trial_minus)
    expect_equal(diagnose(ref)$borrowing$table$estimate, 0)
    boot <- bootstrap_cate(ref, B = 3, grid = d$trial$X[1:3, , drop = FALSE], seed = 13)
    expect_equal(boot$successful, 3L)
    expect_true(all(is.finite(boot$draws)))
})

test_that("nonfinite predictions count as failed bootstrap fits", {
    d <- .audit_example()
    fit <- rct_only_cate(d$trial, learners = d$learners, basis = ~ X1, K = 3, seed = 13)
    base <- fit
    fit$refit <- function(dat, s) {
        ans <- base
        ans$prediction_function <- function(X) rep(NA_real_, nrow(X))
        ans
    }
    boot <- bootstrap_cate(fit, B = 3, grid = d$trial$X[1:3, , drop = FALSE], seed = 13)
    expect_equal(boot$successful, 0L)
    expect_equal(nrow(boot$failures), 3L)
    expect_true(all(grepl("bootstrap prediction", boot$failures$message)))
})

test_that("grouped bootstrap copies stay together in every penalized tuning stage", {
    d <- .audit_example()
    d$learners$trial <- learner_ridge(seed = 13)
    d$learners$calibration <- learner_lasso(seed = 13)
    d$learners$final <- learner_ridge(seed = 13)
    fit <- borrow_cate(d$trial, d$ext, learners = d$learners, basis = ~ X1 + X2,
                       K = 3, seed = 13)
    # A resample with exact repeated copies, retaining original subject IDs.
    replay <- .rerun_fit(fit, .subset_trial(d$trial, c(1:80, 1:40)), seed = 31)
    together <- function(folds, id) all(vapply(split(folds, id),
                   function(x) length(unique(x)) == 1L, logical(1)))
    for (k in names(replay$fold_models)) {
        keep <- replay$folds != as.integer(k)
        for (nm in c("plus", "minus")) {
            arm <- if (nm == "plus") 1 else -1
            id <- replay$trial$id[keep & replay$trial$A == arm]
            mods <- replay$fold_models[[k]][[nm]]
            expect_true(together(mods$trial$foldid, id))
            expect_true(together(mods$cal$foldid, id))
        }
    }
    expect_true(together(replay$final$model$foldid, replay$trial$id))
})
