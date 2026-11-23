# Where in the AI stack is the exuberance?

**Layer-by-layer explosive-root (GSADF) tests on AI-related US stocks, and how robust the answer is to the definition of "explosive".**

Case study for *Time Series Analysis in Finance* (TSAF F2026), HSLU MSc Applied Information and Data Science.
Michele Mogos · Divya Shori | Lecturers: Thomas Ankenbrand, Denis Bieri

---

## Research questions

| | Question |
|---|---|
| **RQ1: Where** | Is exuberance a one-stock story (Nvidia), a chips story, or chain-wide across the AI value chain: chips, memory/storage/equipment, cloud, power & data centres, software? |
| **RQ2: Robustness** | Does the verdict survive changes of definition (log prices vs levels), critical values (wild bootstrap vs Monte Carlo), window (full vs post-ChatGPT) and market adjustment (raw vs relative to the S&P 500)? |
| **RQ3: Timing** | If several layers are exuberant, in which order did they start and end? (exploratory) |

Consumer staples act as a **control layer** that should *not* be flagged.

## Headline results (data to Oct 2026)

1. **Only one layer is robustly explosive: memory, storage & equipment.** It rejects the no-bubble null in **16/16** settings. Next come power & data centres (9/16), chips (5/16, all with Monte Carlo CVs), software (2/16) and cloud (1/16). The staples control rejects in 1/16 settings, a false alarm in the weakest cell (levels, Monte Carlo, short window).
2. **The memory verdict comes from a sub-segment, not from one stock.** Under wild-bootstrap CVs, leaving out MU, WDC *or* STX (any one) pushes the index just below the 5% CV, while leaving out any equipment name keeps the rejection. Individually only STX (and WDC post-2022) reject. The storage/memory names co-move, so aggregation *reveals* a common explosive component instead of masking it.
3. **Chips, the "obvious" AI layer, is not explosive in log prices** with wild-bootstrap CVs, either as an index or for any single chip stock (NVDA included). Chips is flagged only on price levels, or with Monte Carlo CVs, or at weekly frequency (May–Jun 2026).
4. **Definition drives the verdict (E3).** On price levels with Monte Carlo CVs, *all 12* bridge stocks (Magnificent 7 plus AVGO, AMD, ORCL, MU, PLTR) look explosive, MSFT and GOOGL included. The published "Nvidia is exuberant" result is reproduced only on levels. That setting flags steady compounding rather than acceleration.
5. **Timing (RQ3), post-ChatGPT:** power & data centres goes first (late 2023 to early 2025, strongest relative to the S&P 500). Memory/storage/equipment follows (Nov 2025/Jan 2026 to Jun 2026). Chips appears only briefly at weekly frequency (May–Jun 2026). Cloud and software show no post-2022 episode.

6. **Validation by simulation:** Monte Carlo CVs reject a bubble-free random walk 21–29% of the time after a volatility break; the wild bootstrap stays at 2–7% but detects a simulated bubble only 44% of the time at T = 47.

Full write-up: [`report/findings.md`](report/findings.md).

## Repository layout

```
data/
  constituents.csv        49 hand-selected stocks: layer, role (core/laggard/control), rationale
  benchmarks.csv          SPY (market adjustment), ETF cross-checks, bridge names AAPL/TSLA
  raw/daily_adjusted.csv  Yahoo Finance daily adjusted closes (cached for reproducibility)
  processed/              month-end and week-end prices, layer indices
R/
  00_config.R             sample dates, PSY window rules, replications, seed
  utils.R                 index construction, transformations, GSADF + date-stamping wrapper
  01_download.R           quantmod download (falls back to Yahoo chart API if rate-limited)
  02_build_indices.R      equal-weighted indices, coverage check, contribution shares
  03_adf.R                left-tailed ADF on prices/returns + residual diagnostics
  04_gsadf_main.R         MAIN: index-level GSADF + BSADF date-stamping; ETF cross-check
  05_sensitivity_grid.R   16-setting grid per layer; lag-1 check
  06_single_stocks.R      GSADF on every constituent; leave-one-out indices
  07_replication_weekly.R Nvidia/bridge replication; weekly vs monthly
  08_simulation.R         size and power of MC vs wild-bootstrap CVs
  09_figures.R            figures
output/tables/            all results as CSV
output/figures/           report figures
report/findings.md        results and interpretation
run_all.R                 runs the full pipeline
```

## Reproduce

Requires R ≥ 4.3 and the packages `exuber quantmod xts zoo dplyr tidyr readr purrr tibble ggplot2 urca scales jsonlite curl`.

```r
install.packages(c("exuber","quantmod","xts","zoo","dplyr","tidyr","readr","purrr",
                   "tibble","ggplot2","urca","scales","jsonlite","curl"))
```

```bash
Rscript run_all.R --no-download   # use the cached prices in data/raw (exact replication)
Rscript run_all.R                 # re-download from Yahoo first (prices may be revised)
```

Run from the repository root. Seeds are fixed (`SEED` in `00_config.R`). Runtime is about 25 minutes on 2 cores.

## Design decisions

**Index construction** (lecturer point 1)
- Each layer is an equal-weighted index of 8–9 stocks built from **monthly simple returns, rebalanced monthly**, rebased to 100 at end-January 2015.
- A stock contributes a return in month *t* only if it has a price at the end of both *t−1* and *t*. A listing month (partial) therefore never enters, and the stock joins from its first full month.
- An index starts once ≥ 4 constituents have prices. Every layer has ≥ 4 from Jan 2015 (`output/tables/coverage.csv`).
- Each layer deliberately includes **laggards** (INTC, QCOM, IBM, AKAM, DOCN, ADBE, TER) to limit hindsight bias.
- To check that individual stocks don't drive the results we use (a) contribution shares of each stock to the cumulative index return (`contributions.csv`), (b) leave-one-out indices under both CV types, and (c) GSADF on every constituent.

**Tests**
- GSADF (Phillips, Shi & Yu 2015) via `exuber`.
- Minimum window ⌊T(0.01 + 1.8/√T)⌋: 22 months for T = 142, 12 for the post-ChatGPT window (T = 47), 50 weeks for weekly.
- Minimum episode duration round(log T): 5 months, 4 months, 6 weeks.
- ADF lag 0 (lag 1 as a robustness check).
- 95% critical values from a wild bootstrap (999 draws, series-specific, robust to the ARCH effects found in `03_adf.R`) and from Monte Carlo (2,000 draws; 500 for weekly T).
- Date-stamped episodes are reported for every series, but are only interpreted as evidence where the series-level GSADF test rejects.

**Data limitations**
- Free Yahoo data exclude delisted firms, so survivorship bias is limited, not removed.
- Index dates are labelled with the first day of the month but refer to **month-end** prices.
- In weekly tables, the `months_explosive` column counts **weeks**.

## Sources

- Phillips, Shi & Yu (2015), *Testing for Multiple Bubbles*, International Economic Review.
- Vasilopoulos, Pavlidis & Martínez-García (2022), *exuber: Recursive Right-Tailed Unit Root Testing*, Journal of Statistical Software.
- Basele, Phillips & Shi, *From Innovation to Speculation: AI and the Magnificent Seven*, Cowles Foundation DP 2537 (2026).
- Wang & Chen, *Boom, Bubble, or Buildout?*, arXiv 2606.01575; Sarkar & Wells, arXiv 2604.12062; Chen et al., arXiv 2604.25826.
