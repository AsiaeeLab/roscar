# Public API examples for P001/P004-P007. Source without running to inspect.
run_recipe_examples <- function(B = 500L, seed = 20260914L) {
  matched <- simulate_scenario(1, 200, 2000, seed)
  mismatch <- simulate_scenario(4, 200, 2000, seed, rho = .8)
  controls <- external_data(matched$ext$X[matched$ext$A == -1, ],
                           Y = matched$ext$Y[matched$ext$A == -1])
  ll <- list(external = learner_ridge(seed = seed),
             calibration = learner_lasso(seed = seed),
             trial = learner_lasso(seed = seed), final = learner_ols(),
             imputer = learner_ridge(seed = seed))
  list(A = borrow_cate(matched$trial, matched$ext, "A", learners = ll,
         basis = matched$basis, K = 5, B = B, grid = matched$profiles, seed = seed),
       B = borrow_cate(matched$trial, controls, "B", arm_ext = -1, learners = ll,
         basis = matched$basis, K = 5, B = B, grid = matched$profiles, seed = seed),
       C = borrow_cate(mismatch$trial, mismatch$ext, "C", learners = ll,
         shared = mismatch$shared, trial_only = mismatch$trial_only,
         external_only = mismatch$external_only, basis = mismatch$basis,
         offset = TRUE, K = 5, B = B, grid = mismatch$profiles, seed = seed),
       D = borrow_cate(mismatch$trial, mismatch$ext, "D", learners = ll,
         shared = mismatch$shared, trial_only = mismatch$trial_only,
         external_only = mismatch$external_only, basis = mismatch$basis,
         embed_dim = NULL, pls_by_arm = FALSE,
         K = 5, B = B, grid = mismatch$profiles, seed = seed))
}
