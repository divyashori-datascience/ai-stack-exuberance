# =============================================================================
# 09_figures.R — figures for the report
# =============================================================================
source("R/00_config.R")
theme_set(theme_minimal(base_size = 11) +
            theme(panel.grid.minor = element_blank(), plot.title.position = "plot",
                  legend.position = "bottom", strip.text = element_text(face = "bold")))
PAL <- c(chips = "#2a6f97", memory_equipment = "#c1121f", cloud = "#6a4c93",
         power_datacentre = "#e09f3e", software = "#2b9348", staples = "#7f7f7f", SPY = "#000000")
lab <- c(LAYER_LABELS, SPY = "S&P 500 (SPY)")
save <- function(p, f, w = 9, h = 5.5) ggsave(P("output/figures", f), p, width = w, height = h, dpi = 200, bg = "white")

idx <- read_csv(P("data/processed/layer_indices_monthly.csv"), show_col_types = FALSE)
long <- idx |> pivot_longer(-date, names_to = "series", values_to = "index")

# 1. Layer indices (log scale)
p1 <- ggplot(long, aes(date, index, colour = series)) +
  geom_vline(xintercept = CHATGPT_DATE, linetype = 2, colour = "grey50") +
  annotate("text", x = CHATGPT_DATE, y = 9000, label = "ChatGPT launch", hjust = 1.05, size = 3, colour = "grey40") +
  geom_line(linewidth = 0.8) + scale_y_log10(labels = scales::comma) +
  scale_colour_manual(values = PAL, labels = lab, name = NULL) +
  labs(title = "Equal-weighted AI-layer indices, Jan 2015 = 100 (log scale)",
       subtitle = "Monthly, rebalanced monthly; staples as control; SPY as market benchmark", x = NULL, y = NULL)
save(p1, "01_layer_indices.png")

# 2. BSADF sequences vs 95% wild-bootstrap critical values, with date-stamped episodes
bs  <- read_csv(P("output/tables/bsadf_main.csv"), show_col_types = FALSE) |> filter(cv_type == "wb")
eps <- read_csv(P("output/tables/episodes_main.csv"), show_col_types = FALSE) |> filter(cv_type == "wb")
gs  <- read_csv(P("output/tables/gsadf_main.csv"), show_col_types = FALSE) |> filter(cv_type == "wb") |>
  mutate(stars = coalesce(stars, ""),
         strip = paste0(lab[series], "\nGSADF ", sprintf("%.2f", gsadf), stars, "  (95% CV ", sprintf("%.2f", cv95), ")"))
strip_lab <- setNames(gs$strip, gs$series)
ord <- c(LAYERS, "SPY")
p2 <- ggplot(bs |> mutate(series = factor(series, ord))) +
  geom_rect(data = eps |> mutate(series = factor(series, ord)),
            aes(xmin = start, xmax = end + 27, ymin = -Inf, ymax = Inf), fill = "#c1121f", alpha = 0.15) +
  geom_line(aes(date, bsadf), linewidth = 0.6) +
  geom_line(aes(date, cv95), colour = "#c1121f", linetype = 2) +
  facet_wrap(~series, ncol = 2, labeller = as_labeller(strip_lab)) +
  labs(title = "BSADF sequences and date-stamped explosive episodes (primary setting)",
       subtitle = "Log prices, full sample, raw, lag 0, wild-bootstrap 95% CV (dashed). Shaded: >= 5 consecutive months above CV",
       x = NULL, y = "BSADF")
save(p2, "02_bsadf_datestamping.png", h = 9)

# 3. Sensitivity grid heatmap (16 settings x 6 layers)
grid <- read_csv(P("output/tables/gsadf_grid.csv"), show_col_types = FALSE) |>
  mutate(stars = coalesce(stars, ""),
         setting = paste(definition, toupper(cv_type), window, adjust, sep = " | "),
         ratio = gsadf / cv95,
         layer = factor(lab[layer], lab[LAYERS]))
p3 <- ggplot(grid, aes(layer, setting, fill = ratio)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = paste0(sprintf("%.2f", gsadf), stars)), size = 3) +
  scale_fill_gradient2(low = "#2a6f97", mid = "white", high = "#c1121f", midpoint = 1,
                       name = "GSADF / 95% CV") +
  labs(title = "Sensitivity grid: GSADF statistic under 16 settings",
       subtitle = "Definition | critical values (WB = wild bootstrap, MC = Monte Carlo) | window | market adjustment.  * 10%  ** 5%  *** 1%",
       x = NULL, y = NULL) + theme(axis.text.x = element_text(angle = 20, hjust = 1))
save(p3, "03_sensitivity_grid.png", h = 7)

# 4. Individual stocks: GSADF / CV by layer (full and post windows)
st <- read_csv(P("output/tables/gsadf_stocks.csv"), show_col_types = FALSE) |>
  mutate(ratio = gsadf / cv95, layer_lab = factor(ifelse(layer == "bridge", "Bridge (AAPL, TSLA)", lab[layer]),
                                                  c(lab[LAYERS], "Bridge (AAPL, TSLA)")),
         window = factor(ifelse(window == "full", "Full sample", "Post-ChatGPT"), c("Full sample", "Post-ChatGPT")))
p4 <- ggplot(st, aes(ratio, reorder(ticker, ratio), colour = reject_95)) +
  geom_vline(xintercept = 1, linetype = 2) + geom_point(size = 2) +
  facet_grid(layer_lab ~ window, scales = "free_y", space = "free_y") +
  scale_colour_manual(values = c(`FALSE` = "grey55", `TRUE` = "#c1121f"), labels = c("not rejected", "explosive at 5%"), name = NULL) +
  labs(title = "Individual stocks: GSADF statistic relative to its wild-bootstrap 95% CV",
       subtitle = "Log prices, raw, lag 0. Right of the dashed line = explosive at 5%", x = "GSADF / 95% CV", y = NULL) +
  theme(strip.text.y = element_text(angle = 0, hjust = 0))
save(p4, "04_single_stocks.png", w = 10, h = 12)

# 5. Leave-one-out
loo <- read_csv(P("output/tables/gsadf_leave_one_out.csv"), show_col_types = FALSE) |>
  mutate(layer_lab = factor(lab[layer], lab[LAYERS]), ratio = gsadf / cv95,
         cv_type = ifelse(cv_type == "wb", "Wild bootstrap", "Monte Carlo"))
p5 <- ggplot(loo |> filter(dropped != "none"), aes(ratio, layer_lab)) +
  geom_vline(xintercept = 1, linetype = 2) +
  geom_point(aes(colour = reject_95), position = position_jitter(height = 0.15, seed = 1), size = 2) +
  geom_text(aes(label = dropped), size = 2.4, vjust = -0.9, check_overlap = TRUE) +
  geom_point(data = loo |> filter(dropped == "none"), shape = 4, size = 4, stroke = 1.2) +
  facet_wrap(~cv_type) +
  scale_colour_manual(values = c(`FALSE` = "grey55", `TRUE` = "#c1121f"), labels = c("not rejected", "explosive at 5%"), name = NULL) +
  labs(title = "Leave-one-out: does a single stock drive the layer verdict?",
       subtitle = "Each dot = layer index without one stock (label). X = full index. Log, full sample, raw.",
       x = "GSADF / 95% CV", y = NULL)
save(p5, "05_leave_one_out.png", w = 10, h = 5.5)

# 6. Timeline of date-stamped episodes (RQ3), primary setting, post-2022 shown in context
p6 <- ggplot(eps |> mutate(series = factor(lab[series], rev(lab[ord])))) +
  geom_vline(xintercept = CHATGPT_DATE, linetype = 2, colour = "grey50") +
  geom_segment(aes(x = start, xend = end + 27, y = series, yend = series, colour = series), linewidth = 5) +
  scale_colour_manual(values = setNames(PAL, lab[names(PAL)]), guide = "none") +
  scale_x_date(limits = range(idx$date)) +
  labs(title = "Date-stamped explosive episodes by layer (RQ3: timing)",
       subtitle = "Primary setting; BSADF above wild-bootstrap 95% CV for >= 5 months.\nEpisodes are reported even where GSADF does not reject; read them together with the GSADF verdict.",
       x = NULL, y = NULL)
save(p6, "06_episode_timeline.png", h = 4)
message("Figures written to output/figures/")
