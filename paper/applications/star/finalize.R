# Durable, local-only finalizer for an already running STAR analysis. It waits
# for completion, summarizes public aggregates and refreshes the local paper
# summary. It does not rerun analyses, commit, push or publish anything.
star_process_start <- function(pid) {
  path <- file.path("/proc", as.character(pid), "stat")
  if (!file.exists(path)) return(NA_character_)
  line <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  if (length(line) != 1L) return(NA_character_)
  fields <- strsplit(sub("^.*[)] ", "", line), " +")[[1]]
  if (length(fields) < 20L) NA_character_ else fields[20L]
}
star_finalizer_status <- function(path, values) {
  values$`Updated-UTC` <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  write.dcf(as.data.frame(lapply(values, as.character), check.names = FALSE), temporary)
  if (!file.rename(temporary, path)) stop("Cannot atomically write finalizer status")
}
star_wait_and_finalize <- function(config_path) {
  cfg <- readRDS(config_path)
  status_path <- file.path(cfg$state_dir, "STATUS.dcf")
  status <- list(Status = "waiting", `Finalizer-PID` = Sys.getpid(),
    `Analysis-PID` = cfg$analysis_pid, `Started-UTC` = cfg$started_utc,
    `Run-Directory` = cfg$run_dir, `Source-Snapshot` = cfg$snapshot)
  writeLines(as.character(Sys.getpid()), file.path(cfg$state_dir, "PID"))
  star_finalizer_status(status_path, status)
  tryCatch({
    cat("Waiting for STAR completion marker:", cfg$marker, "\n")
    repeat {
      if (file.exists(cfg$marker)) break
      current <- star_process_start(cfg$analysis_pid)
      alive <- isTRUE(tryCatch(tools::pskill(cfg$analysis_pid, signal = 0L), error = function(e) FALSE))
      if (!alive || (!is.na(cfg$analysis_start) && !identical(current, cfg$analysis_start)))
        stop("STAR analysis process ended without FINISHED.txt; no final summaries were produced")
      Sys.sleep(cfg$poll_seconds)
      star_finalizer_status(status_path, status)
    }
    # Verify the finalizer's frozen R sources before executing either summary.
    manifest <- read.csv(file.path(cfg$snapshot, "SOURCE_MANIFEST.csv"), stringsAsFactors = FALSE)
    hashes <- unname(tools::md5sum(file.path(cfg$snapshot, manifest$path)))
    if (!identical(hashes, manifest$md5)) stop("Finalizer source snapshot checksum mismatch")
    status$Status <- "summarizing"
    star_finalizer_status(status_path, status)
    old <- setwd(cfg$root); on.exit(setwd(old), add = TRUE)
    env <- new.env(parent = globalenv())
    source(file.path(cfg$snapshot, "paper/applications/star/summarize.R"), local = env)
    summary <- env$star_summarize(cfg$run_dir, file.path(cfg$run_dir, "summary"), cfg$primary_path)
    if (!isTRUE(summary$status$full_design_complete))
      stop("Completion marker exists, but the full STAR design is incomplete; inspect summary/RUN_STATUS.csv")
    source(file.path(cfg$snapshot, "paper/results/summarize.R"), local = env)
    env$write_results_summary(root = cfg$root, source_root = cfg$snapshot)
    status$Status <- "completed"
    status$`STAR-Summary` <- summary$summary
    status$`Paper-Summary` <- file.path(cfg$root, "paper/results/RESULTS_SUMMARY.md")
    star_finalizer_status(status_path, status)
    cat("Completed local STAR summary and paper-summary refresh.\n")
    invisible(summary)
  }, error = function(e) {
    status$Status <- "failed"; status$Error <- conditionMessage(e)
    star_finalizer_status(status_path, status)
    cat("Finalizer failed:", conditionMessage(e), "\n")
    stop(conditionMessage(e), call. = FALSE)
  })
}
star_launch_finalizer <- function(run_dir = "paper/applications/star/results-full",
                                  analysis_pid, root = ".", poll_seconds = 30L,
                                  primary_path = "paper/applications/star/data/star_primary_extract.rds") {
  if (.Platform$OS.type == "windows") stop("Durable finalizer launch currently requires a Unix host")
  if (!nzchar(Sys.which("setsid"))) stop("Durable finalizer launch requires the Unix setsid command")
  stopifnot(length(analysis_pid) == 1L, is.finite(analysis_pid), analysis_pid > 0,
            length(poll_seconds) == 1L, is.finite(poll_seconds), poll_seconds >= 1, poll_seconds <= 60)
  root <- normalizePath(root, mustWork = TRUE)
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  primary_path <- normalizePath(primary_path, mustWork = TRUE)
  state_dir <- file.path(run_dir, "finalizer")
  if (file.exists(file.path(state_dir, "PID"))) {
    old_pid <- as.integer(readLines(file.path(state_dir, "PID"), warn = FALSE)[1])
    if (isTRUE(tryCatch(tools::pskill(old_pid, 0L), error = function(e) FALSE)))
      stop("A STAR finalizer is already running with PID ", old_pid)
    unlink(file.path(state_dir, "PID"))
  }
  snapshot <- file.path(state_dir, paste0("source-", format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")))
  dir.create(snapshot, recursive = TRUE, showWarnings = FALSE)
  files <- c("paper/applications/star/summarize.R", "paper/applications/star/finalize.R",
    file.path("paper/results", list.files(file.path(root, "paper/results"), "[.]R$")))
  manifest <- data.frame(path = files, md5 = unname(tools::md5sum(file.path(root, files))))
  for (file in files) {
    target <- file.path(snapshot, file)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file.path(root, file), target)) stop("Could not freeze source: ", file)
  }
  if (!identical(unname(tools::md5sum(file.path(snapshot, files))), manifest$md5))
    stop("A source changed while the finalizer snapshot was being copied")
  write.csv(manifest, file.path(snapshot, "SOURCE_MANIFEST.csv"), row.names = FALSE)
  cfg <- list(root = root, run_dir = run_dir, state_dir = state_dir, snapshot = snapshot,
    analysis_pid = as.integer(analysis_pid), analysis_start = star_process_start(analysis_pid),
    marker = file.path(run_dir, "FINISHED.txt"), poll_seconds = as.integer(poll_seconds),
    primary_path = primary_path, started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
  if (is.na(cfg$analysis_start) && !file.exists(cfg$marker)) stop("The requested STAR analysis process is not running")
  config_path <- file.path(state_dir, "CONFIG.rds"); saveRDS(cfg, config_path)
  log <- file.path(state_dir, "run.log")
  command <- c(shQuote(file.path(R.home("bin"), "Rscript")),
    shQuote(file.path(snapshot, "paper/applications/star/finalize.R")), "watch", shQuote(config_path))
  # A separate session survives termination of the interactive launcher's
  # process group; nohup alone does not provide that isolation.
  system2("setsid", c("nohup", command), stdin = "/dev/null",
          stdout = log, stderr = log, wait = FALSE)
  for (attempt in seq_len(50L)) {
    if (file.exists(file.path(state_dir, "PID"))) break
    Sys.sleep(.1)
  }
  pid <- if (file.exists(file.path(state_dir, "PID"))) as.integer(readLines(file.path(state_dir, "PID"))[1]) else NA_integer_
  invisible(list(pid = pid, status = file.path(state_dir, "STATUS.dcf"), log = log, snapshot = snapshot))
}
if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  if (length(args) == 2L && args[1] == "watch") star_wait_and_finalize(args[2])
  else if (length(args) == 3L && args[1] == "launch")
    print(star_launch_finalizer(args[2], as.integer(args[3])))
  else stop("Usage: Rscript paper/applications/star/finalize.R launch RUN_DIR ANALYSIS_PID")
}
