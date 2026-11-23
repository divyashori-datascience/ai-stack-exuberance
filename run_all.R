# =============================================================================
# run_all.R — reproduce the full analysis from the repository root:
#   Rscript run_all.R            # full pipeline incl. download
#   Rscript run_all.R --no-download   # reuse data/raw/daily_adjusted.csv
# Approximate runtime on a 2-core machine: ~25 min (07 weekly MC and 08 simulation
# dominate).
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
steps <- c("R/01_download.R", "R/02_build_indices.R", "R/03_adf.R", "R/04_gsadf_main.R",
           "R/05_sensitivity_grid.R", "R/06_single_stocks.R", "R/07_replication_weekly.R",
           "R/08_simulation.R", "R/09_figures.R")
if ("--no-download" %in% args) steps <- steps[-1]
for (s in steps) {
  message("\n========== ", s, " ==========")
  t0 <- Sys.time()
  local(source(s, local = TRUE, echo = FALSE))
  message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
}
