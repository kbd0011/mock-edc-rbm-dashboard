"""Cross-form temporal (date-comparison) checks. Dispatched by CheckID."""
from __future__ import annotations

import pandas as pd

from python.edit_checks import Query


def _to_dt(s: pd.Series) -> pd.Series:
    return pd.to_datetime(s, errors="coerce")


# ---- Per-check handlers -------------------------------------------------

def _ec019_ae_after_treatment(forms):
    """AE.AESTDAT >= EX.EXSTDT — treatment-emergent AEs must start on/after first dose."""
    ae, ex = forms.get("ae"), forms.get("ex")
    if ae is None or ex is None:
        return []
    j = ae.merge(ex[["SUBJID", "EXSTDT"]], on="SUBJID", how="left")
    bad = j[_to_dt(j["AESTDAT"]) < _to_dt(j["EXSTDT"])]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AESTDAT",
        check_id="EC019", severity="Warning",
        message=f"AE start {r.AESTDAT} precedes first dose {r.EXSTDT}.",
    ) for r in bad.itertuples(index=False)]


def _ec020_ae_end_after_start(forms):
    """AE.AEENDAT >= AE.AESTDAT."""
    ae = forms.get("ae")
    if ae is None:
        return []
    bad = ae[(_to_dt(ae["AEENDAT"]).notna()) &
             (_to_dt(ae["AEENDAT"]) < _to_dt(ae["AESTDAT"]))]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AEENDAT",
        check_id="EC020", severity="Error",
        message=f"AE end {r.AEENDAT} precedes AE start {r.AESTDAT}.",
    ) for r in bad.itertuples(index=False)]


def _ec021_cm_end_after_start(forms):
    """CM.CMENDAT >= CM.CMSTDAT."""
    cm = forms.get("cm")
    if cm is None:
        return []
    bad = cm[(_to_dt(cm["CMENDAT"]).notna()) &
             (_to_dt(cm["CMENDAT"]) < _to_dt(cm["CMSTDAT"]))]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="CM", field="CMENDAT",
        check_id="EC021", severity="Error",
        message=f"CM end {r.CMENDAT} precedes CM start {r.CMSTDAT}.",
    ) for r in bad.itertuples(index=False)]


def _ec022_ae_after_birth(forms):
    """AE.AESTDAT > DM.BRTHDAT."""
    ae, dm = forms.get("ae"), forms.get("dm")
    if ae is None or dm is None:
        return []
    j = ae.merge(dm[["SUBJID", "BRTHDAT"]], on="SUBJID", how="left")
    bad = j[(_to_dt(j["BRTHDAT"]).notna()) &
            (_to_dt(j["AESTDAT"]).notna()) &
            (_to_dt(j["AESTDAT"]) <= _to_dt(j["BRTHDAT"]))]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="AE", field="AESTDAT",
        check_id="EC022", severity="Error",
        message=f"AE start {r.AESTDAT} not after date of birth {r.BRTHDAT}.",
    ) for r in bad.itertuples(index=False)]


def _ec023_lb_post_baseline(forms):
    """Post-baseline lab samples must be on/after first dose."""
    lb, ex = forms.get("lb"), forms.get("ex")
    if lb is None or ex is None:
        return []
    j = lb.merge(ex[["SUBJID", "EXSTDT"]], on="SUBJID", how="left")
    bad = j[(j["VISIT"] != "SCREENING") &
            (_to_dt(j["LBDAT"]) < _to_dt(j["EXSTDT"]))]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="LB", field="LBDAT",
        check_id="EC023", severity="Warning",
        message=f"Post-baseline lab {r.LBDAT} ({r.VISIT}) precedes first dose {r.EXSTDT}.",
    ) for r in bad.itertuples(index=False)]


def _ec024_pasi_post_baseline(forms):
    """Post-baseline PASI must be on/after first dose."""
    pasi, ex = forms.get("pasi"), forms.get("ex")
    if pasi is None or ex is None:
        return []
    j = pasi.merge(ex[["SUBJID", "EXSTDT"]], on="SUBJID", how="left")
    bad = j[(j["VISIT"] != "SCREENING") &
            (_to_dt(j["PASIDAT"]) < _to_dt(j["EXSTDT"]))]
    return [Query.new(
        site=r.SITEID, subjid=r.SUBJID, form="PASI", field="PASIDAT",
        check_id="EC024", severity="Warning",
        message=f"Post-baseline PASI {r.PASIDAT} ({r.VISIT}) precedes first dose {r.EXSTDT}.",
    ) for r in bad.itertuples(index=False)]


HANDLERS = {
    "EC019": _ec019_ae_after_treatment,
    "EC020": _ec020_ae_end_after_start,
    "EC021": _ec021_cm_end_after_start,
    "EC022": _ec022_ae_after_birth,
    "EC023": _ec023_lb_post_baseline,
    "EC024": _ec024_pasi_post_baseline,
}


def run(check_row, forms):
    handler = HANDLERS.get(check_row["CheckID"])
    return handler(forms) if handler else []
