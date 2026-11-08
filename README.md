# mock-edc-rbm-dashboard

[![pipeline](https://github.com/kbd0011/mock-edc-rbm-dashboard/actions/workflows/ci.yml/badge.svg)](https://github.com/kbd0011/mock-edc-rbm-dashboard/actions/workflows/ci.yml)
[![R 4.6.0](https://img.shields.io/badge/R-4.6.0-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![Python 3.12](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)

Mock end-to-end EDC + Risk-Based Quality Management (RBQM) build for a fictional Phase III plaque psoriasis trial (IMM-PSO-3001): eCRF specification, edit-check engine, CDASH → SDTM mapping, Key Risk Indicators and an R Shiny monitoring dashboard. CDASHIG 2.2 → SDTMIG 3.3, ICH E6(R3) centralized monitoring, TransCelerate RBQM.

All subject data are synthetic, produced by a seeded Python generator (`python/synth_generator.py`). One `make all` rebuilds every dataset, query log, KRI table and PDF from the specs.

## What this demonstrates

- **CDASHIG 2.2-aligned eCRF** - 6 forms (DM, IE, AE, CM, PASI, LB) with 49 fields, each named to CDASHIG conventions and given an SDTM target, in `metadata/fields_spec.xlsx`
- **35 edit checks across 6 categories** (Required / Range / Format / Cross-form temporal / Cross-form consistency / Plausibility) in `metadata/edit_checks.xlsx`; together the checks cover 26 variables
- **Spec-driven Python edit-check engine** - reads `edit_checks.xlsx`, routes required, range, format and plausibility checks to generic handlers and the 12 cross-form checks to a handler registry, and writes a query log with a JSON summary: 548 queries across 8 sites on the committed synthetic data
- **CDASH → SDTM mapping** for DM, AE and LB in R (`dplyr`), with a hand-built MedDRA term lookup for AE coding; specified in `metadata/mapping_spec.xlsx` (44 rows) and written as `.rds` and SAS v5 transport `.xpt` files (`haven`)
- **6 RBQM Key Risk Indicators**, each with a written formula in `docs/kri_definitions.md`: enrollment rate, query rate, AE reporting latency, protocol deviation rate, missing data rate and lab out-of-range rate. Five have flag thresholds; lab out-of-range rate has none and is informational, for safety review. All six have weekly time series for sparklines
- **R Shiny dashboard** with Overview heatmap, KRI Detail drill-down, filterable Query Log and About tabs
- **Data Management Plan** (`docs/dmp.qmd`) - 12-page Quarto-rendered PDF following SCDM GCDMP structure
- **Annotated CRF PDF** (`crf/annotated_crf.qmd`) - stakeholder-readable form spec with CDASH variable annotations
- **6 static HTML eCRF mockups** showing the per-form data entry experience (`crf/mockups/`)
- **Tests** - pytest for the edit-check handlers and testthat for the SDTM builders and KRI functions: 25 test cases, 47 assertions (`tests/`)
- **Reproducibility** - renv lockfile pinning R 4.6.0 and 151 packages, pinned Python requirements, a Makefile pipeline, and a GitHub Actions workflow that regenerates metadata, synthetic data, the query log, SDTM datasets and KRIs, runs both test suites and renders the PDFs on every push to `main`

## Dashboard tour

Run `make app` to open it locally.

- **Overview** - site × KRI heatmap colored by flag (red HIGH, yellow NORMAL, green LOW) and a count of flagged sites per KRI. Clicking a tile opens that site and KRI in KRI Detail.
- **KRI Detail** - bar chart comparing all eight sites, weekly time series for the chosen site, and a subject-level drill-down table.
- **Query Log** - filter by site, form, severity and status, with totals for open queries, errors and warnings; download the filtered log as CSV.
- **eCRF mockups** - six static Bootstrap 5 pages in `crf/mockups/`, one per form, showing the data-entry layout.

## Stack

| Layer | Technology |
|---|---|
| Synthetic data | Python 3.12 (`pandas`, `faker`, `click`, `pyyaml`) - seeded, deterministic |
| Edit-check engine | Python (spec-driven from `edit_checks.xlsx`; registry of cross-form handlers) |
| CDASH→SDTM mapping | R (`dplyr`, `haven` for `.xpt`) |
| KRI computation | R |
| Dashboard | R Shiny + `bslib` (Bootstrap 5 flatly) + `plotly` + `DT` |
| Documents | Quarto → PDF (`flextable`, LuaTeX) |
| Reproducibility | `renv` + `requirements.txt` + Makefile + GitHub Actions |
| Deployment | `make deploy` bundles the app and its data for shinyapps.io |

## Repository structure

```
.
├── README.md
├── LICENSE                    # MIT
├── Makefile                   # reproducibility contract
├── _quarto.yml
├── renv.lock                  # R 4.6.0 + 151 packages pinned
├── requirements.txt           # Python deps
│
├── docs/                      # protocol summary, DMP, KRI definitions
│   ├── protocol_summary.md
│   ├── kri_definitions.md
│   └── dmp.qmd  / dmp.pdf
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
- **ICH E6(R3)** - Risk-based quality management and centralized monitoring
- **ICH E2A** - AE/SAE definitions and reporting timelines
- **SCDM** - Good Clinical Data Management Practice (GCDMP)
- **TransCelerate RBQM Framework** - KRI catalogue and thresholds
- **21 CFR Part 11** - Audit trail, electronic signature and access-control sections of the DMP

## Notes on the data

- Subjects, sites, IP-301 and the sponsor (Helix Therapeutics) are fictional. The trial design is modeled on Phase III IL-23 inhibitor studies in plaque psoriasis.
- The generator seeds two of eight sites (`S005`, `S007`) as problem sites with higher error rates (`metadata/error_profile.yml`), so the dashboard has signal to find: in the committed snapshot (`data/kris.rds`), S005 flags HIGH on four KRIs and S007 on three.
- See `docs/kri_definitions.md` for the full KRI contract (numerators, denominators, snapshot logic, thresholds) and `docs/dmp.qmd` for the Data Management Plan that ties everything together.

## Scope and limitations

- Edit checks run as a batch over the form CSVs, the way a scheduled EDC check job would; the eCRF itself exists as specs and static mockups, not a data-entry system.
- AE coding uses a hand-built MedDRA lookup sized to the synthetic terms, not a licensed dictionary.
- SDTM output covers DM, AE and LB; there is no define.xml or conformance-checker run.
- The dashboard runs locally with `make app` and has not been published to shinyapps.io.

## License

MIT. See `LICENSE`.
