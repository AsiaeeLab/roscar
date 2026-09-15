# Validated data adapters retain the X/Y/A layout used by Cole Beck's
# build_data(); transport() also uses that function for mismatch augmentation.
.roscar_matrix <- function(X, n = NULL) {
    if (is.data.frame(X) && !all(vapply(X, is.numeric, logical(1))))
        stop("X must be numeric; encode categorical covariates explicitly.", call. = FALSE)
    if (is.null(dim(X))) X <- matrix(X, ncol = 1L)
    X <- as.matrix(X)
    if (!is.numeric(X) || anyNA(X) || any(!is.finite(X)))
        stop("X must be a finite numeric matrix or data frame.", call. = FALSE)
    if (!is.null(n) && nrow(X) != n) stop("X and Y must have the same number of rows.", call. = FALSE)
    if (!nrow(X)) stop("Data must contain at least one row.", call. = FALSE)
    storage.mode(X) <- "double"
    if (is.null(colnames(X)) && ncol(X)) colnames(X) <- paste0("X", seq_len(ncol(X)))
    if (anyNA(colnames(X)) || any(!nzchar(colnames(X))) || anyDuplicated(colnames(X)))
        stop("Covariate names must be nonempty and unique.", call. = FALSE)
    X
}

.roscar_arm <- function(A) {
    if (is.logical(A)) A <- as.integer(A)
    if (!is.numeric(A) || anyNA(A) || !length(A))
        stop("A must contain numeric 0/1 or -1/+1 treatment codes.", call. = FALSE)
    if (all(A %in% c(0, 1))) return(ifelse(A == 1, 1, -1))
    if (all(A %in% c(-1, 1))) return(as.numeric(A))
    stop("A must use either 0/1 or -1/+1 treatment coding.", call. = FALSE)
}

.roscar_columns <- function(x, X, what) {
    if (is.null(x)) return(NULL)
    if (is.numeric(x)) {
        if (anyNA(x) || any(x != as.integer(x)) || any(x < 1 | x > ncol(X)))
            stop(what, " contains invalid column indices.", call. = FALSE)
        x <- colnames(X)[x]
    }
    if (!is.character(x) || anyNA(x) || anyDuplicated(x) || !all(x %in% colnames(X)))
        stop(what, " must contain unique names or indices of columns in X.", call. = FALSE)
    x
}

.roscar_blocks <- function(X, shared, trial_only, external_only) {
    out <- list(shared = .roscar_columns(shared, X, "shared"),
                trial_only = .roscar_columns(trial_only, X, "trial_only"),
                external_only = .roscar_columns(external_only, X, "external_only"))
    if (anyDuplicated(unlist(out, use.names = FALSE)))
        stop("Covariate blocks must not overlap.", call. = FALSE)
    out
}

.roscar_with_seed <- function(seed, code) {
    if (is.null(seed)) return(force(code))
    if (length(seed) != 1L || is.na(seed) || !is.finite(seed)) stop("seed must be a finite scalar.", call. = FALSE)
    exists_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (exists_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit(if (exists_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
            else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
                rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
    set.seed(seed)
    force(code)
}

#' Construct validated randomized trial data
#'
#' The returned list uses the same numeric X, Y, A layout as [build_data()].
#' Categorical predictors must first be encoded into numeric columns. Supply
#' known design probabilities when available: an empirical arm proportion is
#' only the fallback. This constructor does not infer cluster randomization.
#' @param X Finite numeric covariate matrix or numeric data frame.
#' @param A Treatment coded 0/1 or -1/+1.
#' @param Y Finite numeric outcome vector.
#' @param pi Probability of each participant's observed arm, strictly between
#'   zero and one; a scalar is recycled. Defaults to observed arm proportions
#'   within strata. This is not always the probability of treatment +1.
#' @param id Independent resampling unit identifier, defaulting to row number.
#' @param strata Randomization/design strata, defaulting to one stratum.
#' @param weights Optional positive finite analysis weights (for example,
#'   inverse probabilities of response). These do not replace randomization pi.
#' @param shared,trial_only,external_only Optional disjoint covariate block names
#'   or column indices. Missing block assignments are inferred during transport.
#' @return A validated list of class `roscar_trial`, including `p_plus`, the
#'   probability of assignment to +1, and the covariate `blocks`.
#' @export
trial_data <- function(X, A, Y, pi = NULL, id = NULL, strata = NULL,
                       shared = NULL, trial_only = NULL, external_only = NULL,
                       weights = NULL) {
    if (!is.numeric(Y) || !length(Y) || anyNA(Y) || any(!is.finite(Y)))
        stop("Y must be a nonempty finite numeric vector.", call. = FALSE)
    Y <- as.numeric(Y)
    X <- .roscar_matrix(X, length(Y)); A <- .roscar_arm(A)
    n <- length(Y)
    if (length(A) != n || length(unique(A)) != 2L)
        stop("Trial A must match Y and contain both treatment arms.", call. = FALSE)
    if (is.null(id)) id <- seq_len(n)
    if (is.null(strata)) strata <- rep("all", n)
    if (length(id) != n || anyNA(id) || length(strata) != n || anyNA(strata))
        stop("id and strata must have one nonmissing value per row.", call. = FALSE)
    if (any(vapply(split(as.character(strata), id), function(z) length(unique(z)) != 1L, logical(1))))
        stop("An id cannot cross design strata.", call. = FALSE)
    if (is.null(pi)) {
        p_plus <- stats::ave(as.numeric(A == 1), strata, FUN = mean)
        pi <- ifelse(A == 1, p_plus, 1 - p_plus)
    } else {
        if (length(pi) == 1L) pi <- rep(pi, n)
        if (!is.numeric(pi) || length(pi) != n) stop("pi must have length one or nrow(X).", call. = FALSE)
        p_plus <- ifelse(A == 1, pi, 1 - pi)
    }
    if (anyNA(pi) || any(!is.finite(pi)) || any(pi <= 0 | pi >= 1))
        stop("Observed-arm pi must lie strictly between zero and one; supply design probabilities if a stratum has only one observed arm.", call. = FALSE)
    if (!is.null(weights) && (!is.numeric(weights) || length(weights) != n ||
        anyNA(weights) || any(!is.finite(weights)) || any(weights <= 0)))
        stop("weights must contain one positive finite analysis weight per row.", call. = FALSE)
    structure(list(X = X, A = A, Y = Y, pi = as.numeric(pi),
                   p_plus = as.numeric(p_plus), id = id, strata = strata, weights = weights,
                   blocks = .roscar_blocks(X, shared, trial_only, external_only)),
              class = c("roscar_trial", "list"))
}

#' Construct validated external outcome data
#' @param X Finite numeric covariate matrix or numeric data frame.
#' @param A Optional treatment vector coded 0/1 or -1/+1. If missing, the arm
#'   is designated by `arm_ext` in [fit_external_arms()] or [borrow_cate()].
#' @param Y Finite numeric outcome vector.
#' @param shared,trial_only,external_only Optional disjoint covariate block
#'   names or column indices; see [trial_data()].
#' @return A list of class `roscar_external`, compatible with the X/Y/A layout
#'   returned by [build_data()].
#' @export
external_data <- function(X, A = NULL, Y, shared = NULL, trial_only = NULL,
                          external_only = NULL) {
    if (!is.numeric(Y) || !length(Y) || anyNA(Y) || any(!is.finite(Y)))
        stop("Y must be a nonempty finite numeric vector.", call. = FALSE)
    X <- .roscar_matrix(X, length(Y))
    if (!is.null(A)) {
        A <- .roscar_arm(A)
        if (length(A) != length(Y)) stop("A and Y must have equal lengths.", call. = FALSE)
    }
    structure(list(X = X, A = A, Y = as.numeric(Y),
                   blocks = .roscar_blocks(X, shared, trial_only, external_only)),
              class = c("roscar_external", "list"))
}

#' Make treatment-stratified folds without splitting independent units
#'
#' Extends `make_stratified_folds()` in the JMLR release
#' `r-oscar/R/06_diagnostic.R` with design strata, grouped units, and scoped RNG.
#' @param A Treatment coded 0/1 or -1/+1.
#' @param K Number of folds, at least two and no larger than the number of IDs.
#' @param strata Optional vector of design strata.
#' @param id Optional independent-unit identifiers. Repeated copies of an ID
#'   always receive the same fold. IDs cannot cross design strata.
#' @param seed Optional random seed; the caller's RNG state is restored.
#' @return An integer fold label from 1 to K for each row.
#' @export
make_stratified_folds <- function(A, K = 5, strata = NULL, id = NULL, seed = NULL) {
    A <- .roscar_arm(A); n <- length(A)
    if (is.null(strata)) strata <- rep("all", n)
    if (is.null(id)) id <- seq_len(n)
    if (length(id) != n || anyNA(id) || length(strata) != n || anyNA(strata))
        stop("id and strata must have one nonmissing value per row.", call. = FALSE)
    ids <- unique(as.character(id)); gi <- match(as.character(id), ids)
    if (length(K) != 1L || is.na(K) || K != as.integer(K) || K < 2L || K > length(ids))
        stop("K must be an integer between two and the number of independent units.", call. = FALSE)
    groups <- split(seq_len(n), factor(gi, levels = seq_along(ids)))
    gs <- vapply(groups, function(i) {
        if (length(unique(strata[i])) != 1L) stop("An id cannot cross design strata.", call. = FALSE)
        as.character(strata[i[1L]])
    }, character(1))
    # Balance homogeneous-arm groups separately; mixed-arm groups stay intact.
    ga <- vapply(groups, function(i) paste(sort(unique(A[i])), collapse = ","), character(1))
    .roscar_with_seed(seed, {
        assignment <- integer(length(ids)); total <- rep(0L, K)
        for (lev in unique(gs)) for (arm in unique(ga[gs == lev])) {
            idx <- which(gs == lev & ga == arm)
            idx <- idx[sample.int(length(idx))]
            idx <- idx[order(-lengths(groups[idx]), method = "radix")]
            arm_load <- rep(0L, K)
            for (j in idx) {
                candidates <- which(arm_load == min(arm_load))
                candidates <- candidates[total[candidates] == min(total[candidates])]
                f <- candidates[sample.int(length(candidates), 1L)]
                assignment[j] <- f
                arm_load[f] <- arm_load[f] + length(groups[[j]])
                total[f] <- total[f] + length(groups[[j]])
            }
        }
        as.integer(assignment[gi])
    })
}
