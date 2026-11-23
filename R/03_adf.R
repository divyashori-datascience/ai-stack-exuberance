# =============================================================================
# 03_adf.R — standard (left-tailed) ADF tests on log prices and log returns,
# plus residual diagnostics of the lag-0 Dickey–Fuller regression.
# Purpose: establish the usual I(1) baseline (unit root in prices, stationary
# returns) before testing the explosive (right-tailed) alternative.
# Output: output/tables/adf_tests.csv, adf_residual_diagnostics.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
suppressPackageStartupMessages(library(urca))

idx <- read_csv(P("data/processed/layer_indices_monthly.csv"), show_col_types = FALSE)
series <- c(LAYERS, "SPY")

adf_row <- function(x, name, what, type) {
  t <- ur.df(x, type = type, lags = 12, selectlags = "BIC")
  stat <- t@teststat[1, paste0("tau", ifelse(type == "trend", "3", "2"))]
  cv5  <- t@cval[1, "5pct"]
  tibble(series = name, variable = what, deterministics = type,
         lags_bic = sum(grepl("z.diff.lag", rownames(t@testreg$coefficients))),
         tau = stat, cv_5pct = cv5, reject_unit_root_5pct = stat < cv5)
}

res <- map(series, \(s) {
  lp <- log(na.omit(idx[[s]])); r <- diff(lp)
  bind_rows(adf_row(lp, s, "log price", "trend"),
            adf_row(r,  s, "log return", "drift"))
}) |> list_rbind()
write_csv(res, P("output/tables/adf_tests.csv"))
print(res, n = 50)

# Residual diagnostics: Ljung–Box on residuals of the lag-0 DF regression on log
# prices (the specification GSADF uses by default). Serial correlation here is
# the reason we re-run GSADF with lag 1 as a robustness check.
diag <- map(series, \(s) {
  lp <- log(na.omit(idx[[s]])); dy <- diff(lp); ylag <- head(lp, -1)
  e <- residuals(lm(dy ~ ylag))
  lb6 <- Box.test(e, lag = 6, type = "Ljung-Box"); lb12 <- Box.test(e, lag = 12, type = "Ljung-Box")
  arch <- Box.test(e^2, lag = 6, type = "Ljung-Box")
  tibble(series = s, lb6_p = lb6$p.value, lb12_p = lb12$p.value, arch6_p = arch$p.value)
}) |> list_rbind()
write_csv(diag, P("output/tables/adf_residual_diagnostics.csv"))
print(diag)
