# Protocol Summary — IMM-PSO-3001

**Title:** A Multicenter, Randomized, Double-Blind, Placebo-Controlled Phase III Study of [Investigational IL-23 Inhibitor, IP-301] in Adults with Moderate-to-Severe Plaque Psoriasis

**Protocol Number:** IMM-PSO-3001
**Version:** 1.0
**Date:** 2026-05-15
**Phase:** III
**Indication:** Moderate-to-severe plaque psoriasis

> **Notice.** This is a fictional protocol abstract authored for the `mock-edc-rbm-dashboard` portfolio project. No patients exist; no investigational product exists. The study is designed to mirror the structure of a real Phase III immunology trial so that the downstream data-management artifacts (eCRF, edit checks, SDTM mapping, RBQM KRIs, DMP) are realistic and reviewable.

---

## 1. Sponsor

**Helix Therapeutics, Inc.** (fictional)
500 Madison Avenue, New Brunswick, NJ 08901, USA
Medical Monitor: Dr. A. N. Other, MD
Sponsor Contact: clinical-ops@helix-therapeutics.example

---

## 2. Background and Rationale

Plaque psoriasis affects an estimated 2–3% of adults worldwide and 7.5 million adults in the United States. Moderate-to-severe disease — defined by a Psoriasis Area and Severity Index (PASI) ≥12, a Body Surface Area (BSA) involvement ≥10%, and an Investigator's Global Assessment (IGA) ≥3 — is associated with substantial psychosocial burden, increased cardiometabolic comorbidity, and reduced quality of life. The interleukin-23/T-helper-17 (IL-23/Th17) signaling axis is now established as a central driver of plaque psoriasis pathogenesis, and selective IL-23p19 inhibitors have demonstrated high PASI 90 response rates with favorable long-term safety profiles. IP-301 is a fully human monoclonal antibody targeting the p19 subunit of IL-23, administered by subcutaneous injection. This Phase III study evaluates the efficacy and safety of IP-301 versus placebo over 52 weeks in adults with moderate-to-severe plaque psoriasis who are candidates for systemic therapy.

---

## 3. Objectives

### 3.1 Primary Objective

To evaluate the efficacy of IP-301 versus placebo, measured by the proportion of subjects achieving a **PASI 90 response at Week 16**.

### 3.2 Secondary Objectives

- Proportion of subjects achieving **PASI 75** at Week 16
- Proportion of subjects achieving **PASI 100** at Week 16
- Proportion of subjects achieving **IGA 0/1** (clear or almost clear) at Week 16
- Mean change from baseline in **Dermatology Life Quality Index (DLQI)** at Week 16
- Maintenance of PASI 90 response through Week 52

### 3.3 Safety Objective

To characterize the safety and tolerability profile of IP-301 through Week 52, with emphasis on serious infections, injection-site reactions, and major adverse cardiovascular events (MACE).

---

## 4. Study Design

| Element | Specification |
|---|---|
| Phase | III |
| Design | Multicenter, randomized, double-blind, placebo-controlled, parallel-group |
| Randomization | 2:1 (IP-301 : placebo) |
| Treatment duration | 52 weeks |
| Total study duration per subject | ~56 weeks (including screening and EOS) |
| Number of sites | 8 (United States) |
| Target enrollment | 150 randomized subjects (100 IP-301; 50 placebo) |
| Stratification factors | Prior biologic exposure (yes/no); baseline weight (<90 kg vs ≥90 kg) |

Subjects are randomized at Baseline (Day 1) and receive subcutaneous injections of IP-301 100 mg or matching placebo at Weeks 0, 4, and every 8 weeks thereafter through Week 44. The primary efficacy assessment is at Week 16; safety follow-up continues through Week 52, with an end-of-study (EOS) visit at Week 52.

---

## 5. Sample Size and Power

A planned enrollment of N=150 (100 active, 50 placebo) provides approximately 90% power to detect a 35-percentage-point difference in PASI 90 response at Week 16 (assumed rates: 60% IP-301 vs 5% placebo), using a two-sided chi-square test at α=0.05, allowing for a 10% dropout rate before Week 16.

Enrollment is targeted across 8 sites at ~1 subject/site/month over an 18-month recruitment period. Operational expectations: average site activation by Month 1; first subject in by Month 2; last subject in by Month 19; database lock at Month 24.

---

## 6. Study Population

### 6.1 Inclusion Criteria

1. Adults aged 18–75 years at screening.
2. Diagnosis of plaque psoriasis for ≥6 months prior to screening.
3. **PASI ≥12** at both screening and baseline.
4. **BSA ≥10%** at both screening and baseline.
5. **IGA ≥3** (moderate or severe) at both screening and baseline.
6. Candidate for systemic therapy or phototherapy per investigator judgment.
7. Able to provide written informed consent.

### 6.2 Exclusion Criteria

1. Prior treatment failure on any IL-23-class biologic (defined as <PASI 50 response after ≥16 weeks of adequate dosing).
2. Treatment with any biologic agent within 5 half-lives of baseline.
3. Active or chronic infection requiring systemic antimicrobial therapy at screening.
4. Latent or active tuberculosis without documented adequate prophylaxis.
5. History of malignancy within 5 years (other than adequately treated non-melanoma skin cancer or in-situ cervical carcinoma).
6. Pregnancy, lactation, or unwillingness to use highly effective contraception through 20 weeks post-last-dose.
7. Other clinically significant medical or psychiatric condition that, in the investigator's opinion, would interfere with study participation.
8. Receipt of a live vaccine within 4 weeks of baseline.

---

## 7. Endpoints

### 7.1 Primary

- Proportion of subjects achieving PASI 90 at Week 16.

### 7.2 Key Secondary

- Proportion achieving PASI 75 at Week 16.
- Proportion achieving PASI 100 at Week 16.
- Proportion achieving IGA 0/1 at Week 16.
- Mean change from baseline in DLQI at Week 16.

### 7.3 Other Secondary

- Maintenance of PASI 90 through Week 52.
- Time to first PASI 75 response.
- Change from baseline in BSA at each scheduled visit.

### 7.4 Safety

- Incidence and severity of treatment-emergent adverse events (TEAEs).
- Incidence of serious adverse events (SAEs).
- Incidence of injection-site reactions.
- Incidence of MACE (adjudicated).
- Laboratory abnormalities (Grade ≥3 per CTCAE v5.0).

---

## 8. Schedule of Assessments

### 8.1 Visit Schedule

| Visit | Day / Week | Window |
|---|---|---|
| Screening | Day −28 to Day −1 | n/a |
| Baseline / Randomization | Day 1 | n/a |
| W4 | Week 4 | ±3 days |
| W8 | Week 8 | ±3 days |
| W12 | Week 12 | ±3 days |
| **W16 (Primary endpoint)** | Week 16 | ±3 days |
| W24 | Week 24 | ±5 days |
| W36 | Week 36 | ±7 days |
| W52 (EOS) | Week 52 | ±7 days |

### 8.2 Assessments by Visit

| Assessment | Scr | BL | W4 | W8 | W12 | W16 | W24 | W36 | W52 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Informed consent | X | | | | | | | | |
| Demographics (DM) | X | | | | | | | | |
| Inclusion/Exclusion (IE) | X | | | | | | | | |
| Medical history | X | | | | | | | | |
| Concomitant medications (CM) | X | X | X | X | X | X | X | X | X |
| Vital signs | X | X | X | X | X | X | X | X | X |
| Physical examination | X | X | | | X | X | X | X | X |
| PASI assessment | X | X | X | X | X | X | X | X | X |
| BSA assessment | X | X | X | X | X | X | X | X | X |
| IGA | X | X | X | X | X | X | X | X | X |
| DLQI | | X | X | | X | X | X | X | X |
| Laboratory (LB) | X | X | X | | X | | X | | X |
| Pregnancy test (WOCBP) | X | X | | | X | | X | | X |
| TB screening (IGRA) | X | | | | | | | | |
| IP administration | | X | X | | | X | X | X | |
| Adverse events (AE) | | →←─────────────── continuous ───────────────→ | | | | | | | |

`X` = assessment performed at that visit. The CRF data captured for each assessment is described in `docs/crf_completion_guide.md` and the field-level metadata in `metadata/fields_spec.xlsx`.

---

## 9. Safety Reporting

- **Adverse Events (AE):** captured continuously from informed consent through the EOS visit on form AE per ICH E2A definitions. Severity graded MILD / MODERATE / SEVERE; relationship to study drug assessed by investigator as RELATED / NOT RELATED / UNKNOWN.
- **Serious Adverse Events (SAE):** reported by site to sponsor within **24 hours** of awareness, per ICH E2A. SAE reconciliation between EDC and safety database performed monthly.
- **Suspected Unexpected Serious Adverse Reactions (SUSARs):** expedited reporting to regulatory authorities within 7 days (fatal/life-threatening) or 15 days (other), per 21 CFR 312.32 and EU CTR.
- **Data Safety Monitoring Board (DSMB):** independent DSMB reviews unblinded safety data at scheduled intervals (after first 50 subjects reach W16; after first 100 subjects reach W16; annual thereafter) and ad hoc as warranted.
- **Pregnancy:** any pregnancy in a subject or partner during the study or within 20 weeks post-last-dose is reported within 24 hours and followed to outcome.

---

## 10. Data Management and Risk-Based Quality Management

Data are captured through a CDASHIG 2.2-aligned electronic Case Report Form (eCRF). Edit checks (≥35 specified in `metadata/edit_checks.xlsx`) fire at point of entry and emit queries to the EDC query log. Centralized monitoring is performed per ICH E6(R3) Annex E using six Key Risk Indicators (enrollment rate, query rate, AE reporting latency, protocol deviation rate, missing-data rate, lab out-of-range rate) computed and surfaced in a dashboard (`shiny/app.R`). Full operational details — including SDV strategy, query management, coding (MedDRA for AE; WHO-DD for CM), and database lock procedures — are specified in the Data Management Plan (`docs/dmp.qmd`). CDASH-to-SDTM mapping for DM, AE, and LB domains is specified in `metadata/mapping_spec.xlsx` and implemented in `R/01_cdash_to_sdtm.R`.

---

## 11. References

- ICH E2A — Clinical Safety Data Management: Definitions and Standards for Expedited Reporting.
- ICH E6(R3) — Good Clinical Practice, Annex E (Centralized Monitoring).
- ICH E9(R1) — Statistical Principles for Clinical Trials, including estimand framework.
- CDISC CDASHIG v2.2.
- CDISC SDTMIG v3.3.
- SCDM Good Clinical Data Management Practice (GCDMP), current edition.
- TransCelerate RBQM Framework.

---

*This protocol abstract is a fictional document authored solely for portfolio purposes. It must not be used to design, conduct, or interpret any actual clinical investigation.*
