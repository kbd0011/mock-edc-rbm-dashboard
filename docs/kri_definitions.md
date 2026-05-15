# KRI Definitions — IMM-PSO-3001

Operational definitions for the 6 Key Risk Indicators surfaced in the RBQM Shiny dashboard. Written **before** the synthetic data model so the data layer reflects what the KRIs actually need (per `heads_up.md`).

Aligned to ICH E6(R3) Annex E centralized monitoring and the TransCelerate RBQM framework. Each KRI specifies: data source, formula, time grain, threshold logic, and dashboard rendering. Downstream code (`R/02_compute_kris.R`, `python/synth_generator.py`, `shiny/R/server_*.R`) must honor this contract.

---

## Conventions

- **Computation grain:** per `SITEID`. All KRIs roll up to a site, with subject-level drill-down on the KRI Detail tab.
- **Snapshot date:** all rolling/cumulative metrics are computed as of `snapshot_date`, which defaults to `max(RFSTDTC, AESTDTC, LBDTC, query_log.timestamp)` across the loaded data. A single snapshot per pipeline run.
- **Flag values:** `HIGH`, `LOW`, `NORMAL`. `HIGH`/`LOW` mean "outside the expected band and warrants reviewer attention." Not all KRIs use `LOW` (see per-KRI notes).
- **Output schema:** every KRI emits rows into the long tibble `data/kris.rds` with columns `site, kri_name, value, date, threshold_flag, denominator`. A parallel `data/kris_timeseries.rds` holds weekly bins for sparklines: `site, kri_name, week_start, value, threshold_flag`.

---

## KRI-01 — Enrollment Rate

- **Category:** Operational
- **Definition:** Subjects randomized per site, normalized to subjects-per-month, over a rolling 90-day window ending at `snapshot_date`.
- **Numerator:** count of `DM` rows where `RFSTDTC` is within `[snapshot_date - 90d, snapshot_date]`, grouped by `SITEID`.
- **Denominator:** 3 (months in window).
- **Formula:** `value = n_subjects_in_window / 3`.
- **Time grain:** rolling 90-day snapshot. Time series: weekly bins, value = 90-day window ending each Sunday.
- **Thresholds:**
  - `value < 0.5` → `LOW` (under-enrolling site, risk to timeline)
  - `value > 2.0` → `HIGH` (potential consent quality / source verification concerns)
  - else → `NORMAL`
- **Rationale for thresholds:** Phase III plaque psoriasis trials with 8 sites and N=150 over 18 months target ~1.0 subjects/site/month. `<0.5` and `>2.0` are standard TransCelerate-style ±2σ-ish bands.
- **Required upstream fields:** `DM.SITEID`, `DM.SUBJID`, `DM.RFSTDTC`.
- **Dashboard:** heatmap tile + value_box; KRI Detail tab shows site bar chart, weekly time series, and subject-level table for the flagged site.

---

## KRI-02 — Query Rate

- **Category:** Data Quality
- **Definition:** Open queries per subject per site, snapshot.
- **Numerator:** count of rows in `data/queries/query_log.csv` with `status == "Open"`, grouped by `site`.
- **Denominator:** count of distinct `SUBJID` per site from `DM`.
- **Formula:** `value = n_open_queries / n_subjects`.
- **Time grain:** snapshot at `snapshot_date`. Time series: cumulative open queries / cumulative subjects by week.
- **Thresholds:**
  - `value > 5.0` → `HIGH` (high query burden — possible CRA training gap or site data hygiene issue)
  - else → `NORMAL`
  - No `LOW` flag (zero queries is suspicious in practice but not actionable as a flag here).
- **Rationale:** TransCelerate central monitoring benchmarks place healthy Phase III data-management trials at 1–3 open queries per subject; >5 indicates a clear outlier.
- **Required upstream fields:** `query_log.site`, `query_log.subjid`, `query_log.status`; `DM.SITEID`, `DM.SUBJID`.
- **Dashboard:** heatmap tile, value_box; Query Log tab shows the underlying queries with filters.

---

## KRI-03 — AE Reporting Latency

- **Category:** Safety
- **Definition:** Median days between AE onset (`AESTDTC`) and AE form entry (`AE_ENTRY_DTC`) per site.
- **Numerator:** `median(AE_ENTRY_DTC - AESTDTC)` in whole days, per `SITEID`.
- **Denominator:** n/a (median, not ratio).
- **Time grain:** rolling 90-day window of AEs with `AESTDTC` in `[snapshot_date - 90d, snapshot_date]`. Time series: weekly median over the rolling window.
- **Thresholds:**
  - `median > 5 days` → `HIGH` (slow reporting — regulatory and patient-safety concern)
  - else → `NORMAL`
- **Rationale:** ICH E2A SAE reporting is 24h/7d for sponsor → regulator, but site → sponsor data entry is conventionally targeted within 5 calendar days for non-serious AEs. 5d is the operational standard for entry latency.
- **Required upstream fields:** `AE.SITEID`, `AE.SUBJID`, `AE.AESTDTC`, `AE.AE_ENTRY_DTC`.
- **Note on synthetic data:** `synth_generator.py` must generate `AE_ENTRY_DTC = AESTDTC + Exp(mean=2d) + occasional outliers`, with site-correlated latency (1–2 "slow" sites have mean ~6d).
- **Dashboard:** heatmap tile, value_box, time-series sparkline of weekly median.

---

## KRI-04 — Protocol Deviation Rate

- **Category:** Compliance
- **Definition:** Protocol deviations per 10 enrolled subjects, per site, cumulative.
- **Numerator:** count of rows in `synthetic/raw/protocol_deviations.csv` per `SITEID`.
- **Denominator:** count of distinct `SUBJID` per site from `DM`, divided by 10.
- **Formula:** `value = n_deviations / (n_subjects / 10)`.
- **Time grain:** cumulative as of `snapshot_date`. Time series: cumulative count by week.
- **Thresholds:**
  - `value > 3` → `HIGH` (more than 3 deviations per 10 subjects — indicates protocol compliance issue)
  - else → `NORMAL`
- **Rationale:** Across Phase III oncology and immunology trials, TransCelerate benchmarks target <2–3 major deviations per 10 subjects as the acceptable range.
- **Required upstream fields:** `protocol_deviations.site`, `protocol_deviations.subjid`, `protocol_deviations.deviation_date`, `protocol_deviations.category`.
- **Note on synthetic data:** generate a separate `protocol_deviations.csv` (~30–50 rows total) with categories drawn from {visit window violation, missed assessment, eligibility breach, dosing error, ICF re-consent missed}. Skew counts so 1–2 sites are flagged HIGH.
- **Dashboard:** heatmap tile, value_box, KRI Detail tab shows deviations broken down by category.

---

## KRI-05 — Missing Data Rate (Required Fields)

- **Category:** Data Quality
- **Definition:** Percentage of required-field cells that are blank, across all forms with required fields, per site.
- **Numerator:** count of blank cells where `metadata/fields_spec.xlsx::RequiredYN == "Y"`, summed across all required fields for subjects at the site.
- **Denominator:** total count of required-field cells expected for subjects at the site (per visit schedule from `protocol_summary.md`).
- **Formula:** `value = blank_required_cells / expected_required_cells * 100` (as a percentage).
- **Time grain:** snapshot. Time series: weekly snapshot.
- **Thresholds:**
  - `value > 10%` → `HIGH` (excessive missingness; possible site/CRF design issue)
  - else → `NORMAL`
- **Rationale:** SCDM GCDMP and FDA submission practice target <2–5% missing required-field data for analysis-quality datasets; >10% triggers escalation.
- **Required upstream fields:** every form CSV with required-field columns; `metadata/fields_spec.xlsx::RequiredYN`.
- **Note on synthetic data:** `error_profile.yml::missing_required_fields.rate = 0.02` (2% baseline). Bias 1 site to ~12% to surface a HIGH flag.
- **Dashboard:** heatmap tile, value_box; KRI Detail shows missingness broken down by form.

---

## KRI-06 — Lab Out-of-Range Rate

- **Category:** Safety review (not a quality flag)
- **Definition:** Percentage of `LB` records where `LBORRES` falls outside `[LBSTNRLO, LBSTNRHI]`, per site.
- **Numerator:** count of `LB` rows where `LBORRES < LBSTNRLO OR LBORRES > LBSTNRHI`, grouped by `SITEID`.
- **Denominator:** total `LB` row count per site.
- **Formula:** `value = n_oor / n_total * 100`.
- **Time grain:** cumulative as of `snapshot_date`. Time series: weekly cumulative.
- **Thresholds:**
  - **No quality threshold.** Always `NORMAL` for flag purposes. The KRI is surfaced to support clinical/safety review, not as a data-quality flag — high OOR rates can reflect true biological signal in a population with hepatic comorbidities (e.g., MTX users in psoriasis).
  - Dashboard renders the value in informational color (blue), not red/yellow/green.
- **Rationale:** Spec note from `ARCHITECTURE.md` (line 197): "not a quality flag — for safety review". Including it gives the dashboard a clinical-monitoring lens alongside the operational/data-quality KRIs.
- **Required upstream fields:** `LB.SITEID`, `LB.LBORRES`, `LB.LBSTNRLO`, `LB.LBSTNRHI`. These are populated during CDASH→SDTM mapping (`R/01_cdash_to_sdtm.R`).
- **Dashboard:** heatmap tile rendered in informational shade; KRI Detail shows OOR rate by lab test (WBC, HGB, PLT, ALT, AST, CREAT).

---

## Data Contract Summary (what the synth generator must produce)

For the KRIs above to compute correctly, `python/synth_generator.py` must emit:

| Form / file | Must include columns |
|---|---|
| `synthetic/raw/dm.csv` | `SITEID`, `SUBJID`, `RFSTDTC` (= TRTSDT in DM/EX merge), demographics |
| `synthetic/raw/ae.csv` | `SITEID`, `SUBJID`, `AESTDAT`, `AE_ENTRY_DTC` (new — site-correlated latency), `AETERM`, `AESEV`, `AESER` |
| `synthetic/raw/lb.csv` | `SITEID`, `SUBJID`, `LBTESTCD`, `LBORRES`, `LBDAT` (and units; LBSTNRLO/HI derived in R) |
| `synthetic/raw/protocol_deviations.csv` | `SITEID`, `SUBJID`, `deviation_date`, `category` (~30–50 rows total) |
| All forms | required-field columns blank at ~2% baseline; 1 site biased to ~12% to flag KRI-05 |
| `data/queries/query_log.csv` | `site`, `subjid`, `status`, plus the edit-check engine's standard cols — produced by `python/edit_checks/runner.py`, not by `synth_generator.py` |

This contract drives the `synth_generator.py` design in task #6.

---

## Open questions / decisions to make

- **Should KRI-05 (missing data) include date fields, or restrict to non-date required fields?** Decision: include all required fields regardless of dtype. Aligns with how query rate already treats them.
- **AE_ENTRY_DTC is not a real CDASH field.** It's an operational metadata field that real EDC systems track as `audit_timestamp`. For the mock, we synthesize it directly. The DMP section 9 should note that in production this comes from the EDC audit trail.
- **Site biasing:** to make the dashboard interesting, 2 of 8 sites should be "problem sites" with multiple flagged KRIs. Encode this in `error_profile.yml::site_bias` (new section).

---

*Last updated: 2026-05-15. Frozen until task #6 (synth_generator) lands; revise only if the data model can't support a computation defined here.*
