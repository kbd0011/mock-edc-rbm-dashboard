# mock-edc-rbm-dashboard

[![pipeline](https://github.com/kbd0011/mock-edc-rbm-dashboard/actions/workflows/ci.yml/badge.svg)](https://github.com/kbd0011/mock-edc-rbm-dashboard/actions/workflows/ci.yml)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![Python 3.12](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)

Mock end-to-end EDC + Risk-Based Monitoring (RBQM) dashboard for a fictional Phase III plaque psoriasis trial (IMM-PSO-3001). CDASHIG 2.2 → SDTMIG 3.3, ICH E6(R3) Annex E + TransCelerate RBQM.

> **Live demo:** not yet deployed to shinyapps.io - the screenshots below are from the app running locally.

![KRI heatmap](docs/img/hero_heatmap.png)
*Site × KRI heatmap from the Overview tab. Tile color = threshold flag (red HIGH, yellow NORMAL, green LOW).*

## What this demonstrates

- **CDASHIG 2.2-aligned eCRF** - 6 forms (DM, IE, AE, CM, PASI, LB), 49 fields, all CDISC-named, in `metadata/fields_spec.xlsx`
- **35 edit checks across 6 categories** (Required / Range / Format / Cross-form temporal / Cross-form consistency / Plausibility) in `metadata/edit_checks.xlsx`
- **Declarative Python edit-check engine** that reads the spec, runs synthetic data, and emits a 548-row query log with summary JSON
- **CDASH → SDTM mapping** for DM, AE, LB using R (`metacore`, `xportr`); outputs `.rds` and `.xpt`
- **6 RBQM Key Risk Indicators** per ICH E6(R3) Annex E + TransCelerate framework: enrollment rate, query rate, AE reporting latency, protocol deviation rate, missing data rate, lab out-of-range rate - all with weekly time-series for sparklines
- **R Shiny dashboard** with Overview heatmap, KRI Detail drill-down, filterable Query Log, About; runs locally
- **Data Management Plan** (`docs/dmp.qmd`) - 12-page Quarto-rendered PDF following SCDM GCDMP structure
- **Annotated CRF PDF** (`crf/annotated_crf.qmd`) - stakeholder-readable form spec with CDASH variable annotations
- **6 static HTML eCRF mockups** showing the per-form data entry experience (`crf/mockups/`)
- **Reproducibility**: pinned renv lockfile (68 R packages), pinned Python requirements, GitHub Actions pipeline that rebuilds everything end-to-end on every push

## Dashboard tour

|  |  |
|---|---|
| ![Overview](docs/img/tour_overview.png) | **Overview** - site × KRI heatmap plus per-KRI HIGH-flag counts |
| ![KRI Detail](docs/img/tour_kri_detail.png) | **KRI Detail** - bar across sites, weekly time series, subject-level drill-down |
| ![Query Log](docs/img/tour_query_log.png) | **Query Log** - filterable by site / form / severity / status; CSV download |
| ![eCRF Mockup](docs/img/tour_ecrf.png) | **eCRF mockups** - Bootstrap-styled static screens, screenshot-ready |

## Stack

| Layer | Technology |
|---|---|
| Synthetic data | Python 3.12 (`pandas`, `faker`, `click`, `pyyaml`) - seeded, deterministic |
| Edit-check engine | Python (declarative, YAML/Excel-driven; registry-pattern handlers) |
| CDASH→SDTM mapping | R (`dplyr`, `metacore`, `metatools`, `xportr`) |
| KRI computation | R |
| Dashboard | R Shiny + `bslib` (Bootstrap 5 flatly) + `plotly` + `DT` |
| Documents | Quarto → PDF (`flextable`, LuaTeX) |
| Reproducibility | `renv` + `requirements.txt` + Makefile + GitHub Actions |
| Deployment | shinyapps.io free tier |

## Repository structure

```
.
├── README.md
├── LICENSE                    # MIT
├── Makefile                   # reproducibility contract
├── _quarto.yml
├── renv.lock                  # 68 R packages pinned
├── requirements.txt           # Python deps
│
├── docs/                      # protocol summary, DMP, KRI definitions
│   ├── protocol_summary.md
│   ├── kri_definitions.md
│   ├── dmp.qmd  / dmp.pdf
│   └── img/                   # screenshots for the README
│
├── crf/
│   ├── annotated_crf.qmd / annotated_crf.pdf
│   └── mockups/               # 6 static HTML eCRF mockups
│
├── metadata/                  # generator scripts + their .xlsx/.yml outputs
│
├── synthetic/raw/             # generated CDASH CSVs (committed, deterministic)
│
├── python/
│   ├── synth_generator.py
│   └── edit_checks/           # runner.py, reporters.py, checks/*.py
│
├── R/                         # 00_setup.R, 01_cdash_to_sdtm.R, 02_compute_kris.R
│
├── shiny/                     # app.R + R/ui_*.R + R/server_*.R + www/style.css
│
├── tests/                     # pytest + testthat
│
└── .github/workflows/ci.yml
```

## Run locally

Requirements: Python 3.12+, R 4.6.0, Quarto 1.6+, TinyTeX (or another LaTeX). On macOS, R packages compile from source - give the first install ~10 minutes.

```bash
# 1. Bootstrap envs (one-time)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
Rscript R/install_packages.R

# 2. Build everything from scratch
make clean && make all

# 3. Run the dashboard
make app
# Then open http://127.0.0.1:<port>/ in a browser
```

Pipeline order (per the Makefile): `metadata` → `synth` → `checks` → `sdtm` → `kris` → `docs` → `test`.

## Standards & references

- **CDISC CDASHIG v2.2** - eCRF field naming
- **CDISC SDTMIG v3.3** - downstream mapping target
- **ICH E6(R3)** Annex E - Centralized monitoring
- **ICH E2A** - AE/SAE definitions and reporting timelines
- **SCDM** - Good Clinical Data Management Practice (GCDMP)
- **TransCelerate RBQM Framework** - KRI catalogue and thresholds
- **21 CFR Part 11** - Audit trail, electronic signatures, access control

## Notes on the demo

- Subjects, sites, IP-301, and the sponsor (Helix Therapeutics) are entirely fictional. The trial design and pharmacology mirror real Phase III IL-23 inhibitor immunology studies for portfolio realism.
- The dashboard is deliberately biased to show signal: two of eight sites (`S005`, `S007`) have inflated error rates so multiple KRIs flag HIGH. Reviewers can see what an actionable dashboard view looks like.
- See `docs/kri_definitions.md` for the full KRI contract (numerators, denominators, snapshot logic, thresholds) and `docs/dmp.qmd` for the Data Management Plan that ties everything together.

## License

MIT. See `LICENSE`.
