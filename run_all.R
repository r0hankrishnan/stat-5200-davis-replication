# =============================================================================
# run_all.R
# Runs the full replication from raw data to tables, figure and check.
# Usage (from the repository root):  Rscript run_all.R
# Runtime: about 15 seconds.
# =============================================================================

if (!file.exists("run_all.R")) stop("Run this script from the repository root.")

steps <- c("01_build_data.R", "02_tables.R", "03_event_study.R", "04_check_against_paper.R",
           "05_slide_figures.R")
for (s in steps) {
  cat("\n------------------------------------------------------------\n")
  cat("Running R/", s, "\n", sep = "")
  cat("------------------------------------------------------------\n")
  source(file.path("R", s), echo = FALSE, local = new.env())
}

writeLines(capture.output(sessionInfo()), file.path("output", "session_info.txt"))
cat("\nDone. Results are in output/.\n")
