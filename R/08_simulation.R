# =============================================================================
# 08_simulation.R — validation by simulation (feasibility study, section 5)
#  * Size: how often does GSADF reject on series WITHOUT a bubble?
#      - random walk, homoskedastic errors
#      - random walk with a volatility break (sd x3 in the second half)
#      - random walk with GARCH(1,1) errors (calibrated to monthly equity returns)
#  * Power: how often does it reject on a PSY single-bubble DGP (sim_psy1),
#    and does BSADF date-stamping place the bubble in the right period?
# Both Monte Carlo and wild-bootstrap critical values, T = 142 (full sample)
# and T = 47 (post-ChatGPT window), PSY minimum window rule.
# Output: output/tables/simulation_size_power.csv
# =============================================================================
source("R/00_config.R"); source("R/utils.R")
set.seed(SEED)
NSIM <- 200L; NBOOT_SIM <- 199L

# Lean wild bootstrap (Harvey, Leybourne, Sollis & Taylor 2016 scheme, as in
# exuber::radf_wb_cv): y*_t = y_1 + sum_{s<=t} dy_s * w_s, w_s ~ N(0,1).
# exuber's own function has ~2 s fixed overhead per call, which makes thousands of
# simulation calls impractical; this version matches its critical values up to
# bootstrap noise (checked: 95% CV 3.09 vs 3.23 on a test series, 999 draws).
# The empirical results (scripts 04-07) use exuber::radf_wb_cv itself.
wb_gsadf_cv95 <- function(y, minw, nboot) {
  e <- diff(y); n <- length(y)
  st <- replicate(nboot, as.numeric(radf(data.frame(y = c(y[1], y[1] + cumsum(e * rnorm(n - 1)))),
                                         minw = minw)$gsadf))
  quantile(st, 0.95)
}

rw <- function(n, sd_fun) cumsum(c(0, rnorm(n - 1) * sd_fun(n - 1))) + 100
garch_rw <- function(n, omega = 0.0002, a = 0.10, b = 0.85) {
  e <- numeric(n); h <- omega / (1 - a - b)
  for (t in 2:n) { h <- omega + a * e[t - 1]^2 + b * h; e[t] <- sqrt(h) * rnorm(1) }
  log(100) + cumsum(e)
}
dgps <- list(
  rw_homosk   = \(n) rw(n, \(m) rep(1, m)),
  rw_volbreak = \(n) rw(n, \(m) c(rep(1, m %/% 2), rep(3, m - m %/% 2))),
  rw_garch    = \(n) garch_rw(n),
  bubble_psy  = \(n) as.numeric(sim_psy1(n, te = round(0.6 * n), tf = round(0.75 * n)))
)

sim_one <- function(dgp, n) {
  minw <- psy_minw(n); mindur <- psy_mindur(n)
  mc <- get_mc_cv(n, minw)
  map(seq_len(NSIM), \(i) {
    y   <- dgps[[dgp]](n)
    est <- radf(data.frame(y = y), minw = minw, lag = 0L)
    wb95 <- wb_gsadf_cv95(y, minw, NBOOT_SIM)
    stat <- as.numeric(est$gsadf); bs <- as.numeric(est$bsadf)
    # date-stamping hit: BSADF above MC sequence for >= mindur periods inside the bubble
    above <- bs > as.numeric(mc$bsadf_cv[, "95%"])
    tt <- (n - length(bs) + 1):n
    in_bubble <- tt >= round(0.6 * n) & tt <= round(0.75 * n) + mindur
    rr <- rle(above & in_bubble)
    tibble(dgp, n, rep = i,
           rej_mc = stat > mc$gsadf_cv["95%"],
           rej_wb = stat > wb95,
           detected_in_bubble = any(rr$values & rr$lengths >= mindur))
  }) |> list_rbind()
}

t0 <- Sys.time()
sims <- expand_grid(dgp = names(dgps), n = c(142L, 47L)) |>
  pmap(\(dgp, n) { message(dgp, " n=", n); sim_one(dgp, n) }) |> list_rbind()
message("Simulation runtime: ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

out <- sims |> group_by(dgp, n) |>
  summarise(nsim = n(), reject_rate_mc = mean(rej_mc), reject_rate_wb = mean(rej_wb),
            bubble_dated_correctly = ifelse(first(dgp) == "bubble_psy", mean(detected_in_bubble), NA_real_),
            .groups = "drop") |>
  mutate(interpretation = ifelse(dgp == "bubble_psy", "power (higher is better)",
                                 "size (nominal 5%)"))
write_csv(out, P("output/tables/simulation_size_power.csv"))
print(out, width = 200)
