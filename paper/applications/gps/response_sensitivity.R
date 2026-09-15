# Inverse-probability-of-response sensitivity. Cross-fit the response model and
# both outcome regressions; regress the response-weighted randomized pseudo-
# outcome on ALL baseline-eligible children. Missing outcomes contribute zero.
# This targets the eligible baseline-complete population under MAR, correctly
# specified response probabilities, and positivity; it is a sensitivity only.
gps_response_fit <- function(eligible, external, X, Xext, grid, strata, pi_plus,
                             seed, K = 5L) {
  if (!requireNamespace("glmnet", quietly = TRUE)) stop("Response sensitivity requires glmnet")
  response <- is.finite(eligible$Y) & eligible$Y >= -5 & eligible$Y <= 5
  A <- eligible$A; n <- nrow(X); pi_plus <- rep(pi_plus, length.out = n)
  folds <- roscar::make_stratified_folds(A, K = K, strata = strata,
    id = eligible$record_id, seed = seed)
  learner <- roscar::learner_lasso()
  external_fit <- learner$fit(Xext, external$Y)
  q <- learner$predict(external_fit, X)
  psi <- rho <- rep(NA_real_, n)
  set.seed(seed)
  response_X <- cbind(as.matrix(X), treatment = as.numeric(A == 1))
  for (k in unique(folds)) {
    train <- which(folds != k); test <- which(folds == k)
    if (length(unique(response[train])) != 2L) stop("Response model needs respondents and nonrespondents")
    fit_r <- glmnet::cv.glmnet(response_X[train, , drop = FALSE], response[train],
      family = "binomial", alpha = 0, foldid = roscar::make_stratified_folds(
        as.integer(response[train]), K = min(5L, length(unique(eligible$record_id[train]))),
        id = eligible$record_id[train], seed = seed + k))
    prob <- as.numeric(predict(fit_r, response_X, type = "response", s = "lambda.min"))
    if (any(!is.finite(prob) | prob < .01)) stop("Response positivity failure: fitted probability below 0.01")
    rho[test] <- prob[test]
    control <- train[A[train] == -1 & response[train]]
    treated <- train[A[train] == 1 & response[train]]
    if (min(length(control), length(treated)) < 10L) stop("Insufficient response-model training support")
    cal <- learner$fit(X[control, , drop = FALSE], eligible$Y[control],
      weights = 1 / prob[control], offset = q[control], id = eligible$record_id[control])
    plus <- learner$fit(X[treated, , drop = FALSE], eligible$Y[treated], weights = 1 / prob[treated], id = eligible$record_id[treated])
    mu_minus <- q[test] + learner$predict(cal, X[test, , drop = FALSE])
    mu_plus <- learner$predict(plus, X[test, , drop = FALSE])
    baseline <- (1 - pi_plus[test]) * mu_plus + pi_plus[test] * mu_minus
    p_observed <- ifelse(A[test] == 1, pi_plus[test], 1 - pi_plus[test])
    psi[test] <- 0
    obs <- response[test]
    psi[test[obs]] <- A[test[obs]] * (eligible$Y[test[obs]] - baseline[obs]) /
      (p_observed[obs] * prob[test[obs]])
  }
  final <- roscar::learner_ols(); model <- final$fit(X, psi)
  list(prediction = final$predict(model, grid), min_response_probability = min(rho),
       max_response_weight = max(1 / rho), observed_n = sum(response), eligible_n = n)
}
gps_response_bootstrap <- function(eligible, external, X, Xext, grid, strata,
                                   pi_plus, B, seed) {
  point <- gps_response_fit(eligible, external, X, Xext, grid, strata, pi_plus, seed)
  draws <- matrix(NA_real_, B, nrow(grid)); errors <- character(B)
  for (b in seq_len(B)) {
    set.seed(seed + b)
    idx <- unlist(lapply(split(seq_len(nrow(eligible)), strata),
      function(i) i[sample.int(length(i), length(i), replace = TRUE)]), use.names = FALSE)
    result <- tryCatch(gps_response_fit(eligible[idx, ], external, X[idx, ], Xext,
      grid, strata[idx], rep(pi_plus, length.out = nrow(eligible))[idx], seed + b),
      error = function(e) e)
    if (inherits(result, "error")) errors[b] <- conditionMessage(result)
    else draws[b, ] <- result$prediction
  }
  list(point = point, draws = draws, errors = errors,
    successful = sum(rowSums(is.finite(draws)) == ncol(draws)), attempted = B)
}
