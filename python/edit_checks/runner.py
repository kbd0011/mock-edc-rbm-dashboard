"""Edit-check runner.

Loads metadata/edit_checks.xlsx and synthetic/raw/*.csv, dispatches each
check to its handler, and writes data/queries/query_log.csv plus a JSON
summary.

CLI:
    python -m python.edit_checks.runner [--data-dir ...] [--checks-spec ...]
"""
from __future__ import annotations

from pathlib import Path

import click
import pandas as pd

from python.edit_checks import Query
from python.edit_checks.checks import range_checks, consistency_checks, temporal_checks
from python.edit_checks.reporters import write_query_log


# Forms loaded into the engine. Keys are lowercased to match the Form column
# in edit_checks.xlsx.
FORM_FILES = {
    "dm":   "dm.csv",
    "ie":   "ie.csv",
    "ex":   "ex.csv",
    "ae":   "ae.csv",
    "cm":   "cm.csv",
    "pasi": "pasi.csv",
    "lb":   "lb.csv",
}


def load_forms(data_dir: Path) -> dict[str, pd.DataFrame]:
    forms = {}
    for key, fname in FORM_FILES.items():
        path = data_dir / fname
        if path.exists():
            forms[key] = pd.read_csv(path)
    return forms


def _dispatch(check_row, forms) -> list[Query]:
    cat = check_row["CheckCategory"]
    if cat == "Required":
        return range_checks.required_check(check_row, forms)
    if cat == "Range":
        return range_checks.range_check(check_row, forms)
    if cat == "Format":
        return range_checks.format_check(check_row, forms)
    if cat == "Plausibility":
        return range_checks.plausibility_check(check_row, forms)
    if cat == "Cross-form":
        # Temporal handlers take precedence; fall back to consistency.
        cid = check_row["CheckID"]
        if cid in temporal_checks.HANDLERS:
            return temporal_checks.run(check_row, forms)
        return consistency_checks.run(check_row, forms)
    print(f"WARN: no runner for category '{cat}' (CheckID={check_row['CheckID']})")
    return []


@click.command()
@click.option("--data-dir", default="synthetic/raw", help="Directory of CSV forms")
@click.option("--checks-spec", default="metadata/edit_checks.xlsx",
              help="Path to edit_checks.xlsx")
@click.option("--out", default="data/queries/query_log.csv",
              help="Output CSV path")
def main(data_dir: str, checks_spec: str, out: str) -> None:
    forms = load_forms(Path(data_dir))
    if not forms:
        raise click.ClickException(f"No form CSVs found in {data_dir}")

    spec = pd.read_excel(checks_spec)
    print(f"Loaded {len(spec)} checks; {len(forms)} forms ({', '.join(forms)})")

    all_queries: list[Query] = []
    for _, check in spec.iterrows():
        all_queries.extend(_dispatch(check, forms))

    summary = write_query_log(all_queries, out)

    print(f"\nWrote {out} ({summary['total']} queries)")
    print(f"  By severity: {summary['by_severity']}")
    print(f"  By site:     {summary['by_site']}")
    print(f"  Top checks:  {[c['check_id'] for c in summary['top_5_checks']]}")


if __name__ == "__main__":
    main()
