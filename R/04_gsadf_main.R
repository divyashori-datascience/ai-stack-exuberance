# =============================================================================
# 04_gsadf_main.R — MAIN ANALYSIS (priority per lecturer feedback)
# Index-level GSADF tests and BSADF date-stamping for the five AI layers,
# the staples control and the S&P 500 (SPY).
# Primary setting: log prices, full sample (Jan 2015–Oct 2026, T = 142),
# raw (not market-adjusted), ADF lag 0, wild-bootstrap 95% critical values.
# Monte Carlo critical values are reported alongside.
# ETFs are run as a cross-check on the hand-built indices.
# Outputs: output/tables/gsadf_main.csv, episodes_main.csv, bsadf_main.csv,
#          gsadf_etf_check.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
set.seed(SEED)

idx <- read_csv(P("data/processed/layer_indices_monthly.csv"), show_col_types = FALSE) |>
  filter(date >= START_DATE, date <= END_DATE)
series <- c(LAYERS, "SPY")

t0 <- Sys.time()
main <- map(series, \(s) {
  y <- log(idx[[s]] / idx[[s]][1] * 100)
  list(wb = run_gsadf(y, idx$date, s, "wb"), mc = run_gsadf(y, idx$date, s, "mc"))
})
message("Main GSADF runtime: ", round(difftime(Sys.time(), t0, units = "secs")), " s")

summ <- map(main, \(m) bind_rows(m$wb$summary, m$mc$summary)) |> list_rbind()
eps  <- map(main, \(m) bind_rows(m$wb$episodes |> mutate(cv_type = "wb"),
                                  m$mc$episodes |> mutate(cv_type = "mc"))) |> list_rbind()
bs   <- map(main, \(m) bind_rows(m$wb$bsadf |> mutate(cv_type = "wb"),
                                  m$mc$bsadf |> mutate(cv_type = "mc"))) |> list_rbind()
write_csv(summ, P("output/tables/gsadf_main.csv"))
write_csv(eps,  P("output/tables/episodes_main.csv"))
write_csv(bs,   P("output/tables/bsadf_main.csv"))
print(summ |> select(series, cv_type, gsadf, cv95, stars, n_episodes, months_explosive), n = 50)
print(eps |> filter(cv_type == "wb"), n = 50)

# ---- ETF cross-check --------------------------------------------------------
monthly <- read_csv(P("data/processed/monthly_prices.csv"), show_col_types = FALSE) |>
  filter(date >= START_DATE, date <= END_DATE)
etfs <- c(SMH = "chips + equipment", IGV = "software", SKYY = "cloud", XLP = "staples")
etf <- map(names(etfs), \(tk) {
  d <- monthly |> filter(ticker == tk)
  run_gsadf(log(d$price), d$date, tk, "wb")$summary |> mutate(compares_to = etfs[[tk]])
}) |> list_rbind()
write_csv(etf, P("output/tables/gsadf_etf_check.csv"))
print(etf |> select(series, compares_to, T, gsadf, cv95, stars))
