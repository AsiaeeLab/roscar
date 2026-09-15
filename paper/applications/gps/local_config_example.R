# Copy OUTSIDE the repository and complete after the local audit. This file does
# not assert verification or supply guessed allocation probabilities.
config <- list(
  assignment_probability = NA_real_, # Known P(digital) from the allocation plan
  assignment_evidence = "",          # Citation/file and section supporting it
  strata_columns = c("site", "language", "health_literacy"),
  baseline_verified = FALSE,         # Earliest WFLz timing checked against randomization
  endpoint_verified = FALSE,         # Source visit construction checked
  source_overlap_verified = FALSE,   # Cross-source identifiers/linkage checked
  response_denominator_verified = FALSE, # Original eligible denominator checked against upstream filters
  endpoint_audit = list(),           # Named list(verified=TRUE,evidence="...") entries
  expected_trial_n = 330L,
  expected_external_n = 8867L,
  min_profile_arm_n = 5L,
  # Literal control label(s) can be supplied after checking the data dictionary.
  control_labels = c("Clinic Only"),
  strict_reconstruction = TRUE
)
# saveRDS(config, "/secure/analysis/gps_design.rds")
# Set GPS_DESIGN_RDS to that file and GPS_OUTPUT_DIR to an external directory.
