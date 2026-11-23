# =============================================================================
# 07_replication_weekly.R — two validation steps from the feasibility study
#  (a) Replication of the published Nvidia finding (Basele, Phillips & Shi) and
#      the other bridge stocks: which setting is needed to flag them?
#      log/level x wild bootstrap/Monte Carlo x monthly/weekly, full window.
#  (b) Weekly vs monthly for the layer indices (primary setting, log, raw):
#      is the monthly design an artefact?
# Weekly runs (T ~ 615) use Monte Carlo critical values only: the wild bootstrap
# re-estimates ~160k BSADF regressions per draw at this T, which is impractical
# (as anticipated in the feasibility study). MC values depend only on T and
# are computed once.
# Outputs: output/tables/replication_bridge.csv, gsadf_weekly_layers.csv,
#          episodes_weekly_layers.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
set.seed(SEED)

monthly <- read_csv(P("data/processed/monthly_prices.csv"), show_col_types = FALSE) |>
  filter(date >= START_DATE, date <= END_DATE)
weekly  <- read_csv(P("data/processed/weekly_prices.csv"), show_col_types = FALSE) |>
  filter(date >= as.Date("2015-01-02"), date <= END_DATE)
BRIDGE_12 <- c("NVDA", "MSFT", "AAPL", "AMZN", "GOOGL", "META", "TSLA", "AVGO", "AMD", "ORCL", "MU", "PLTR")

run_setting <- function(d, tk, definition, cv_type, freq) {
  # drop the partial IPO period (PLTR listed Sep 2020)
  if (tk == "PLTR") d <- d[-1, ]
  y <- if (definition == "log") log(d$price) else d$price / d$price[1] * 100
  run_gsadf(y, d$date, tk, cv_type)$summary |> mutate(definition, freq)
}

t0 <- Sys.time()
rep <- expand_grid(ticker = BRIDGE_12, definition = c("log", "level"),
                   cv_type = c("wb", "mc"), freq = c("monthly", "weekly")) |>
  filter(!(freq == "weekly" & cv_type == "wb")) |>
  pmap(\(ticker, definition, cv_type, freq) {
    d <- (if (freq == "monthly") monthly else weekly) |> filter(ticker == !!ticker)
    run_setting(d, ticker, definition, cv_type, freq)
  }) |> list_rbind() |>
  select(ticker = series, freq, definition, cv_type, T, minw, gsadf, cv95, reject_95, stars, months_explosive)
message("Replication runtime: ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
write_csv(rep, P("output/tables/replication_bridge.csv"))
rep |> mutate(cell = paste0(round(gsadf, 2), stars)) |>
  select(ticker, freq, definition, cv_type, cell) |>
  pivot_wider(names_from = c(freq, definition, cv_type), values_from = cell) |> print(width = 250)

# ---- (b) Weekly layer indices ----------------------------------------------
idx_w <- read_csv(P("data/processed/layer_indices_weekly.csv"), show_col_types = FALSE) |>
  filter(date <= END_DATE)
wk <- map(c(LAYERS, "SPY"), \(l) {
  y <- log(idx_w[[l]] / idx_w[[l]][1] * 100)
  run_gsadf(y, idx_w$date, l, "mc")
})
wk_sum <- map(wk, "summary") |> list_rbind()
write_csv(wk_sum, P("output/tables/gsadf_weekly_layers.csv"))
write_csv(map(wk, \(m) m$episodes |> mutate(cv_type = "mc")) |> list_rbind(),
          P("output/tables/episodes_weekly_layers.csv"))
print(wk_sum |> select(series, cv_type, T, minw, min_dur, gsadf, cv95, stars, n_episodes, months_explosive))
