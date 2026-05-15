"""Pytest tests for the edit-check engine.

Each test builds a tiny in-memory `forms` dict with known violations and
asserts the right number/kind of Query records come back.
"""
from __future__ import annotations

import pandas as pd
import pytest

from python.edit_checks.checks import range_checks, consistency_checks, temporal_checks


# ---- helpers -----------------------------------------------------------

def _check(check_id, category, form, fields, logic, severity="Error",
           query="msg", sas=""):
    return pd.Series({
        "CheckID": check_id,
        "CheckCategory": category,
        "Form": form,
        "Fields": fields,
        "Logic": logic,
        "Severity": severity,
        "QueryText": query,
        "SAS_Equivalent_Pseudocode": sas,
    })


# ---- Required -----------------------------------------------------------

def test_required_check_flags_blank():
    df = pd.DataFrame({
        "SITEID": ["S001", "S001", "S002"],
        "SUBJID": ["S001-0001", "", "S002-0001"],
    })
    queries = range_checks.required_check(
        _check("EC001", "Required", "dm", "SUBJID", "REQUIRED"),
        {"dm": df},
    )
    assert len(queries) == 1
    assert queries[0].subjid == ""
    assert queries[0].field == "SUBJID"


def test_required_check_does_not_flag_filled():
    df = pd.DataFrame({"SITEID": ["S001"], "SUBJID": ["S001-0001"]})
    queries = range_checks.required_check(
        _check("EC001", "Required", "dm", "SUBJID", "REQUIRED"),
        {"dm": df},
    )
    assert len(queries) == 0


# ---- Range --------------------------------------------------------------

def test_range_check_flags_below_min():
    df = pd.DataFrame({"SITEID": ["S001"], "SUBJID": ["S001-0001"], "AGE": [17]})
    queries = range_checks.range_check(
        _check("EC003", "Range", "dm", "AGE", "BETWEEN 18 AND 75"),
        {"dm": df},
    )
    assert len(queries) == 1


def test_range_check_flags_above_max():
    df = pd.DataFrame({"SITEID": ["S001"], "SUBJID": ["S001-0001"], "AGE": [80]})
    queries = range_checks.range_check(
        _check("EC003", "Range", "dm", "AGE", "BETWEEN 18 AND 75"),
        {"dm": df},
    )
    assert len(queries) == 1


def test_range_check_passes_in_range():
    df = pd.DataFrame({"SITEID": ["S001"], "SUBJID": ["S001-0001"], "AGE": [50]})
    queries = range_checks.range_check(
        _check("EC003", "Range", "dm", "AGE", "BETWEEN 18 AND 75"),
        {"dm": df},
    )
    assert len(queries) == 0


def test_conditional_range_only_fires_when_gated():
    df = pd.DataFrame({
        "SITEID": ["S001", "S001"],
        "SUBJID": ["S001-0001", "S001-0001"],
        "LBTESTCD": ["WBC", "HGB"],
        "LBORRES": [200, 200],   # WBC 200 is OOR; HGB 200 is OOR by absolute but not checked
    })
    queries = range_checks.range_check(
        _check("EC011", "Range", "lb", "LBORRES",
               "WHEN LBTESTCD='WBC' BETWEEN 0.1 AND 100",
               severity="Warning"),
        {"lb": df},
    )
    assert len(queries) == 1   # only WBC row fires


# ---- Format -------------------------------------------------------------

def test_format_check_flags_bad_pattern():
    df = pd.DataFrame({
        "SITEID": ["S001", "S001"],
        "SUBJID": ["S001-0001", "BAD-FORMAT"],
    })
    queries = range_checks.format_check(
        _check("EC015", "Format", "dm", "SUBJID",
               "MATCHES /^S[0-9]{3}-[0-9]{4}$/"),
        {"dm": df},
    )
    assert len(queries) == 1


def test_format_check_ignores_blanks():
    """Blank SUBJID should be caught by Required, not Format."""
    df = pd.DataFrame({"SITEID": ["S001"], "SUBJID": [""]})
    queries = range_checks.format_check(
        _check("EC015", "Format", "dm", "SUBJID",
               "MATCHES /^S[0-9]{3}-[0-9]{4}$/"),
        {"dm": df},
    )
    assert len(queries) == 0


# ---- Cross-form temporal ------------------------------------------------

def test_ec019_ae_before_treatment():
    forms = {
        "ae": pd.DataFrame({
            "SITEID": ["S001", "S001"], "SUBJID": ["S001-0001"] * 2,
            "AESTDAT": ["2025-01-01", "2025-06-01"],
        }),
        "ex": pd.DataFrame({
            "SUBJID": ["S001-0001"], "EXSTDT": ["2025-03-01"],
        }),
    }
    queries = temporal_checks.run(
        _check("EC019", "Cross-form", "ae+ex", "AESTDAT,EXSTDT",
               "ae.AESTDAT >= ex.EXSTDT", severity="Warning"),
        forms,
    )
    # The 2025-01-01 AE precedes the 2025-03-01 EXSTDT → 1 query.
    assert len(queries) == 1


def test_ec022_ae_after_birth():
    forms = {
        "ae": pd.DataFrame({
            "SITEID": ["S001"], "SUBJID": ["S001-0001"],
            "AESTDAT": ["1990-01-01"],   # implausibly early — before BRTHDAT
        }),
        "dm": pd.DataFrame({
            "SUBJID": ["S001-0001"], "BRTHDAT": ["2000-01-01"],
        }),
    }
    queries = temporal_checks.run(
        _check("EC022", "Cross-form", "ae+dm", "AESTDAT,BRTHDAT",
               "ae.AESTDAT > dm.BRTHDAT"),
        forms,
    )
    assert len(queries) == 1


# ---- Cross-form consistency ---------------------------------------------

def test_ec025_serious_ae_severity_consistency():
    forms = {
        "ae": pd.DataFrame({
            "SITEID": ["S001", "S001"],
            "SUBJID": ["S001-0001"] * 2,
            "AETERM": ["headache", "anaphylaxis"],
            "AESER":  ["N", "Y"],
            "AESEV":  ["MILD", "MILD"],     # serious + MILD = inconsistent
        }),
    }
    queries = consistency_checks.run(
        _check("EC025", "Cross-form", "ae", "AESER,AESEV",
               "IF ae.AESER = 'Y' THEN ae.AESEV IN ('MODERATE','SEVERE')",
               severity="Warning"),
        forms,
    )
    assert len(queries) == 1
    assert queries[0].check_id == "EC025"


def test_ec026_pasi_total_inconsistency():
    forms = {
        "pasi": pd.DataFrame({
            "SITEID": ["S001"], "SUBJID": ["S001-0001"],
            "PASIHEAD": [1.0], "PASIARMS": [2.0],
            "PASITRNK": [3.0], "PASILEGS": [4.0],
            "PASITOT":  [15.0],   # should be 10.0 ± 0.1 → flag
        }),
    }
    queries = consistency_checks.run(
        _check("EC026", "Cross-form", "pasi", "PASITOT", "", severity="Error"),
        forms,
    )
    assert len(queries) == 1
