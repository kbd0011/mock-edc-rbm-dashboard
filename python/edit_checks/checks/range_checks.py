"""Single-form checks: Required, Range, Format, Plausibility, conditional Range."""
from __future__ import annotations

import re
from typing import Iterable

import pandas as pd

from python.edit_checks import Query


# ---- Logic parsing ------------------------------------------------------

_BETWEEN_RE   = re.compile(r"^\s*BETWEEN\s+(-?\d+(?:\.\d+)?)\s+AND\s+(-?\d+(?:\.\d+)?)\s*$")
_WHEN_BETWEEN = re.compile(
    r"^\s*WHEN\s+(\w+)\s*=\s*'([^']+)'\s+BETWEEN\s+(-?\d+(?:\.\d+)?)\s+AND\s+(-?\d+(?:\.\d+)?)\s*$"
)
_MATCHES_RE   = re.compile(r"^\s*MATCHES\s+/(.+)/\s*$")


def _is_blank(v) -> bool:
    if v is None:
        return True
    if isinstance(v, float) and pd.isna(v):
        return True
    if isinstance(v, str) and v.strip() == "":
        return True
    return False


def _site_of(row, fallback="") -> str:
    return row.get("SITEID", fallback) if isinstance(row, dict) else row.get("SITEID", fallback)


def _emit(check_row, df: pd.DataFrame, field: str, message_fmt: str,
          mask: pd.Series) -> list[Query]:
    out: list[Query] = []
    form_label = str(check_row["Form"]).upper()
    for _, r in df[mask].iterrows():
        out.append(Query.new(
            site=r.get("SITEID", ""),
            subjid=r.get("SUBJID", ""),
            form=form_label,
            field=field,
            check_id=check_row["CheckID"],
            severity=check_row["Severity"],
            message=message_fmt.format(value=r.get(field, "")),
        ))
    return out


# ---- Public API ---------------------------------------------------------

def required_check(check_row, forms: dict[str, pd.DataFrame]) -> list[Query]:
    form_key = check_row["Form"].lower()
    field = check_row["Fields"].strip()
    df = forms.get(form_key)
    if df is None or field not in df.columns:
        return []
    mask = df[field].apply(_is_blank)
    return _emit(check_row, df, field,
                 message_fmt=check_row["QueryText"], mask=mask)


def range_check(check_row, forms: dict[str, pd.DataFrame]) -> list[Query]:
    form_key = check_row["Form"].lower()
    field = check_row["Fields"].strip()
    df = forms.get(form_key)
    if df is None or field not in df.columns:
        return []

    logic = check_row["Logic"]

    # Conditional range: WHEN <gate_field>='value' BETWEEN lo AND hi
    m = _WHEN_BETWEEN.match(logic)
    if m:
        gate, gate_val, lo, hi = m.group(1), m.group(2), float(m.group(3)), float(m.group(4))
        if gate not in df.columns:
            return []
        gate_mask = df[gate].astype(str) == gate_val
        vals = pd.to_numeric(df[field], errors="coerce")
        oor_mask = gate_mask & vals.notna() & ((vals < lo) | (vals > hi))
        return _emit(check_row, df, field,
                     message_fmt=check_row["QueryText"], mask=oor_mask)

    # Plain range: BETWEEN lo AND hi
    m = _BETWEEN_RE.match(logic)
    if m:
        lo, hi = float(m.group(1)), float(m.group(2))
        vals = pd.to_numeric(df[field], errors="coerce")
        oor_mask = vals.notna() & ((vals < lo) | (vals > hi))
        return _emit(check_row, df, field,
                     message_fmt=check_row["QueryText"], mask=oor_mask)

    return []


def format_check(check_row, forms: dict[str, pd.DataFrame]) -> list[Query]:
    form_key = check_row["Form"].lower()
    field = check_row["Fields"].strip()
    df = forms.get(form_key)
    if df is None or field not in df.columns:
        return []

    m = _MATCHES_RE.match(check_row["Logic"])
    if not m:
        return []
    pattern = re.compile(m.group(1))

    def bad(v):
        if _is_blank(v):
            return False   # Required handles blanks; format only on non-blank
        return not pattern.match(str(v))

    mask = df[field].apply(bad)
    return _emit(check_row, df, field,
                 message_fmt=check_row["QueryText"], mask=mask)


def plausibility_check(check_row, forms: dict[str, pd.DataFrame]) -> list[Query]:
    # Same parser as range_check; severity is already 'Warning' from the spec.
    return range_check(check_row, forms)
