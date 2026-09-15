#' Simulate a Prespecified Tutorial Scenario
#'
#' Scenarios 1--5 implement Section 8 of the tutorial. Scenario 6 is the
#' sparse extension requested in audit A6: 100 Gaussian covariates, ten
#' prognostic coefficients, two effect modifiers, and a two-coordinate
#' external-to-trial prognostic shift. Its exact coefficients are recorded
#' in the returned metadata and in paper/simulations/README.md.
#'
#' The trial always has known balanced Bernoulli randomization. Independent
#' errors for both potential outcomes are generated before the observed
#' outcome is selected. The 2,000-row evaluation sample uses a separate seed
#' that does not depend on the replication seed. Thus repeated calls with
#' different replication seeds share the same evaluation covariates.
#'
#' @param name Integer 1--6 or a string such as "scenario1"; "teaching"
#'   selects the four-covariate example from Section 4.3.
#' @param n_r Trial sample size; defaults to 250 for Scenario 6 and 200 otherwise.
#' @param n_o External sample size.
#' @param seed Seed for the independent trial and external observations.
#' @param test_seed Separate seed for the fixed evaluation set.
#' @param variant Scenario 3 external outcome: "nonprognostic" or "reversed".
#' @param rho Scenario 4 recoverability parameter, either 0 or 0.8.
#' @param gamma Scenario 5 external control prognosis coefficient, 0 or 1.
#' @param kappa Scenario 5 treated-arm sine coefficient, 0 or 1.
#' @param support_fraction Scenario 6 nonzero prognostic-coefficient fraction.
#' @param delta_fraction Scenario 6 nonzero source-shift coefficient fraction.
#' @return List containing validated trial and external data, analytic CATE
#'   vectors, the fixed test set, three profile rows, exact average and subgroup
#'   truths, the effect basis, the oracle baseline function, and generation metadata.
#' @examples
#' sim <- simulate_scenario(1, n_r = 80, n_o = 200, seed = 42)
#' head(sim$truth_trial)
#' sim$truth_profiles
#' @export
simulate_scenario <- function(name, n_r = NULL, n_o = 2000, seed = 20260914,
                              test_seed = 20260901, variant = "nonprognostic",
                              rho = 0, gamma = 1, kappa = 0,
                              support_fraction = 0.1, delta_fraction = 0.02) {
  scenario <- tolower(gsub("[ _-]", "", as.character(name)))
  scenario <- sub("^scenario", "", scenario)
  if (length(scenario) != 1L || !scenario %in% c(as.character(1:6), "teaching"))
    stop("name must identify Scenario 1--6 or teaching")
  if (is.null(n_r)) n_r <- if (scenario == "6") 250L else 200L
  for (n in list(n_r, n_o)) {
    if (length(n) != 1L || !is.finite(n) || n < 2L || n != as.integer(n))
      stop("sample sizes must be integers of at least two")
  }
  if (!rho %in% c(0, 0.8)) stop("rho must be 0 or 0.8")
  if (!gamma %in% 0:1 || !kappa %in% 0:1) stop("gamma and kappa must be 0 or 1")
  variant <- match.arg(variant, c("nonprognostic", "reversed"))
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
          else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
            rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
  p <- if (scenario == "teaching") 4L else if (scenario == "6") 100L else 20L
  beta <- delta <- NULL
  if (scenario == "6") {
    if (any(!is.finite(c(support_fraction, delta_fraction))) ||
        support_fraction < 0.02 || support_fraction > 1 ||
        delta_fraction < 0.01 || delta_fraction > 1)
      stop("Scenario 6 fractions must define at least two prognostic and one shift coefficient")
    s <- max(2L, as.integer(round(p * support_fraction)))
    d <- max(1L, as.integer(round(p * delta_fraction)))
    beta <- delta <- numeric(p)
    beta[seq_len(s)] <- rep(c(1, -1, 0.75, -0.75, 0.5), length.out = s)
    delta[seq.int(p - d + 1L, p)] <- rep(c(0.75, -0.75), length.out = d)
    names(beta) <- names(delta) <- paste0("X", seq_len(p))
  }
  draw_covariates <- function(n, source = "trial") {
    if (scenario == "4") {
      Z <- matrix(stats::rnorm(n * 4L), n, 4L,
                  dimnames = list(NULL, paste0("Z", 1:4)))
      U <- matrix(stats::rnorm(n * 2L), n, 2L,
                  dimnames = list(NULL, paste0("U", 1:2)))
      eta <- matrix(stats::rnorm(n * 6L), n, 6L)
      V <- rho * Z[, rep(1:4, length.out = 6L), drop = FALSE] + sqrt(1 - rho^2) * eta
      colnames(V) <- paste0("V", 1:6)
      list(X = if (source == "trial") cbind(Z, U) else cbind(Z, V), Z = Z, U = U, V = V)
    } else {
      correlation <- if (scenario == "teaching") 0 else 0.3
      Sigma <- correlation^abs(outer(seq_len(p), seq_len(p), "-"))
      X <- matrix(stats::rnorm(n * p), n, p) %*% chol(Sigma)
      colnames(X) <- paste0("X", seq_len(p))
      list(X = X)
    }
  }
  tau <- function(X) {
    X <- as.data.frame(X)
    if (scenario == "4") 0.5 + 0.5 * X$Z1 - 0.25 * X$U1
    else if (scenario == "teaching") 0.5 + 0.5 * X$X1
    else 0.5 + 0.5 * X$X1 - 0.25 * X$X2 +
      if (scenario == "5") kappa * sin(X$X3) else 0
  }
  prognosis <- function(X) {
    X <- as.data.frame(X)
    if (scenario == "4") 2 + (1 + rho) * X$Z1 + 0.5 * (1 + rho) * X$Z2 + 0.5 * X$U1
    else if (scenario == "teaching") 1 + X$X1 + X$X2
    else if (scenario == "6") 2 + drop(as.matrix(X[, names(beta), drop = FALSE]) %*% beta)
    else 2 + X$X1 + X$X2 + 0.5 * X$X3 + 0.5 * sin(X$X4) +
      if (scenario == "5") kappa * sin(X$X3) / 2 else 0
  }
  draw_sample <- function(n, source) {
    dat <- draw_covariates(n, source)
    X <- dat$X
    if (scenario == "4") {
      g <- 2 + dat$Z[, 1] + 0.5 * dat$Z[, 2] + dat$V[, 1] +
        0.5 * dat$V[, 2] + 0.5 * dat$U[, 1]
      tr <- 0.5 + 0.5 * dat$Z[, 1] - 0.25 * dat$U[, 1]
    } else {
      g <- prognosis(X)
      tr <- tau(X)
    }
    prob <- rep(0.5, n)
    if (source == "external") {
      if (scenario %in% c("1", "4", "teaching")) g <- g + 0.5
      if (scenario == "2") {
        L <- stats::rnorm(n)
        prob <- stats::plogis(0.6 * X[, 1] + 1.2 * L)
        g <- g + L
      }
      if (scenario == "3") {
        if (variant == "nonprognostic") { g <- rep(0, n); tr <- rep(1, n) }
        else g <- 4 - g + 2 * cos(X[, 1])
      }
      if (scenario == "5") {
        # Subtract half of the full trial contrast from its average arm mean:
        # the treated-arm sine cancels, leaving exactly g_base - tau_base / 2.
        g <- 0.5 + gamma * (g - tr / 2)
        tr <- rep(0, n)
        prob <- rep(0, n)
      }
      if (scenario == "6") g <- g + 0.5 + drop(X %*% delta)
    }
    A <- 2 * stats::rbinom(n, 1, prob) - 1
    err_minus <- stats::rnorm(n)
    err_plus <- stats::rnorm(n)
    Y <- g + A * tr / 2 + ifelse(A == 1, err_plus, err_minus)
    list(X = X, A = A, Y = Y)
  }
  set.seed(seed)
  raw_trial <- draw_sample(n_r, "trial")
  raw_ext <- draw_sample(n_o, "external")
  trial <- trial_data(raw_trial$X, raw_trial$A, raw_trial$Y, pi = rep(0.5, n_r))
  ext <- external_data(raw_ext$X, raw_ext$A, raw_ext$Y)
  set.seed(test_seed)
  test_X <- draw_covariates(2000L, "trial")$X
  profiles <- matrix(0, 3L, ncol(trial$X), dimnames = list(NULL, colnames(trial$X)))
  profiles[, 1] <- c(-1, 0, 1)
  effect_terms <- if (scenario == "4") c("Z1", "U1") else if (scenario == "teaching") "X1" else c("X1", "X2")
  if (scenario == "5") effect_terms <- c(effect_terms, "sin(X3)")
  basis <- stats::reformulate(effect_terms)
  # For an AR(1) Gaussian design E[X2 | X1>0] = 0.3 sqrt(2/pi).
  # E[sin(X3) | X1>0] has no elementary form, so Scenario 5 subgroup
  # integration is performed by one-dimensional deterministic quadrature.
  halfnormal <- sqrt(2 / base::pi)
  sub_delta <- if (scenario %in% c("4", "teaching")) 0.5 * halfnormal else 0.425 * halfnormal
  integration_error <- 0
  if (scenario == "5" && kappa == 1) {
    rr <- 0.3^2
    iq <- stats::integrate(function(z) 2 * sin(rr * z) *
                            exp(-(1 - rr^2) / 2) * stats::dnorm(z),
                          lower = 0, upper = Inf, rel.tol = 1e-12)
    sub_delta <- sub_delta + iq$value
    integration_error <- iq$abs.error
  }
  metadata <- list(scenario = scenario, n_r = n_r, n_o = n_o, seed = seed,
                   test_seed = test_seed, n_test = 2000L, variant = variant,
                   rho = rho, gamma = gamma, kappa = kappa,
                   covariance = if (scenario == "4") "independent Z,U; V=rho*Z+noise"
                     else if (scenario == "teaching") "identity" else "AR1 rho=0.3",
                   support_fraction = if (scenario == "6") support_fraction else NULL,
                   delta_fraction = if (scenario == "6") delta_fraction else NULL,
                   prognosis_coefficients = beta, source_shift_coefficients = delta,
                   subgroup_integration_error = integration_error)
  list(trial = trial, ext = ext, test_X = test_X, truth_trial = tau(trial$X),
       truth_test = tau(test_X), profiles = profiles, truth_profiles = tau(profiles),
       center_X = profiles[2L, , drop = FALSE], truth_center = tau(profiles)[2L],
       truth_average = 0.5,
       truth_subgroups = c(below_zero = 0.5 - sub_delta, above_zero = 0.5 + sub_delta),
       basis = basis, oracle_baseline = prognosis, truth_function = tau,
       shared = if (scenario == "4") paste0("Z", 1:4) else colnames(trial$X),
       trial_only = if (scenario == "4") paste0("U", 1:2) else character(),
       external_only = if (scenario == "4") paste0("V", 1:6) else character(),
       metadata = metadata)
}
