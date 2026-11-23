# =============================================================================
# 01_download.R — download daily adjusted prices from Yahoo Finance
# Primary route: quantmod::getSymbols(). If Yahoo rejects quantmod's request
# (HTTP 429, which happens from some networks), fall back to Yahoo's chart API
# with a browser user agent. Both return the same adjusted-close series.
# Output: data/raw/daily_adjusted.csv (date, ticker, adjusted)
# =============================================================================
source("R/00_config.R")
suppressPackageStartupMessages({ library(quantmod); library(jsonlite) })

cons   <- read_csv(P("data/constituents.csv"), show_col_types = FALSE)
bench  <- read_csv(P("data/benchmarks.csv"), show_col_types = FALSE)
tickers <- unique(c(cons$ticker, bench$ticker))

from <- as.Date("2014-12-01"); to <- END_DATE + 1

get_quantmod <- function(tk) {
  x <- getSymbols(tk, src = "yahoo", from = from, to = to, auto.assign = FALSE)
  tibble(date = index(x), ticker = tk, adjusted = as.numeric(Ad(x)))
}

get_chart_api <- function(tk) {
  url <- sprintf(paste0("https://query1.finance.yahoo.com/v8/finance/chart/%s?",
                        "period1=%d&period2=%d&interval=1d&events=div%%2Csplits"),
                 tk, as.integer(as.POSIXct(from, tz = "UTC")),
                 as.integer(as.POSIXct(to, tz = "UTC")))
  h <- curl::new_handle(useragent = "Mozilla/5.0 (X11; Linux x86_64)")
  js <- fromJSON(rawToChar(curl::curl_fetch_memory(url, handle = h)$content))
  r  <- js$chart$result
  tibble(date = as.Date(as.POSIXct(r$timestamp[[1]], origin = "1970-01-01", tz = "America/New_York")),
         ticker = tk,
         adjusted = r$indicators$adjclose[[1]]$adjclose[[1]])
}

fetch <- function(tk) {
  out <- tryCatch(get_quantmod(tk), error = function(e) NULL)
  if (is.null(out)) out <- tryCatch(get_chart_api(tk), error = function(e) {
    message("FAILED: ", tk, " — ", conditionMessage(e)); NULL })
  Sys.sleep(0.3)
  out
}

prices <- map(tickers, fetch) |> list_rbind() |>
  filter(!is.na(adjusted)) |> distinct(date, ticker, .keep_all = TRUE) |>
  arrange(ticker, date)

missing <- setdiff(tickers, unique(prices$ticker))
if (length(missing)) warning("No data for: ", paste(missing, collapse = ", "))

write_csv(prices, P("data/raw/daily_adjusted.csv"))
writeLines(c(paste("Downloaded:", Sys.time()),
             paste("Tickers:", n_distinct(prices$ticker)),
             paste("Rows:", nrow(prices)),
             paste("Range:", min(prices$date), "to", max(prices$date))),
           P("data/raw/download_log.txt"))
message("Saved ", nrow(prices), " rows for ", n_distinct(prices$ticker), " tickers.")
