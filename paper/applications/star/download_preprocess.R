# Primary data only. The unlicensed comparison CSV is downloaded into a temporary
# directory, compared, then deleted; none of its data are written to this project.
star_columns <- function() c("stdntid", "gender", "race", "birthmonth", "birthday",
  "birthyear", unlist(lapply(c("gk", "g1", "g2", "g3"), function(g)
    paste0(g, c("classtype", "classsize", "schid", "surban", "tchid", "freelunch",
      "treadss", "tmathss", if (g == "g3") "tlangss", "tlistss")))))
star_download <- function(url, dest) {
  status <- try(utils::download.file(url, dest, quiet = TRUE, mode = "wb",
    headers = c("User-Agent" = "roscar reproducibility audit")), silent = TRUE)
  if (inherits(status, "try-error") || !file.exists(dest) || status != 0L)
    stop("Public STAR download failed: ", url, call. = FALSE)
  invisible(dest)
}
star_outcome_checksum <- function(d) {
  keep <- d$g1classtype %in% c(1, 2)
  y <- rowMeans(d[keep, c("g1treadss", "g1tmathss", "g1tlistss")])
  tmp <- tempfile(); on.exit(unlink(tmp))
  writeLines(sprintf("%.12f", sort(y[is.finite(y)])), tmp, useBytes = TRUE)
  unname(tools::md5sum(tmp))
}
star_verify_extract <- function(extract, comparator) {
  # Raw comparator has two empty trailing columns; preserve and verify those too.
  raw <- read.csv(comparator, check.names = FALSE, na.strings = c("NA", ""))
  named <- nzchar(names(raw)); expected <- star_columns()
  if (!identical(names(raw)[named], expected) || !all(vapply(raw[!named],
      function(x) all(is.na(x)), logical(1)))) stop("Unexpected comparison CSV schema")
  checks <- data.frame(column = expected, identical = vapply(expected, function(nm)
    identical(as.numeric(extract[[nm]]), as.numeric(raw[[nm]])), logical(1)))
  summary <- data.frame(primary_rows = nrow(extract), comparator_rows = nrow(raw),
    substantive_columns = length(expected), blank_trailing_columns = sum(!named),
    column_names_match = identical(names(extract), expected),
    all_values_match = all(checks$identical),
    sorted_outcome_md5 = star_outcome_checksum(extract),
    comparator_sorted_outcome_md5 = star_outcome_checksum(raw))
  list(summary = summary, columns = checks,
       pass = nrow(extract) == nrow(raw) && all(checks$identical))
}
prepare_star <- function(data_dir = "paper/applications/star/data", verify = TRUE) {
  stopifnot(requireNamespace("foreign", quietly = TRUE),
            requireNamespace("jsonlite", quietly = TRUE))
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  metadata_path <- file.path(data_dir, "dataverse_metadata.json")
  star_download(paste0("https://dataverse.harvard.edu/api/datasets/:persistentId",
    "?persistentId=hdl:1902.1/10766"), metadata_path)
  version <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)$data$latestVersion
  if (version$versionNumber != 1L || version$versionMinorNumber != 0L)
    stop("Primary dataset version changed; re-audit before updating the reproduction")
  if (version$license$name != "CC0 1.0") stop("Expected CC0 1.0 license; metadata changed")
  entries <- Filter(function(x) identical(x$dataFile$filename, "PROJECT STAR.zip"), version$files)
  if (length(entries) != 1L) stop("PROJECT STAR.zip missing or ambiguous")
  entry <- entries[[1]]$dataFile
  zipfile <- file.path(data_dir, "PROJECT STAR.zip")
  star_download(paste0("https://dataverse.harvard.edu/api/access/datafile/", entry$id), zipfile)
  if (toupper(entry$checksum$type) != "MD5" ||
      unname(tools::md5sum(zipfile)) != entry$checksum$value) stop("STAR ZIP checksum mismatch")
  writeLines(c("CC0 1.0 Universal: public domain dedication.",
    "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
    "License recorded by Harvard Dataverse hdl:1902.1/10766.",
    "The license applies to the primary data, not the comparison GitHub CSV."),
    file.path(data_dir, "LICENSE-CC0.txt"))
  work <- tempfile("star-primary-"); dir.create(work); on.exit(unlink(work, recursive = TRUE))
  files <- utils::unzip(zipfile, list = TRUE)$Name
  student <- files[grepl("(^|/)STAR_Students\\.sav$", files)]
  if (length(student) != 1L) stop("Expected one primary STAR_Students.sav")
  utils::unzip(zipfile, files = student, exdir = work)
  primary <- foreign::read.spss(file.path(work, student), to.data.frame = TRUE,
                               use.value.labels = FALSE)
  names(primary) <- tolower(names(primary))
  extract <- primary[, star_columns()]
  if (verify) {
    comparator <- file.path(work, "comparison.csv")
    star_download(paste0("https://raw.githubusercontent.com/CausalML/",
      "RemovingHiddenConfounding/a25cf3d2524a01c8a8d821f25cdeeb312c34a9cd/STAR_Students_for_Uri.csv"), comparator)
    audit <- star_verify_extract(extract, comparator)
    write.csv(audit$summary, file.path(data_dir, "reconstruction_audit.csv"), row.names = FALSE)
    write.csv(audit$columns, file.path(data_dir, "column_audit.csv"), row.names = FALSE)
    if (!audit$pass) stop("Primary reconstruction differs from Kallus extract; inspect audit")
  }
  # This table is selected entirely from the licensed SPSS source.
  saveRDS(extract, file.path(data_dir, "star_primary_extract.rds"))
  invisible(extract)
}
if (sys.nframe() == 0L) prepare_star()
