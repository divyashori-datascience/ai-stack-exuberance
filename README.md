# Where in the AI Stack Is the Exuberance?

GSADF bubble tests across five layers of the AI value chain, with consumer staples as a control.
Monthly US stock data, January 2015 – October 2026, analysed in R with `exuber`.

**Course:** Time Series Analysis in Finance (TSAF F2026), HSLU MSc Applied Information and Data Science
**Authors:** Divya Shori, Michele Mogos
**Lecturers:** Thomas Ankenbrand, Denis Bieri

---

## Contents

1. [Research Questions](#1-research-questions)
2. [Key Findings](#2-key-findings)
3. [Repository Structure](#3-repository-structure)
4. [Data](#4-data)
5. [Methodology](#5-methodology)
6. [How to Run](#6-how-to-run)
7. [Outputs](#7-outputs)
8. [Limitations](#8-limitations)
9. [References](#9-references)

---

## 1. Research Questions

Instead of asking whether "AI" as a whole is in a bubble, we test **which layer** of the AI value chain shows explosive price behaviour.

| | Question |
|---|---|
| **RQ1 — Where** | Is exuberance a single-stock story (Nvidia), a chips story, or spread across the whole value chain? |
| **RQ2 — Robustness** | Does the verdict survive changes in definition (log prices vs levels), critical values (wild bootstrap vs Monte Carlo), window (full vs post-ChatGPT) and market adjustment (raw vs relative to the S&P 500)? |
| **RQ3 — Timing** | If several layers are exuberant, in which order did their episodes start and end? |

**The five AI layers:**
- chips
- memory, storage & equipment
- cloud
- power & data centres
- software

**Control:** consumer staples, which should *not* be flagged.

---

## 2. Key Findings

| # | Finding |
|---|---|
| 1 | **Only memory, storage & equipment is robustly explosive.** It rejects the no-bubble null in 16 of 16 settings. Next: power & data centres 9/16, chips 5/16, software 2/16, cloud 1/16. |
| 2 | **The memory result comes from a sub-segment, not a single stock.** Removing MU, WDC or STX weakens it; removing any equipment maker does not. |
| 3 | **Chips is not explosive in log prices**, neither as an index nor for any single chip stock, Nvidia included. |
| 4 | **The definition drives the verdict.** On price levels with Monte Carlo critical values, all 12 big-tech stocks look explosive, Microsoft and Alphabet included. That setting picks up steady growth, not bubbles. |
| 5 | **Timing:** power & data centres (2023–25) → memory/storage (late 2025 to mid-2026) → chips only briefly (mid-2026). |
| 6 | **Simulation check:** Monte Carlo critical values wrongly flag up to 29% of bubble-free series when volatility shifts; the wild bootstrap stays at 2–7%. |

Full results and interpretation: [`report/findings.md`](report/findings.md)

---

## 3. Repository Structure

```
ai-stack-exuberance/
│
├── README.md                        Project overview (this file)
├── run_all.R                        Runs the full pipeline end to end
│
├── data/
│   ├── constituents.csv             49 stocks: layer, role, selection rationale
│   ├── benchmarks.csv               S&P 500 (SPY), ETF cross-checks, bridge stocks
│   ├── raw/
│   │   └── daily_adjusted.csv       Daily adjusted prices from Yahoo Finance
│   └── processed/
│       ├── monthly_prices.csv       Month-end prices
│       ├── weekly_prices.csv        Week-end prices
│       ├── layer_indices_monthly.csv
│       └── layer_indices_weekly.csv
│
├── R/
│   ├── 00_config.R                  Sample dates, window rules, seeds
│   ├── utils.R                      Index construction and GSADF helpers
│   ├── 01_download.R                Step 1 · Download prices
│   ├── 02_build_indices.R           Step 2 · Build equal-weighted layer indices
│   ├── 03_adf.R                     Step 3 · Standard ADF baseline
│   ├── 04_gsadf_main.R              Step 4 · MAIN: index-level GSADF + date-stamping
│   ├── 05_sensitivity_grid.R        Step 5 · 16-setting robustness grid
│   ├── 06_single_stocks.R           Step 6 · Individual stocks + leave-one-out
│   ├── 07_replication_weekly.R      Step 7 · Nvidia replication + weekly check
│   ├── 08_simulation.R              Step 8 · Size and power simulation
│   └── 09_figures.R                 Step 9 · Figures
│
├── output/
│   ├── tables/                      All results as CSV
│   └── figures/                     Report figures (PNG)
│
└── report/
    └── findings.md                  Results write-up
```

---

## 4. Data

| Item | Detail |
|---|---|
| **Source** | Yahoo Finance (`quantmod`), daily adjusted closes |
| **Period** | January 2015 – October 2026 (T = 142 months) |
| **Universe** | 49 US-listed stocks across 5 AI layers + staples control (8–9 per layer) |
| **Benchmark** | S&P 500 (SPY) for market adjustment |
| **Cross-checks** | SMH, IGV, SKYY, XLP sector ETFs |

**Index construction**
- Each layer is an **equal-weighted index**, rebalanced monthly and rebased to 100 at January 2015.
- A stock enters from its first **full** month of trading.
- An index starts once at least 4 stocks have prices. All layers meet this from the start.
- Each layer deliberately includes **laggards** (e.g. Intel, IBM, Adobe) to limit hindsight bias.

---

## 5. Methodology

| Step | Method | Purpose |
|---|---|---|
| Baseline | Left-tailed ADF on prices and returns | Confirm unit root in prices, stationary returns |
| **Main** | Right-tailed GSADF (Phillips, Shi & Yu 2015) | Test each layer for explosive behaviour |
| Date-stamping | BSADF sequence vs critical values | Identify when episodes start and end |
| Critical values | Wild bootstrap (primary) and Monte Carlo | Wild bootstrap is robust to changing volatility |
| Robustness | 16-setting grid, lag 1, single stocks, leave-one-out | Check the verdict is not an artefact |
| Validation | Simulation of random walks and bubbles | Measure false-alarm rate and detection power |

**Key settings**

| Parameter | Value |
|---|---|
| Minimum window | ⌊T(0.01 + 1.8/√T)⌋ → 22 months (full), 12 months (post-ChatGPT) |
| Minimum episode length | round(log T) → 5 months (full), 4 months (post-ChatGPT) |
| ADF lag | 0 (lag 1 as a robustness check) |
| Bootstrap draws | 999 wild bootstrap, 2,000 Monte Carlo |
| Significance | 5% |

---

## 6. How to Run

**Requirements:** R ≥ 4.3

```r
install.packages(c("exuber", "quantmod", "xts", "zoo", "dplyr", "tidyr", "readr",
                   "purrr", "tibble", "ggplot2", "urca", "scales", "jsonlite", "curl"))
```

**Run from the repository root:**

```bash
# Option A — use the cached data (exact replication)
Rscript run_all.R --no-download

# Option B — download fresh data first
Rscript run_all.R
```

Runtime is about 20 minutes. Seeds are fixed, so results are reproducible.

---

## 7. Outputs

| File | Content |
|---|---|
| `output/tables/gsadf_main.csv` | Main index-level results |
| `output/tables/episodes_main.csv` | Date-stamped explosive episodes |
| `output/tables/gsadf_grid.csv` | 16-setting sensitivity grid |
| `output/tables/gsadf_stocks.csv` | Individual-stock results |
| `output/tables/gsadf_leave_one_out.csv` | Leave-one-out results |
| `output/tables/replication_bridge.csv` | Nvidia / big-tech replication |
| `output/tables/simulation_size_power.csv` | Simulation results |
| `output/figures/` | Six figures used in the report |

---

## 8. Limitations

- **Survivorship bias:** Yahoo data exclude delisted firms.
- **Hindsight in selection:** reduced by including laggards in every layer.
- **Short post-ChatGPT window:** with 47 months, the test has limited power to detect bubbles.
- **Weekly check:** uses Monte Carlo critical values only; the wild bootstrap was too slow at weekly frequency.
- **Date labels:** index dates show the first day of the month but refer to month-end prices.

---

## 9. References

- Phillips, P. C. B., Shi, S. & Yu, J. (2015). Testing for Multiple Bubbles. *International Economic Review*.
- Vasilopoulos, K., Pavlidis, E. & Martínez-García, E. (2022). exuber: Recursive Right-Tailed Unit Root Testing with R. *Journal of Statistical Software*.
- Basele, Phillips & Shi (2026). From Innovation to Speculation: AI and the Magnificent Seven. Cowles Foundation Discussion Paper 2537.
