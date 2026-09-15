# Investigator-run only when including protected Greenlight aggregate results.
# Output must remain outside every repository.
combine_application_tables <- function(star_table, gps_table, output_file) {
  source("paper/applications/gps/audit.R")
  gps_external_directory(dirname(output_file))
  star <- read.csv(star_table, check.names = FALSE)
  gps <- read.csv(gps_table, check.names = FALSE)
  star$application <- "STAR"; gps$application <- "Greenlight Plus"
  cols <- union(names(star), names(gps))
  for (nm in setdiff(cols, names(star))) star[[nm]] <- NA
  for (nm in setdiff(cols, names(gps))) gps[[nm]] <- NA
  write.csv(rbind(star[, cols], gps[, cols]), output_file, row.names = FALSE)
  invisible(output_file)
}
