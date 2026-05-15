"""Cross-form consistency checks (non-temporal). Dispatched by CheckID."""
from __future__ import annotations

import pandas as pd

from python.edit_checks import Query


# ---- Per-check handlers -------------------------------------------------

def _ec025_serious_ae_severity(forms):
    """If AESER='Y' then AESEV in (MODERATE, SEVERE)."""
    ae = forms.get("ae")
    if ae is None:
        return []
    bad = ae[(ae["AESER"] == "Y") & (ae["AESEV"] == "MILD")]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AESEV",
        check_id="EC025", severity="Warning",
        message=f"Serious AE '{r.AETERM}' marked MILD; expected MODERATE or SEVERE.",
    ) for r in bad.itertuples(index=False)]


def _ec026_pasi_total_consistency(forms):
    """PASITOT ≈ PASIHEAD + PASIARMS + PASITRNK + PASILEGS (tolerance 0.1)."""
    pasi = forms.get("pasi")
    if pasi is None:
        return []
    parts = ["PASIHEAD", "PASIARMS", "PASITRNK", "PASILEGS"]
    for c in parts + ["PASITOT"]:
        pasi[c + "_num"] = pd.to_numeric(pasi[c], errors="coerce")
    expected = sum(pasi[c + "_num"] for c in parts)
    diff = (pasi["PASITOT_num"] - expected).abs()
    bad = pasi[(diff.notna()) & (diff > 0.1)]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="PASI", field="PASITOT",
        check_id="EC026", severity="Error",
        message=f"PASITOT {r.PASITOT} != sum of regions ({r.PASIHEAD}+{r.PASIARMS}+{r.PASITRNK}+{r.PASILEGS}).",
    ) for r in bad.itertuples(index=False)]


def _ec027_infection_ae_without_cm(forms):
    """Notice when AE term contains 'infection' but no CM with infection indication."""
    ae, cm = forms.get("ae"), forms.get("cm")
    if ae is None or cm is None:
        return []
    inf_ae = ae[ae["AETERM"].fillna("").str.lower().str.contains("infection")]
    subjects_with_inf_cm = set(cm[cm["CMINDC"].fillna("").str.lower().str.contains("infection")]["SUBJID"])
    bad = inf_ae[~inf_ae["SUBJID"].isin(subjects_with_inf_cm)]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AETERM",
        check_id="EC027", severity="Notice",
        message=f"Infection-related AE '{r.AETERM}' without matching CM record.",
    ) for r in bad.itertuples(index=False)]


def _ec028_pregnancy_outcome_sex(forms):
    """Pregnancy outcome only valid for female subjects."""
    ae, dm = forms.get("ae"), forms.get("dm")
    if ae is None or dm is None:
        return []
    j = ae.merge(dm[["SUBJID", "SEX"]], on="SUBJID", how="left")
    bad = j[j["AEOUT"].fillna("").str.lower().str.contains("pregnancy") & (j["SEX"] != "F")]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AEOUT",
        check_id="EC028", severity="Warning",
        message=f"Pregnancy-related outcome '{r.AEOUT}' for non-female subject.",
    ) for r in bad.itertuples(index=False)]


def _ec034_fatal_ae_action(forms):
    """If AESER='Y' and AEOUT='FATAL' then AEACN='DRUG WITHDRAWN'."""
    ae = forms.get("ae")
    if ae is None:
        return []
    bad = ae[(ae["AESER"] == "Y") &
             (ae["AEOUT"] == "FATAL") &
             (ae["AEACN"] != "DRUG WITHDRAWN")]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AEACN",
        check_id="EC034", severity="Warning",
        message=f"Fatal serious AE without DRUG WITHDRAWN action (got '{r.AEACN}').",
    ) for r in bad.itertuples(index=False)]


def _ec035_treatment_effect_plausibility(forms):
    """Notice-only at W16: PASI < 0 would be implausible."""
    pasi = forms.get("pasi")
    if pasi is None:
        return []
    vals = pd.to_numeric(pasi["PASITOT"], errors="coerce")
    bad = pasi[(pasi["VISIT"] == "W16") & vals.notna() & (vals < 0)]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="PASI", field="PASITOT",
        check_id="EC035", severity="Notice",
        message=f"Negative PASITOT at W16 ({r.PASITOT}); review.",
    ) for r in bad.itertuples(index=False)]


HANDLERS = {
    "EC025": _ec025_serious_ae_severity,
    "EC026": _ec026_pasi_total_consistency,
    "EC027": _ec027_infection_ae_without_cm,
    "EC028": _ec028_pregnancy_outcome_sex,
    "EC034": _ec034_fatal_ae_action,
    "EC035": _ec035_treatment_effect_plausibility,
}


def run(check_row, forms):
    handler = HANDLERS.get(check_row["CheckID"])
    return handler(forms) if handler else []
