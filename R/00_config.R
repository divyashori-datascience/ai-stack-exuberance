# =============================================================================
# 00_config.R — shared settings for the whole pipeline
# Where in the AI stack is the exuberance?  (TSAF F2026, HSLU MSc DAI)
# Mogos Michele · Shori Divya
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(purrr); library(tibble)
  library(ggplot2); library(exuber); library(xts); library(zoo)
})

# ---- Paths ------------------------------------------------------------------
# All scripts are run from the repository root (see run_all.R)
ROOT <- getwd()
if (!file.exists(file.path(ROOT, "R", "00_config.R")))
  stop("Run the scripts from the repository root (the folder that contains R/).")
P <- function(...) file.path(ROOT, ...)
dir.create(P("data/raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(P("data/processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(P("output/tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(P("output/figures"), recursive = TRUE, showWarnings = FALSE)

# ---- Sample -----------------------------------------------------------------
START_DATE   <- as.Date("2015-01-01")   # first month in the sample
END_DATE     <- as.Date("2026-10-31")   # last month in the sample (Oct 2026)
CHATGPT_DATE <- as.Date("2022-11-30")   # ChatGPT launch; post window starts Dec 2022
POST_START   <- as.Date("2022-12-01")

MIN_CONSTITUENTS <- 4                   # a layer index starts once >= 4 stocks have prices

LAYERS <- c("chips", "memory_equipment", "cloud", "power_datacentre", "software", "staples")
LAYER_LABELS <- c(chips = "Chips", memory_equipment = "Memory, storage & equipment",
                  cloud = "Cloud", power_datacentre = "Power & data centres",
                  software = "Software", staples = "Staples (control)")

# ---- GSADF settings ---------------------------------------------------------
# Phillips–Shi–Yu (2015) minimum window rule: floor(T * (0.01 + 1.8 / sqrt(T)))
psy_minw <- function(T) floor(T * (0.01 + 1.8 / sqrt(T)))
# Minimum bubble duration: round(delta * log(T)), delta = 1
psy_mindur <- function(T) round(log(T))

ADF_LAG     <- 0L      # exuber default; lag 1 as robustness
NBOOT       <- 999L    # wild-bootstrap replications
NREP_MC     <- 2000L   # Monte Carlo replications (monthly samples)
NREP_MC_LONG <- 500L   # Monte Carlo replications for weekly samples (T > 300)
SIG_LEVEL   <- 0.95    # 95% critical values
SEED        <- 20261123


