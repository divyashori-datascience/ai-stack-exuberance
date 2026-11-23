# =============================================================================
# utils.R — shared helpers: index construction and GSADF wrappers
# =============================================================================

# ---- Month-end and week-end prices -----------------------------------------
to_period_end <- function(daily, unit = c("month", "week")) {
  unit <- match.arg(unit)
  daily |>
    mutate(period = if (unit == "month") as.Date(format(date, "%Y-%m-01"))
                    else date - (as.integer(format(date, "%u")) - 5) %% 7) |>  # Friday of the week
    group_by(ticker, period) |> slice_max(date, n = 1, with_ties = FALSE) |> ungroup() |>
    transmute(date = period, ticker, price = adjusted)
}

# ---- Equal-weighted index ---------------------------------------------------
# Index from equal-weighted simple returns, rebalanced every period, rebased to 100.
# A stock contributes a return in period t only if it has a price at the end of t-1
# and t, so an IPO month (partial) never enters: the stock joins from its first
# full month. The index starts (= 100) at the first period-end where at least
# `min_n` constituents have a price; it is NA before.
build_ew_index <- function(prices, tickers, min_n = MIN_CONSTITUENTS) {
  px <- prices |> filter(ticker %in% tickers) |> arrange(ticker, date) |>
    group_by(ticker) |> mutate(ret = price / lag(price) - 1) |> ungroup()
  n_px <- px |> count(date, name = "n_priced")
  rets <- px |> filter(!is.na(ret)) |>
    group_by(date) |> summarise(ret = mean(ret), n_ret = n(), .groups = "drop")
  out <- n_px |> left_join(rets, by = "date") |> arrange(date)
  start <- out$date[which(out$n_priced >= min_n)[1]]
  if (is.na(start)) return(tibble(date = out$date, index = NA_real_, n = out$n_priced))
  out <- out |> filter(date >= start) |>
    mutate(ret = ifelse(date == start, 0, coalesce(ret, 0)),
           index = 100 * cumprod(1 + ret))
  tibble(date = out$date, index = out$index, n = out$n_priced)
}

# Each stock's share of the index's cumulative arithmetic return over a window:
# contribution_i = sum_t r_it / N_t. Used to check that one stock does not drive a layer.
contribution_shares <- function(prices, tickers, from, to) {
  px <- prices |> filter(ticker %in% tickers) |> arrange(ticker, date) |>
    group_by(ticker) |> mutate(ret = price / lag(price) - 1) |> ungroup() |>
    filter(date > from, date <= to, !is.na(ret)) |>
    group_by(date) |> mutate(contrib = ret / n()) |> ungroup()
  px |> group_by(ticker) |> summarise(contribution = sum(contrib), .groups = "drop") |>
    mutate(share = contribution / sum(contribution)) |> arrange(desc(share))
}

# ---- Series transformations -------------------------------------------------
# definition: "log" (log prices) or "level" (price levels)
# adjust:     "raw" or "relative" (relative to SPY, both rebased to 100 at the window start)
transform_series <- function(x, spy, definition = c("log", "level"), adjust = c("raw", "relative")) {
  definition <- match.arg(definition); adjust <- match.arg(adjust)
  x <- 100 * x / x[1]
  if (adjust == "relative") x <- 100 * x / (100 * spy / spy[1])
  if (definition == "log") log(x) else x
}

# ---- GSADF wrappers ---------------------------------------------------------
# Runs radf() and returns GSADF stat, chosen critical value, verdict and date-stamped episodes.
# cv_type: "wb" (wild bootstrap, series-specific) or "mc" (Monte Carlo, depends only on T)
mc_cache <- new.env()
get_mc_cv <- function(n, minw, lag = 0L) {
  key <- paste(n, minw, lag, sep = "_")
  if (is.null(mc_cache[[key]]))
    mc_cache[[key]] <- radf_mc_cv(n = n, minw = minw, nrep = if (n > 300) NREP_MC_LONG else NREP_MC, seed = SEED)
  mc_cache[[key]]
}

run_gsadf <- function(y, dates, name, cv_type = c("wb", "mc"), lag = ADF_LAG,
                      minw = psy_minw(length(y)), min_dur = psy_mindur(length(y))) {
  cv_type <- match.arg(cv_type)
  df  <- setNames(data.frame(y), name)
  df  <- data.frame(date = dates, df); names(df)[2] <- name
  est <- radf(df[, 2, drop = FALSE], minw = minw, lag = lag)
  cv  <- if (cv_type == "mc") get_mc_cv(length(y), minw, lag)
         else radf_wb_cv(df[, 2, drop = FALSE], minw = minw, nboot = NBOOT, seed = SEED)
  stat <- as.numeric(est$gsadf)
  cv95 <- if (cv_type == "mc") cv$gsadf_cv["95%"] else cv$gsadf_cv[1, "95%"]
  cv90 <- if (cv_type == "mc") cv$gsadf_cv["90%"] else cv$gsadf_cv[1, "90%"]
  cv99 <- if (cv_type == "mc") cv$gsadf_cv["99%"] else cv$gsadf_cv[1, "99%"]
  # BSADF sequence and its 95% critical-value sequence (for date-stamping and plots)
  bsadf <- as.numeric(est$bsadf)
  bs_cv <- if (cv_type == "mc") as.numeric(cv$bsadf_cv[, "95%"])
           else as.numeric(cv$bsadf_cv[, "95%", 1])
  bs_cv <- tail(bs_cv, length(bsadf))   # with lag > 0 the BSADF sequence is shorter by `lag`
  idx   <- (length(y) - length(bsadf) + 1):length(y)
  # Date-stamping: episodes where BSADF > CV for at least min_dur consecutive periods
  above <- bsadf > bs_cv
  r <- rle(above); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
  keep <- r$values & r$lengths >= min_dur
  episodes <- if (any(keep))
    tibble(series = name, start = dates[idx[starts[keep]]], end = dates[idx[ends[keep]]],
           duration = r$lengths[keep],
           peak_date = map2_chr(starts[keep], ends[keep], \(s, e)
                         as.character(dates[idx[s:e][which.max(y[idx[s:e]])]])) |> as.Date())
    else tibble(series = character(), start = as.Date(character()), end = as.Date(character()),
                duration = integer(), peak_date = as.Date(character()))
  list(est = est, cv = cv,
       summary = tibble(series = name, T = length(y), minw = minw, min_dur = min_dur, lag = lag,
                        cv_type = cv_type, gsadf = stat, cv90 = cv90, cv95 = cv95, cv99 = cv99,
                        reject_95 = stat > cv95,
                        stars = case_when(stat > cv99 ~ "***", stat > cv95 ~ "**", stat > cv90 ~ "*", TRUE ~ ""),
                        n_episodes = nrow(episodes),
                        months_explosive = sum(episodes$duration)),
       episodes = episodes,
       bsadf = tibble(series = name, date = dates[idx], bsadf = bsadf, cv95 = bs_cv))
}
