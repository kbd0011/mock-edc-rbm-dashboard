#!/usr/bin/env python3
"""
Generate synthetic CDASH-format CSVs for IMM-PSO-3001.

Outputs to synthetic/raw/:
    dm.csv, ie.csv, ex.csv, ae.csv, cm.csv, pasi.csv, lb.csv,
    protocol_deviations.csv

Drives errors, site bias, and operational parameters from
metadata/error_profile.yml.
"""
from __future__ import annotations

import math
import random
from datetime import date, timedelta
from pathlib import Path

import click
import pandas as pd
import yaml
from faker import Faker


# ---- Reference data ------------------------------------------------------

# (visit_name, day_offset_from_TRTSDT)
VISITS = [
    ("SCREENING", -21),
    ("BASELINE",  0),
    ("W4",        28),
    ("W8",        56),
    ("W12",       84),
    ("W16",       112),
    ("W24",       168),
    ("W36",       252),
    ("W52",       364),
]
LAB_VISITS = ["SCREENING", "BASELINE", "W4", "W12", "W24", "W52"]

# Verbatim AE terms with their MedDRA SOC (kept here for synth realism;
# the AEDECOD mapping lives in R/01_cdash_to_sdtm.R)
AE_TERMS = [
    ("nasopharyngitis", "Infections and infestations"),
    ("upper respiratory tract infection", "Infections and infestations"),
    ("headache", "Nervous system disorders"),
    ("injection site reaction", "General disorders and administration site conditions"),
    ("arthralgia", "Musculoskeletal and connective tissue disorders"),
    ("back pain", "Musculoskeletal and connective tissue disorders"),
    ("hypertension", "Vascular disorders"),
    ("COVID-19", "Infections and infestations"),
    ("diarrhea", "Gastrointestinal disorders"),
    ("nausea", "Gastrointestinal disorders"),
    ("fatigue", "General disorders and administration site conditions"),
    ("urinary tract infection", "Infections and infestations"),
    ("rash", "Skin and subcutaneous tissue disorders"),
    ("dizziness", "Nervous system disorders"),
    ("pruritus", "Skin and subcutaneous tissue disorders"),
]

CM_DRUGS = [
    ("methotrexate", "Psoriasis maintenance", 15, "mg", "ORAL"),
    ("ibuprofen", "Pain", 400, "mg", "ORAL"),
    ("acetaminophen", "Pain", 500, "mg", "ORAL"),
    ("lisinopril", "Hypertension", 10, "mg", "ORAL"),
    ("atorvastatin", "Hyperlipidemia", 20, "mg", "ORAL"),
    ("metformin", "Type 2 diabetes", 1000, "mg", "ORAL"),
    ("sertraline", "Depression", 50, "mg", "ORAL"),
    ("levothyroxine", "Hypothyroidism", 75, "mcg", "ORAL"),
    ("topical hydrocortisone", "Eczema", 1, "g", "TOPICAL"),
    ("vitamin D3", "Supplement", 2000, "IU", "ORAL"),
    ("cetirizine", "Allergies", 10, "mg", "ORAL"),
    ("multivitamin", "Supplement", 1, "unit", "ORAL"),
]

# Lab reference ranges (used both for value generation and for LBSTNRLO/HI
# during CDASH->SDTM mapping in R).
LAB_TESTS = {
    "WBC":   {"mean": 7.0,  "sd": 1.5,  "low": 4.0,  "high": 11.0, "unit": "10^9/L"},
    "HGB":   {"mean": 14.0, "sd": 1.5,  "low": 12.0, "high": 17.0, "unit": "g/dL"},
    "PLT":   {"mean": 250,  "sd": 50,   "low": 150,  "high": 400,  "unit": "10^9/L"},
    "ALT":   {"mean": 25,   "sd": 8,    "low": 10,   "high": 40,   "unit": "U/L"},
    "AST":   {"mean": 25,   "sd": 8,    "low": 10,   "high": 40,   "unit": "U/L"},
    "CREAT": {"mean": 0.9,  "sd": 0.15, "low": 0.6,  "high": 1.3,  "unit": "mg/dL"},
}

PROTOCOL_DEVIATION_CATEGORIES = [
    "visit window violation",
    "missed assessment",
    "eligibility breach",
    "dosing error",
    "ICF re-consent missed",
]

RACE_DIST = [
    ("WHITE", 0.65),
    ("BLACK OR AFRICAN AMERICAN", 0.13),
    ("ASIAN", 0.10),
    ("AMERICAN INDIAN OR ALASKA NATIVE", 0.02),
    ("MULTIPLE", 0.05),
    ("NOT REPORTED", 0.05),
]

ETHNIC_DIST = [
    ("NOT HISPANIC OR LATINO", 0.75),
    ("HISPANIC OR LATINO", 0.20),
    ("NOT REPORTED", 0.05),
]

INCLUSION_CRITERIA = [
    ("INCL01", "Age 18-75 inclusive at screening"),
    ("INCL02", "Plaque psoriasis for >=6 months"),
    ("INCL03", "PASI >= 12 at screening and baseline"),
    ("INCL04", "BSA >= 10% at screening and baseline"),
    ("INCL05", "IGA >= 3 at screening and baseline"),
    ("INCL06", "Candidate for systemic therapy or phototherapy"),
    ("INCL07", "Able to provide written informed consent"),
]
EXCLUSION_CRITERIA = [
    ("EXCL01", "Prior IL-23 biologic failure"),
    ("EXCL02", "Biologic agent within 5 half-lives"),
    ("EXCL03", "Active or chronic infection at screening"),
    ("EXCL04", "Latent or active TB without prophylaxis"),
    ("EXCL05", "Malignancy within 5 years (with exceptions)"),
    ("EXCL06", "Pregnancy or lactation"),
    ("EXCL07", "Clinically significant comorbidity per investigator"),
    ("EXCL08", "Live vaccine within 4 weeks of baseline"),
]


# ---- Helpers -------------------------------------------------------------

def weighted_choice(items_with_weights):
    items = [i for i, _ in items_with_weights]
    weights = [w for _, w in items_with_weights]
    return random.choices(items, weights=weights, k=1)[0]


def iso(d) -> str:
    return d.isoformat() if d else ""


def maybe_blank_row(d: dict, fields: list[str], rate: float, multiplier: float = 1.0):
    """In-place: blank each named field with probability rate*multiplier."""
    eff = min(1.0, rate * multiplier)
    for f in fields:
        if f in d and random.random() < eff:
            d[f] = ""


# ---- Form generators ----------------------------------------------------

def make_subjects(cfg: dict, n_subjects: int, n_sites: int) -> pd.DataFrame:
    """Subject roster — SITEID, SUBJID, ARM, TRTSDT, TRTEDT."""
    study_start = date.fromisoformat(cfg["operational"]["study_start_date"])
    recruit_days = cfg["operational"]["recruitment_months"] * 30
    arms = cfg["operational"]["treatment_arms"]
    arm_choices = [a for a, w in arms.items() for _ in range(w)]

    site_counters = {f"S{i:03d}": 0 for i in range(1, n_sites + 1)}
    rows = []
    for _ in range(n_subjects):
        site = f"S{random.randint(1, n_sites):03d}"
        site_counters[site] += 1
        subjid = f"{site}-{site_counters[site]:04d}"
        arm = random.choice(arm_choices)
        trtsdt = study_start + timedelta(days=random.randint(0, recruit_days))
        trtedt = trtsdt + timedelta(days=364)
        rows.append({"SITEID": site, "SUBJID": subjid, "ARM": arm,
                     "TRTSDT": trtsdt, "TRTEDT": trtedt})
    return pd.DataFrame(rows)


def make_dm(subjects: pd.DataFrame, cfg: dict, fake: Faker) -> pd.DataFrame:
    err = cfg["error_injection"]
    bias = cfg["site_bias"]
    miss_rate = err["missing_required_fields"]["rate"]
    miss_fields = [f.split(".")[1] for f in err["missing_required_fields"]["fields"]
                   if f.startswith("DM.")]
    fmt_rate = err["format_invalid"]["rate"]

    rows = []
    for _, s in subjects.iterrows():
        age = int(max(18, min(75, random.gauss(50, 15))))
        if random.random() < err["age_out_of_range"]["rate"]:
            age = random.choice([17, 80])
        brthdat = s["TRTSDT"] - timedelta(days=int(age * 365.25))
        d = {
            "SITEID":  s["SITEID"],
            "SUBJID":  s["SUBJID"],
            "BRTHDAT": iso(brthdat),
            "AGE":     age,
            "AGEU":    "YEARS",
            "SEX":     "M" if random.random() < 0.55 else "F",
            "RACE":    weighted_choice(RACE_DIST),
            "ETHNIC":  weighted_choice(ETHNIC_DIST),
            "COUNTRY": "USA",
        }
        # Format-invalid injection on SUBJID (drop a dash to break the regex)
        if random.random() < fmt_rate:
            d["SUBJID"] = d["SUBJID"].replace("-", "")
        mult = bias["missing_data_multiplier"] if s["SITEID"] in bias["problem_sites"] else 1.0
        maybe_blank_row(d, miss_fields, miss_rate, mult)
        rows.append(d)
    return pd.DataFrame(rows)


def make_ie(subjects: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """One row per criterion per subject. All subjects pass by construction."""
    err = cfg["error_injection"]
    bias = cfg["site_bias"]
    miss_rate = err["missing_required_fields"]["rate"]
    fmt_rate = err["format_invalid"]["rate"]

    rows = []
    for _, s in subjects.iterrows():
        mult = bias["missing_data_multiplier"] if s["SITEID"] in bias["problem_sites"] else 1.0
        for code, text in INCLUSION_CRITERIA:
            d = {"SITEID": s["SITEID"], "SUBJID": s["SUBJID"],
                 "IECAT": "INCLUSION", "IETESTCD": code,
                 "IETEST": text, "IEORRES": "Y"}
            maybe_blank_row(d, ["IEORRES"], miss_rate, mult)
            rows.append(d)
        for code, text in EXCLUSION_CRITERIA:
            d = {"SITEID": s["SITEID"], "SUBJID": s["SUBJID"],
                 "IECAT": "EXCLUSION", "IETESTCD": code,
                 "IETEST": text, "IEORRES": "N"}
            maybe_blank_row(d, ["IEORRES"], miss_rate, mult)
            rows.append(d)
        # Tiny chance of format-invalid IETESTCD
        if random.random() < fmt_rate and rows:
            rows[-1]["IETESTCD"] = "BAD CODE"
    return pd.DataFrame(rows)


def make_ex(subjects: pd.DataFrame) -> pd.DataFrame:
    """One row per subject — first/last dose, drug name."""
    rows = []
    for _, s in subjects.iterrows():
        rows.append({
            "SITEID":  s["SITEID"],
            "SUBJID":  s["SUBJID"],
            "EXTRT":   "IP-301 100 mg" if s["ARM"] == "Active" else "Placebo",
            "EXDOSE":  100 if s["ARM"] == "Active" else 0,
            "EXDOSU":  "mg",
            "EXROUTE": "SC",
            "EXSTDT":  iso(s["TRTSDT"]),
            "EXENDT":  iso(s["TRTEDT"]),
        })
    return pd.DataFrame(rows)


def make_ae(subjects: pd.DataFrame, cfg: dict, fake: Faker) -> pd.DataFrame:
    """~3 AEs per subject; AE_ENTRY_DTC reflects site-correlated entry latency."""
    err = cfg["error_injection"]
    bias = cfg["site_bias"]
    miss_rate = err["missing_required_fields"]["rate"]
    miss_fields = [f.split(".")[1] for f in err["missing_required_fields"]["fields"]
                   if f.startswith("AE.")]
    fmt_rate = err["format_invalid"]["rate"]

    rows = []
    for _, s in subjects.iterrows():
        is_problem = s["SITEID"] in bias["problem_sites"]
        latency_mean = bias["ae_latency_mean_days"] if is_problem else 2.0
        mult = bias["missing_data_multiplier"] if is_problem else 1.0

        n_ae = max(0, int(round(random.gauss(3, 1.5))))
        for _ in range(n_ae):
            term, soc = random.choice(AE_TERMS)
            sev = weighted_choice([("MILD", 0.60), ("MODERATE", 0.35), ("SEVERE", 0.05)])
            ser = "Y" if (sev == "SEVERE" and random.random() < 0.4) else "N"
            rel = weighted_choice([("RELATED", 0.30),
                                    ("NOT RELATED", 0.55),
                                    ("UNKNOWN", 0.15)])
            acn = weighted_choice([("DOSE NOT CHANGED", 0.80),
                                    ("DRUG INTERRUPTED", 0.10),
                                    ("DOSE REDUCED", 0.05),
                                    ("DRUG WITHDRAWN", 0.04),
                                    ("NOT APPLICABLE", 0.01)])
            out = weighted_choice([("RECOVERED/RESOLVED", 0.75),
                                    ("RECOVERING/RESOLVING", 0.15),
                                    ("NOT RECOVERED/NOT RESOLVED", 0.07),
                                    ("RECOVERED/RESOLVED WITH SEQUELAE", 0.02),
                                    ("UNKNOWN", 0.01)])

            # AESTDAT uniform between TRTSDT and TRTEDT
            day_off = random.randint(0, 364)
            aestdat = s["TRTSDT"] + timedelta(days=day_off)
            # Optionally inject ae-before-treatment
            if random.random() < err["ae_before_treatment"]["rate"]:
                aestdat = s["TRTSDT"] - timedelta(days=random.randint(1, 10))

            duration = random.randint(1, 21)
            aeendat = aestdat + timedelta(days=duration) if random.random() < 0.85 else None

            # AE_ENTRY_DTC: latency follows exponential dist, site-correlated mean
            lag_days = int(round(random.expovariate(1.0 / latency_mean)))
            ae_entry_dtc = aestdat + timedelta(days=max(0, lag_days))

            d = {
                "SITEID":       s["SITEID"],
                "SUBJID":       s["SUBJID"],
                "AETERM":       term,
                "AEDECOD":      "",          # coded later in R
                "AESTDAT":      iso(aestdat),
                "AEENDAT":      iso(aeendat),
                "AESEV":        sev,
                "AESER":        ser,
                "AEREL":        rel,
                "AEACN":        acn,
                "AEOUT":        out,
                "AESOC":        soc,
                "AETOXGR":      random.choice(["", "1", "2", "3"]),
                "AENONST":      "",
                # Operational metadata (not CDASH; mirrors EDC audit-trail timestamp).
                "AE_ENTRY_DTC": iso(ae_entry_dtc),
            }
            if random.random() < fmt_rate:
                d["AESTDAT"] = d["AESTDAT"].replace("-", "/")
            maybe_blank_row(d, miss_fields, miss_rate, mult)
            rows.append(d)
    return pd.DataFrame(rows)


def make_cm(subjects: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    rows = []
    for _, s in subjects.iterrows():
        n_cm = random.randint(0, 5)
        for _ in range(n_cm):
            drug, indc, dose, unit, route = random.choice(CM_DRUGS)
            # Start date: usually before TRTSDT (existing medication)
            cmstdat = s["TRTSDT"] - timedelta(days=random.randint(0, 720))
            ongoing = random.random() < 0.6
            cmendat = "" if ongoing else iso(cmstdat + timedelta(days=random.randint(7, 365)))
            rows.append({
                "SITEID":  s["SITEID"],
                "SUBJID":  s["SUBJID"],
                "CMTRT":   drug,
                "CMINDC":  indc,
                "CMDOSE":  dose,
                "CMDOSU":  unit,
                "CMSTDAT": iso(cmstdat),
                "CMENDAT": cmendat,
                "CMROUTE": route,
                "CMONGO":  "Y" if ongoing else "N",
            })
    return pd.DataFrame(rows)


def make_pasi(subjects: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """Regional sub-scores at each visit with treatment-effect tail-off."""
    err = cfg["error_injection"]
    bias = cfg["site_bias"]
    miss_rate = err["missing_required_fields"]["rate"]
    impl_rate = err["pasi_implausible_total"]["rate"]

    rows = []
    for _, s in subjects.iterrows():
        baseline_total = random.uniform(12, 30)
        # Region weights: 0.1, 0.2, 0.3, 0.4 (head/arms/trunk/legs)
        head_b  = baseline_total * 0.1
        arms_b  = baseline_total * 0.2
        trunk_b = baseline_total * 0.3
        legs_b  = baseline_total * 0.4

        mult = bias["missing_data_multiplier"] if s["SITEID"] in bias["problem_sites"] else 1.0

        for visit, day_off in VISITS:
            # Treatment effect: Active arm decays exponentially; Placebo near-flat
            if visit == "SCREENING":
                factor = 1.05  # screening slightly above baseline by definition
            elif visit == "BASELINE":
                factor = 1.0
            else:
                weeks = day_off / 7.0
                if s["ARM"] == "Active":
                    factor = max(0.05, math.exp(-0.08 * weeks))
                else:
                    factor = max(0.6, 1.0 - 0.005 * weeks + random.gauss(0, 0.05))

            jitter = lambda x: max(0, x * factor + random.gauss(0, 0.3))
            h = round(jitter(head_b),  1)
            a = round(jitter(arms_b),  1)
            t = round(jitter(trunk_b), 1)
            l = round(jitter(legs_b),  1)
            total = round(h + a + t + l, 1)

            # PASI implausible: occasionally exceed 72
            if random.random() < impl_rate:
                total = round(total + 50, 1)

            visit_date = s["TRTSDT"] + timedelta(days=day_off)
            d = {
                "SITEID":   s["SITEID"],
                "SUBJID":   s["SUBJID"],
                "VISIT":    visit,
                "PASIDAT":  iso(visit_date),
                "PASIHEAD": h,
                "PASIARMS": a,
                "PASITRNK": t,
                "PASILEGS": l,
                "PASITOT":  total,
                "PASISBT":  round(random.uniform(0, 30), 0),
                "PASISBA":  round(random.uniform(0, 30), 0),
                "PASISBL":  round(random.uniform(0, 30), 0),
            }
            maybe_blank_row(d, ["PASITOT"], miss_rate, mult)
            rows.append(d)
    return pd.DataFrame(rows)


def make_lb(subjects: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """6 analytes at each lab visit; site-biased on missingness."""
    err = cfg["error_injection"]
    bias = cfg["site_bias"]
    miss_rate = err["missing_required_fields"]["rate"]
    impl_rate = err["lab_implausible"]["rate"]
    miss_fields = [f.split(".")[1] for f in err["missing_required_fields"]["fields"]
                   if f.startswith("LB.")]

    visit_map = {v: d for v, d in VISITS}
    rows = []
    for _, s in subjects.iterrows():
        mult = bias["missing_data_multiplier"] if s["SITEID"] in bias["problem_sites"] else 1.0

        for visit in LAB_VISITS:
            visit_date = s["TRTSDT"] + timedelta(days=visit_map[visit])
            for code, spec in LAB_TESTS.items():
                val = max(0.01, random.gauss(spec["mean"], spec["sd"]))
                # Implausible injection
                if random.random() < impl_rate:
                    val = val * random.choice([10, 0.01])
                val = round(val, 2)

                d = {
                    "SITEID":   s["SITEID"],
                    "SUBJID":   s["SUBJID"],
                    "VISIT":    visit,
                    "LBTESTCD": code,
                    "LBTEST":   {"WBC": "Leukocytes", "HGB": "Hemoglobin",
                                  "PLT": "Platelets", "ALT": "Alanine Aminotransferase",
                                  "AST": "Aspartate Aminotransferase",
                                  "CREAT": "Creatinine"}[code],
                    "LBORRES":  val,
                    "LBORRESU": spec["unit"],
                    "LBORNRLO": spec["low"],
                    "LBORNRHI": spec["high"],
                    "LBDAT":    iso(visit_date),
                    "LBNAM":    "Central Lab Services Inc.",
                }
                maybe_blank_row(d, miss_fields, miss_rate, mult)
                rows.append(d)
    return pd.DataFrame(rows)


def make_protocol_deviations(subjects: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    """~2 deviations per normal site, ~6 per problem site."""
    bias = cfg["site_bias"]
    rows = []
    for site, subset in subjects.groupby("SITEID"):
        is_problem = site in bias["problem_sites"]
        base_n = 2
        n = int(base_n * bias["protocol_deviation_multiplier"]) if is_problem else base_n
        for _ in range(n):
            subj = subset.sample(1).iloc[0]
            offset = random.randint(7, 350)
            rows.append({
                "SITEID":         site,
                "SUBJID":         subj["SUBJID"],
                "deviation_date": iso(subj["TRTSDT"] + timedelta(days=offset)),
                "category":       random.choice(PROTOCOL_DEVIATION_CATEGORIES),
            })
    return pd.DataFrame(rows)


# ---- CLI ---------------------------------------------------------------

@click.command()
@click.option("--config", default="metadata/error_profile.yml",
              help="Path to error_profile.yml")
@click.option("--out-dir", default="synthetic/raw",
              help="Output directory for CSVs")
def main(config: str, out_dir: str) -> None:
    cfg = yaml.safe_load(Path(config).read_text())
    seed = cfg["seed"]
    n_subjects = cfg["operational"]["n_subjects"]
    n_sites = cfg["operational"]["n_sites"]

    random.seed(seed)
    Faker.seed(seed)
    fake = Faker()

    subjects = make_subjects(cfg, n_subjects, n_sites)
    dm  = make_dm(subjects, cfg, fake)
    ie  = make_ie(subjects, cfg)
    ex  = make_ex(subjects)
    ae  = make_ae(subjects, cfg, fake)
    cm  = make_cm(subjects, cfg)
    pasi = make_pasi(subjects, cfg)
    lb  = make_lb(subjects, cfg)
    pd_ = make_protocol_deviations(subjects, cfg)

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    dm.to_csv(out / "dm.csv", index=False)
    ie.to_csv(out / "ie.csv", index=False)
    ex.to_csv(out / "ex.csv", index=False)
    ae.to_csv(out / "ae.csv", index=False)
    cm.to_csv(out / "cm.csv", index=False)
    pasi.to_csv(out / "pasi.csv", index=False)
    lb.to_csv(out / "lb.csv", index=False)
    pd_.to_csv(out / "protocol_deviations.csv", index=False)

    print(f"Generated synthetic data for {n_subjects} subjects across {n_sites} sites.")
    print(f"  dm:    {len(dm):>5d} rows")
    print(f"  ie:    {len(ie):>5d} rows")
    print(f"  ex:    {len(ex):>5d} rows")
    print(f"  ae:    {len(ae):>5d} rows")
    print(f"  cm:    {len(cm):>5d} rows")
    print(f"  pasi:  {len(pasi):>5d} rows")
    print(f"  lb:    {len(lb):>5d} rows")
    print(f"  pdev:  {len(pd_):>5d} rows")
    print(f"Output: {out.resolve()}")


if __name__ == "__main__":
    main()
