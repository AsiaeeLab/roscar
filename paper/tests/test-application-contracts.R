application_file <- function(...) file.path(testthat::test_path("..", "..", "paper", "applications"), ...)

test_that("restricted cubic spline is linear beyond its boundary knots", {
  env <- new.env(parent = globalenv())
  source(application_file("star", "construction.R"), local = env)
  z <- env$application_rcs(c(-3, -2, -1, 4, 5, 6), c(0, 1, 2))
  expect_equal(diff(z[1:3, "nonlinear"], differences = 2), 0)
  expect_equal(diff(z[4:6, "nonlinear"], differences = 2), 0, tolerance = 1e-12)
})

test_that("STAR source selection leaves trial and external disjoint", {
  env <- new.env(parent = globalenv())
  source(application_file("star", "construction.R"), local = env)
  # Public methodological fixture for source sampling; no protected data model.
  d <- data.frame(stdntid = 1:100, Y = seq_len(100), A = rep(c(-1, 1), 50),
    geography = rep(c("rural_inner_city", "urban_suburban"), each = 50),
    g1schid = rep(1:10, each = 10), g1tchid = rep(1:20, each = 5),
    classroom = rep(1:20, each = 5))
  first <- env$star_construct(d, .3, 91)
  second <- env$star_construct(d, .3, 91)
  expect_identical(first, second)
  expect_length(intersect(first$trial$stdntid, first$ext$stdntid), 0L)
  expect_true(all(first$trial$geography == "rural_inner_city"))
  expect_true(all(first$ext$Y[first$ext$A == 1 & first$ext$geography == "urban_suburban"] < 75.5))
  expect_equal(first$selection$median_denominator, c(50L, 50L))
})

test_that("GPS output guard rejects repositories before data access", {
  env <- new.env(parent = globalenv())
  source(application_file("gps", "audit.R"), local = env)
  repo <- tempfile(); dir.create(repo); dir.create(file.path(repo, ".git"))
  on.exit(unlink(repo, recursive = TRUE))
  expect_error(env$gps_external_directory(file.path(repo, "results")), "inside a Git")
  expect_error(env$gps_external_directory(""), "GPS_OUTPUT_DIR")
  expect_error(env$gps_validate_design(list(), data.frame()), "Incomplete GPS_DESIGN_RDS")
})
