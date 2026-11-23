# =============================================================================
# 05_sensitivity_grid.R — RQ2: does the verdict survive reasonable changes?
# 16 settings per layer index = 2 definitions (log, level)
#                             x 2 critical values (wild bootstrap, Monte Carlo)
#                             x 2 windows (full 2015-01..2026-10; post-ChatGPT 2022-12..2026-10)
#                             x 2 market adjustments (raw; relative to SPY)
# Plus: ADF lag 1 instead of 0 for the primary setting.
# Outputs: output/tables/gsadf_grid.csv, episodes_grid.csv, gsadf_lag1.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
set.seed(SEED)

idx <- read_csv(P("data/processed/layer_indices_monthly.csv"), show_col_types = FALSE) |>
  filter(date >= START_DATE, date <= END_DATE)

grid <- expand_grid(layer = LAYERS, definition = c("log", "level"), cv_type = c("wb", "mc"),
                    window = c("full", "post"), adjust = c("raw", "relative"))

t0 <- Sys.time()
runs <- pmap(grid, \(layer, definition, cv_type, window, adjust) {
  d <- if (window == "full") idx else idx |> filter(date >= POST_START)
  y <- transform_series(d[[layer]], d$SPY, definition, adjust)
  r <- run_gsadf(y, d$date, layer, cv_type)
  list(summary = r$summary |> mutate(definition, window, adjust, layer = layer),
       episodes = r$episodes |> mutate(definition, cv_type, window, adjust))
})
message("Grid runtime: ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

res <- map(runs, "summary") |> list_rbind() |>
  select(layer, definition, cv_type, window, adjust, T, minw, min_dur, gsadf, cv90, cv95, cv99,
         reject_95, stars, n_episodes, months_explosive)
write_csv(res, P("output/tables/gsadf_grid.csv"))
write_csv(map(runs, "episodes") |> list_rbind(), P("output/tables/episodes_grid.csv"))

# Compact verdict table: share of the 16 settings that reject at 5%
verdict <- res |> group_by(layer) |>
  summarise(settings = n(), rejections_95 = sum(reject_95), share = mean(reject_95), .groups = "drop") |>
  arrange(desc(share))
write_csv(verdict, P("output/tables/gsadf_grid_verdict.csv"))
print(verdict)
print(res |> select(layer, definition, cv_type, window, adjust, gsadf, cv95, stars) |>
        mutate(cell = paste0(round(gsadf, 2), stars)) |>
        select(-gsadf, -cv95, -stars) |>
        pivot_wider(names_from = layer, values_from = cell), n = 20, width = 200)

# ---- Lag 1 robustness (primary setting) -------------------------------------
lag1 <- map(LAYERS, \(l) {
  y <- log(idx[[l]])
  bind_rows(run_gsadf(y, idx$date, l, "wb", lag = 0L)$summary,
            run_gsadf(y, idx$date, l, "wb", lag = 1L)$summary)
}) |> list_rbind() |> select(series, lag, gsadf, cv95, stars, n_episodes, months_explosive)
write_csv(lag1, P("output/tables/gsadf_lag1.csv"))
print(lag1)
