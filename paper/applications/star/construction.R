# Adapted from AsiaeeLab/r-oscar experiments/example_star.R::CreateData.
# Selection medians use ALL complete-outcome students in each pooled geography,
# including controls and students later sampled into the trial. Strict < median.
star_analysis_population <- function(raw) {
  d <- raw[raw$g1classtype %in% c(1, 2), , drop = FALSE]
  d$Y <- rowMeans(d[, c("g1treadss", "g1tmathss", "g1tlistss")])
  d <- d[is.finite(d$Y), , drop = FALSE]
  d$A <- ifelse(d$g1classtype == 1, 1, -1)
  d$geography <- ifelse(d$g1surban %in% c(1, 3), "rural_inner_city", "urban_suburban")
  if (any(!d$g1surban %in% 1:4)) stop("Missing or unknown geography")
  d$classroom <- paste(d$g1schid, d$g1tchid, sep = ":")
  if (anyNA(d$classroom) || anyNA(d$g1tchid)) stop("Missing classroom proxy")
  # Actual allocation probabilities are absent from the public extract. These
  # estimates are frozen before trial/external construction; never called known.
  d$p_plus <- ave(as.numeric(d$A == 1), d$g1schid, FUN = mean)
  if (any(d$p_plus <= 0 | d$p_plus >= 1)) stop("A school has no two-arm support")
  d
}
star_construct <- function(data, q, seed) {
  stopifnot(length(q) == 1L, q > 0, q < 1)
  set.seed(seed)
  r <- data[data$geography == "rural_inner_city", , drop = FALSE]
  u <- data[data$geography == "urban_suburban", , drop = FALSE]
  r$rct <- stats::rbinom(nrow(r), 1, q) == 1L; u$rct <- FALSE
  med <- c(rural_inner_city = median(r$Y), urban_suburban = median(u$Y))
  r$external <- !r$rct & (r$A == -1 | (r$A == 1 & r$Y < med[[1]]))
  u$external <- u$A == -1 | (u$A == 1 & u$Y < med[[2]])
  full <- rbind(r, u); trial <- full[full$rct, ]; ext <- full[full$external, ]
  overlap <- intersect(unique(trial$classroom), unique(ext$classroom))
  counts <- as.data.frame(table(source = c(rep("trial", nrow(trial)), rep("external", nrow(ext))),
    geography = c(trial$geography, ext$geography), arm = c(trial$A, ext$A)))
  list(trial = trial, ext = ext, full = full,
    counts = transform(counts, q = q, seed = seed),
    selection = data.frame(geography = names(med), median = unname(med),
      median_denominator = c(nrow(r), nrow(u)), q = q, seed = seed),
    overlap = data.frame(q = q, seed = seed, trial_classrooms = length(unique(trial$classroom)),
      external_classrooms = length(unique(ext$classroom)), shared_classrooms = length(overlap),
      trial_fraction_in_shared_classroom = mean(trial$classroom %in% overlap),
      resampling_unit = "school:teacher (classroom proxy)"))
}
# Restricted cubic spline with three knots: linear term and one nonlinear term.
# All knot selection and median imputation are independent of outcomes.
application_rcs <- function(x, knots) {
  stopifnot(length(knots) == 3L, all(diff(knots) > 0))
  h <- function(z) pmax(z, 0)^3
  t1 <- knots[1]; t2 <- knots[2]; t3 <- knots[3]
  cbind(linear = (x - t2) / (t3 - t1), nonlinear =
    (h(x - t1) - h(x - t2) * (t3 - t1) / (t3 - t2) +
      h(x - t3) * (t2 - t1) / (t3 - t2)) / (t3 - t1)^3)
}
star_design <- function(d) {
  dates <- as.Date(sprintf("%04d-%02d-%02d", d$birthyear, d$birthmonth, d$birthday),
                   format = "%Y-%m-%d")
  dob <- as.numeric(dates); missing <- !is.finite(dob)
  dob[missing] <- median(dob, na.rm = TRUE)
  knots <- as.numeric(quantile(dob[!missing], c(.25, .5, .75)))
  categorical <- function(x) factor(ifelse(is.na(x), "Missing", as.character(x)))
  base <- data.frame(gender = categorical(d$gender), race = categorical(d$race))
  X <- as.data.frame(model.matrix(~ gender + race, base)[, -1, drop = FALSE])
  # Birth date and sex/race are eligible primary modifiers. Free-lunch timing is
  # not established, so it defines descriptive subgroups but is not a modifier.
  X$birth_linear <- application_rcs(dob, knots)[, 1]
  X$birth_nonlinear <- application_rcs(dob, knots)[, 2]
  X$birth_missing <- as.numeric(missing)
  names(X) <- make.names(names(X)); rownames(X) <- as.character(d$stdntid)
  list(X = X, basis = reformulate(names(X)), knots = knots, dob = dob,
       missing = missing)
}
star_profiles <- function(d, design, min_per_arm = 2L) {
  groups <- interaction(d$gender, ifelse(is.na(d$g1freelunch), "Missing", d$g1freelunch), drop = TRUE)
  out <- list(); rows <- integer()
  for (g in levels(groups)) {
    eligible <- which(groups == g & !design$missing)
    counts <- table(factor(d$A[eligible], levels = c(-1, 1)))
    if (any(counts < min_per_arm)) next
    for (p in c(.25, .5, .75)) {
      target <- quantile(design$dob[eligible], p)
      j <- eligible[which.min(abs(design$dob[eligible] - target))]
      support_rows <- eligible[ifelse(is.na(d$race[eligible]), "Missing", as.character(d$race[eligible])) ==
        ifelse(is.na(d$race[j]), "Missing", as.character(d$race[j]))]
      counts <- table(factor(d$A[support_rows], levels = c(-1, 1)))
      if (any(counts < min_per_arm)) next
      rows <- c(rows, j)
      out[[length(out) + 1L]] <- data.frame(profile = paste(g, p, sep = ":"),
        group = g, percentile = p, n_control = counts[1], n_treated = counts[2])
    }
  }
  if (!length(rows)) stop("No supported STAR profiles")
  list(rows = rows, metadata = do.call(rbind, out), grid = design$X[rows, , drop = FALSE])
}
