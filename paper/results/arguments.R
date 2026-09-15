# Generate Table P027 from roxygen-generated Rd documentation and real formals.
# No manually maintained API table.

.argument_uses_match_arg <- function(expr, arg) {
  if (!is.call(expr)) return(FALSE)
  head <- paste(deparse(expr[[1L]]), collapse = "")
  if (head %in% c("match.arg", "base::match.arg") && length(expr) >= 2L &&
      identical(expr[[2L]], as.name(arg))) return(TRUE)
  any(vapply(as.list(expr)[-1L], .argument_uses_match_arg, logical(1), arg = arg))
}

.argument_literal_choices <- function(default) {
  if (!grepl("^c\\(", default)) return(NULL)
  expr <- tryCatch(parse(text = default)[[1L]], error = function(e) NULL)
  if (is.null(expr)) return(NULL)
  values <- as.list(expr)[-1L]
  if (!length(values) || !all(vapply(values, is.character, logical(1)))) return(NULL)
  unlist(values, use.names = FALSE)
}

.argument_input_type <- function(arg, purpose, default, matched_choice = FALSE) {
  text <- tolower(purpose)
  has <- function(pattern) grepl(pattern, text, perl = TRUE)
  # Specific documented roles precede incidental words such as "row number"
  # in an ID description or "default learners" in a seed description.
  if (arg == "...") return("additional named arguments")
  if (has("named.*logical/index|named.*logical.*index|named.*list.*selector"))
    return("named list of logical or integer row selectors")
  if (has("identifier|labels on|site/subgroup labels|design strata|randomization/design strata"))
    return("vector of IDs or labels (e.g., character, numeric, factor)")
  if (has("seed")) return("integer scalar or NULL")
  if (has("block names|column.name.*blocks|covariate block.*names|names or.*indices|variable lists"))
    return(if (has("indices|index")) "character names or integer column indices" else "character column names")
  if (has("integer labels|fold labels|fixed grouped trial fold")) return("integer vector of fold labels")
  if (has("roscar_external_fit|fitted object from.*fit_external_arms")) return("roscar_external_fit object")
  if (has("fitted.*roscar_fit|roscar_fit.*object")) return("roscar_fit object")
  if (has("trial from|validated trial|a.*trial_data.*object")) return("roscar_trial list")
  if (has("external source from|external_data.*object")) return("roscar_external list or NULL")
  if (matched_choice) return("character choice")
  if (!is.null(.argument_literal_choices(default))) return("character vector")
  if (has("^names from")) return("character vector")
  if (has("transport comparator")) return("character choice")
  if (default %in% c("TRUE", "FALSE") || has("whether|defaults to true|defaults to false|use.*correction"))
    return("logical flag")
  if (has("^a regression learner|^learner for|^final squared.loss learner|^discrepancy learner") ||
      grepl("^learner_[[:alnum:]_]+\\(", default)) return("learner list with fit/predict functions")
  if (has("^named list.*learners|^named list of external")) return("named list of learners")
  if (has("function of covariates|baseline function|a function")) return("function")
  if (has("one.sided.*formula|effect formula|effect basis.*formula|prespecified.*formula"))
    return("one-sided formula with intercept")
  if (has("probability.*observed arm|probability of assignment|positive.arm probabilities"))
    return("numeric probability scalar or vector")
  if (has("treatment.*coded|treatment vector coded")) return("numeric treatment vector (0/1 or -1/+1)")
  if (has("borrowed arm|arm to calibrate|arm represented")) return("numeric arm code (-1 or +1; 0 accepted for control)")
  if (has("finite numeric.*matrix|numeric.*data frame|covariate matrix|matrix/data frame|matrix or data frame|calibration design"))
    return("numeric matrix or data frame")
  if (has("penalty grid")) return("numeric penalty vector")
  if (has("weights|numeric.*outcome|numeric.*pseudo.outcome|preliminary contrast on|external arm mean prediction|calibrated predictions"))
    return("numeric vector")
  if (has("number of|basis size|pls dimension|components|bootstrap resamples|resamples for"))
    return("integer count or NULL")
  if (has("error probability|interval error")) return("numeric scalar")
  if (grepl("^[0-9]+[Ll]?$", default)) return("integer scalar")
  if (grepl("^[0-9]*[.][0-9]+$", default)) return("numeric scalar")
  if (has("superlearner library")) return("character vector of SuperLearner wrapper names")
  stop("The Rd parameter type needs clarification: ", arg, " — ", purpose)
}

.argument_validation <- function(purpose, choices = NULL, matched_choice = FALSE) {
  if (matched_choice && length(choices))
    return(paste0("Choose one of: ", paste(choices, collapse = ", "), "."))
  sentences <- strsplit(purpose, "(?<=[.!?]) +", perl = TRUE)[[1L]]
  constraint <- grepl("finite|strictly|positive|nonmissing|disjoint|unique|must|requires?|at least|one.*per|coded|0/1|-1/\\+1|intercept|bounded|limited|^Names from|^Either|^One of",
                      sentences, ignore.case = TRUE, perl = TRUE)
  if (any(constraint)) paste(sentences[constraint], collapse = " ") else
    "No additional constraint stated in this parameter's Rd text."
}

write_argument_table <- function(root = ".", output = file.path(root, "paper/results/ARGUMENT_TABLE.md")) {
  functions <- c("trial_data", "external_data", "borrow_cate", "learner_lasso", "learner_ridge",
                 "learner_ols", "learner_gam", "learner_rf", "learner_sl", "transport",
                 "fit_cate", "bootstrap_cate", "diagnose", "compare_methods")
  clean <- function(x) {
    s <- paste(unlist(x), collapse = "")
    s <- gsub("[\r\n]+", " ", s)
    s <- gsub("\\\\(code|link|eqn|emph|strong)\\{([^}]+)\\}", "\\2", s)
    s <- gsub("[|]", "/", s)
    trimws(gsub("[[:space:]]+", " ", s))
  }
  docs <- lapply(list.files(file.path(root, "man"), "\\.Rd$", full.names = TRUE), tools::parse_Rd)
  rows <- character(); records <- list()
  front_B <- paste(deparse(formals(get("borrow_cate", mode = "function"))$B), collapse = " ")
  paper_B <- paste(deparse(formals(get("bootstrap_cate", mode = "function"))$B), collapse = " ")
  for (fun in functions) {
    f <- get(fun, mode = "function")
    aliases <- lapply(docs, function(d) vapply(Filter(function(x) identical(attr(x, "Rd_tag"), "\\alias"), d), clean, ""))
    i <- which(vapply(aliases, function(a) fun %in% a, logical(1)))[1L]
    if (is.na(i)) stop("Missing generated documentation for ", fun)
    d <- docs[[i]]
    args <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\arguments"), d)
    items <- if (length(args)) Filter(function(x) identical(attr(x, "Rd_tag"), "\\item"), args[[1]]) else list()
    value <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\value"), d)
    if (!length(value)) stop("Missing generated return documentation for ", fun)
    output_text <- clean(value[[1]])
    for (arg in names(formals(f))) {
      item <- Filter(function(x) arg %in% strsplit(clean(x[[1]]), ", *")[[1]], items)
      if (!length(item)) stop("Missing generated argument documentation for ", fun, "(", arg, ")")
      purpose <- clean(item[[1]][[2]])
      def <- paste(deparse(formals(f)[[arg]]), collapse = " ")
      if (!nzchar(def)) def <- if (arg == "...") "not supplied" else "required"
      matched_choice <- .argument_uses_match_arg(body(f), arg)
      type <- .argument_input_type(arg, purpose, def, matched_choice)
      if (def != "NULL" && type %in% c("integer count or NULL", "roscar_external list or NULL"))
        type <- sub(" or NULL$", "", type)
      if (def == "NULL" && !grepl(" or NULL$", type)) type <- paste(type, "or NULL")
      validation <- .argument_validation(purpose, .argument_literal_choices(def), matched_choice)
      displayed_default <- paste0("`", gsub("[|]", "/", def), "`")
      if (arg == "B" && identical(def, front_B) && def != paper_B)
        displayed_default <- paste0("`", paper_B, "` in paper analyses; API `", def, "`")
      rows <- c(rows, paste0("| `", fun, "(", arg, ")` | ", type, " | ", displayed_default,
        " | ", purpose, " | ", validation, " | ", output_text, " |"))
      records[[length(records) + 1L]] <- data.frame(function_name = fun, argument = arg,
        input_type = type, api_default = def, purpose = purpose, validation = validation,
        returned_output = output_text, stringsAsFactors = FALSE)
    }
  }
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  writeLines(c("# Package argument table (P027)", "", "Generated from current Rd documentation and function formals by `paper/results/arguments.R`. Input types follow documented parameter roles and literal defaults. Validation cells reproduce documented constraints and identify where a parameter's Rd text states none.",
    paste0("The front-door computational default is B=", front_B,
      "; the tutorial's teaching and application analyses set B=", paper_B,
      ". API defaults below are the actual formals. For a `match.arg` choice vector, the first entry is the effective default. Binary link calibration is tested but not simulation-evaluated. Survival and general cluster-randomized inference are unsupported; grouped IDs handle repeated observations/resampling units."), "",
    "| Argument | Input type | Tutorial default / actual API default | Purpose | Documented validation | Returned output |",
    "|---|---|---|---|---|---|", rows), output)
  attr(output, "arguments") <- do.call(rbind, records)
  invisible(output)
}
