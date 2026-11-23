# =============================================================================
# 06_single_stocks.R — ROBUSTNESS (lecturer feedback): is exuberance concentrated
# in a few stocks or spread across a segment?
#  (a) GSADF on every constituent (and the Mag-7 bridge names AAPL, TSLA):
#      log prices, raw, wild bootstrap; full window (from the stock's first full
#      month) and post-ChatGPT window. Minimum window and duration follow the
#      PSY rules for each stock's own T. Stocks with T < 36 months are skipped.
#  (b) Leave-one-out: rebuild each layer index without one stock at a time and
#      re-run the primary GSADF test (log, full, raw, wild bootstrap).
# Outputs: output/tables/gsadf_stocks.csv, episodes_stocks.csv,
#          stocks_layer_summary.csv, gsadf_leave_one_out.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
set.seed(SEED)

cons    <- read_csv(P("data/constituents.csv"), show_col_types = FALSE)
bench   <- read_csv(P("data/benchmarks.csv"), show_col_types = FALSE)
monthly <- read_csv(P("data/processed/monthly_prices.csv"), show_col_types = FALSE) |>
  filter(date <= END_DATE)
universe <- bind_rows(cons |> select(ticker, layer, role),
                      bench |> filter(type == "bridge") |> transmute(ticker, layer = "bridge", role = "bridge"))
BRIDGE_12 <- c("NVDA", "MSFT", "AAPL", "AMZN", "GOOGL", "META", "TSLA", "AVGO", "AMD", "ORCL", "PLTR", "MU")

# ---- (a) Individual stocks --------------------------------------------------
stock_run <- function(tk, window) {
  d <- monthly |> filter(ticker == tk, date >= START_DATE)
  # IPO month is partial: start from the first full month (drop the first month-end
  # if the stock listed after Dec 2014)
  first_ever <- min(monthly$date[monthly$ticker == tk])
  if (first_ever > as.Date("2014-12-01")) d <- d |> filter(date > first_ever)
  if (window == "post") d <- d |> filter(date >= POST_START)
  if (nrow(d) < 36) return(NULL)
  r <- run_gsadf(log(d$price), d$date, tk, "wb")
  list(summary = r$summary |> mutate(window = window, start = min(d$date)),
       episodes = r$episodes |> mutate(window = window))
}
t0 <- Sys.time()
st <- expand_grid(ticker = universe$ticker, window = c("full", "post")) |>
  pmap(\(ticker, window) stock_run(ticker, window)) |> compact()
message("Single-stock runtime: ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

stocks <- map(st, "summary") |> list_rbind() |> rename(ticker = series) |>
  left_join(universe, by = "ticker") |>
  mutate(bridge = ticker %in% BRIDGE_12) |>
  select(layer, ticker, role, bridge, window, start, T, minw, min_dur, gsadf, cv95, reject_95, stars,
         n_episodes, months_explosive)
write_csv(stocks, P("output/tables/gsadf_stocks.csv"))
write_csv(map(st, "episodes") |> list_rbind() |> rename(ticker = series),
          P("output/tables/episodes_stocks.csv"))

# Layer summary: how many constituents are individually explosive?
layer_sum <- stocks |> filter(layer != "bridge") |> group_by(layer, window) |>
  summarise(n_tested = n(), n_explosive = sum(reject_95),
            share_explosive = mean(reject_95),
            explosive_names = paste(ticker[reject_95], collapse = " "), .groups = "drop") |>
  arrange(window, match(layer, LAYERS))
write_csv(layer_sum, P("output/tables/stocks_layer_summary.csv"))
print(layer_sum, width = 200)
print(stocks |> filter(bridge, window == "full") |> select(ticker, T, gsadf, cv95, stars, months_explosive))

# ---- (b) Leave-one-out ------------------------------------------------------
loo_all <- map(LAYERS, \(l) {
  tks <- cons$ticker[cons$layer == l]
  map(c("none", tks), \(drop) {
    ix <- build_ew_index(monthly, setdiff(tks, drop)) |> filter(date >= START_DATE)
    y  <- log(ix$index / ix$index[1] * 100)
    bind_rows(run_gsadf(y, ix$date, l, "wb")$summary, run_gsadf(y, ix$date, l, "mc")$summary) |>
      mutate(layer = l, dropped = drop)
  }) |> list_rbind()
}) |> list_rbind() |>
  select(layer, dropped, cv_type, gsadf, cv95, reject_95, stars, months_explosive)
write_csv(loo_all, P("output/tables/gsadf_leave_one_out.csv"))
loo_all |> group_by(layer, cv_type) |>
  summarise(full_index = reject_95[dropped == "none"],
            loo_reject_share = mean(reject_95[dropped != "none"]),
            min_gsadf = min(gsadf[dropped != "none"]), max_gsadf = max(gsadf[dropped != "none"]),
            verdict_flipped_by = paste(dropped[dropped != "none" & reject_95 != reject_95[dropped == "none"]], collapse = " "),
            .groups = "drop") |>
  arrange(cv_type) |> print(width = 200)
