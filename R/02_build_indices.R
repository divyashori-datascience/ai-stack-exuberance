# =============================================================================
# 02_build_indices.R — month-end prices, equal-weighted layer indices,
# coverage check and constituent-contribution check
# Outputs: data/processed/monthly_prices.csv, weekly_prices.csv,
#          layer_indices_monthly.csv, layer_indices_weekly.csv
#          output/tables/coverage.csv, constituents_appendix.csv, contributions.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")

cons  <- read_csv(P("data/constituents.csv"), show_col_types = FALSE)
daily <- read_csv(P("data/raw/daily_adjusted.csv"), show_col_types = FALSE) |>
  filter(date <= END_DATE)

# Month-end prices. Dec 2014 is kept only so that Jan 2015 has a return; the
# indices are rebased to 100 at end-Jan 2015 (first month of the sample).
monthly <- to_period_end(daily, "month") |> filter(date >= as.Date("2014-12-01"))
weekly  <- to_period_end(daily, "week")  |> filter(date >= as.Date("2014-12-26"))
write_csv(monthly, P("data/processed/monthly_prices.csv"))
write_csv(weekly,  P("data/processed/weekly_prices.csv"))

build_all <- function(px, first) {
  map(LAYERS, \(l) build_ew_index(px, cons$ticker[cons$layer == l]) |>
        filter(date >= first) |> mutate(index = 100 * index / first(index), layer = l)) |>
    list_rbind()
}
idx_m <- build_all(monthly, START_DATE)
idx_w <- build_all(weekly,  as.Date("2015-01-02"))
spy_m <- monthly |> filter(ticker == "SPY", date >= START_DATE) |> mutate(index = 100 * price / first(price))
spy_w <- weekly  |> filter(ticker == "SPY", date >= as.Date("2015-01-02")) |> mutate(index = 100 * price / first(price))

wide <- function(idx, spy) idx |> select(date, layer, index) |> pivot_wider(names_from = layer, values_from = index) |>
  left_join(spy |> select(date, SPY = index), by = "date") |> arrange(date)
write_csv(wide(idx_m, spy_m), P("data/processed/layer_indices_monthly.csv"))
write_csv(wide(idx_w, spy_w), P("data/processed/layer_indices_weekly.csv"))

# ---- Coverage check (validation step 1) -------------------------------------
first_obs <- monthly |> group_by(ticker) |> summarise(first_month_end = min(date), .groups = "drop")
coverage <- cons |> left_join(first_obs, by = "ticker") |>
  group_by(layer) |>
  summarise(n_constituents = n(),
            n_at_start = sum(first_month_end <= as.Date("2014-12-01")),
            n_at_end = sum(!is.na(first_month_end)),
            index_start = START_DATE,
            pass_min4_from_start = n_at_start >= MIN_CONSTITUENTS, .groups = "drop") |>
  arrange(match(layer, LAYERS))
write_csv(coverage, P("output/tables/coverage.csv"))
print(coverage)

appendix <- cons |> left_join(first_obs, by = "ticker") |>
  mutate(first_full_month_in_index = pmax(as.Date(format(first_month_end + 32, "%Y-%m-01")), START_DATE + 31),
         first_full_month_in_index = ifelse(first_month_end <= as.Date("2014-12-01"), "2015-01 (sample start)",
                                            format(first_full_month_in_index, "%Y-%m"))) |>
  select(layer, ticker, name, role, first_full_month_in_index, rationale) |> arrange(match(layer, LAYERS), ticker)
write_csv(appendix, P("output/tables/constituents_appendix.csv"))

# ---- Which stocks drive each layer? (professor's point on index construction) --
contrib <- map(LAYERS, \(l) {
  bind_rows(
    contribution_shares(monthly, cons$ticker[cons$layer == l], as.Date("2014-12-01"), END_DATE) |> mutate(window = "full"),
    contribution_shares(monthly, cons$ticker[cons$layer == l], as.Date("2022-11-01"), END_DATE) |> mutate(window = "post_chatgpt")
  ) |> mutate(layer = l)
}) |> list_rbind()
write_csv(contrib, P("output/tables/contributions.csv"))
contrib |> group_by(layer, window) |> slice_max(share, n = 1) |> print()
