"""Write the query log CSV and a sibling JSON summary."""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

import pandas as pd

from python.edit_checks import Query


def write_query_log(queries: list[Query], out_path: str | Path) -> dict:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    df = pd.DataFrame([q.to_dict() for q in queries])
    if not df.empty:
        df = df.sort_values(["site", "subjid", "form", "check_id"]).reset_index(drop=True)
    df.to_csv(out_path, index=False)

    summary = write_summary(queries, out_path.with_suffix(".summary.json"))
    return summary


def write_summary(queries: list[Query], out_path: str | Path) -> dict:
    by_severity = Counter(q.severity for q in queries)
    by_site = Counter(q.site for q in queries)
    by_form = Counter(q.form for q in queries)
    by_check = Counter(q.check_id for q in queries)

    top_5_checks = [{"check_id": cid, "count": n}
                    for cid, n in by_check.most_common(5)]

    summary = {
        "total":       len(queries),
        "by_severity": dict(by_severity),
        "by_site":     dict(sorted(by_site.items())),
        "by_form":     dict(sorted(by_form.items())),
        "top_5_checks": top_5_checks,
    }

    Path(out_path).write_text(json.dumps(summary, indent=2))
    return summary
