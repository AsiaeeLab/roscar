# Run from the package source root. Paper scripts are intentionally excluded from
# the installed R package and are checked separately from R CMD check.
if (!requireNamespace("testthat", quietly = TRUE)) stop("Install testthat to run paper checks")
files <- list.files("paper/applications", pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
invisible(lapply(files, parse))
testthat::test_dir("paper/tests", reporter = "summary", stop_on_failure = TRUE)
