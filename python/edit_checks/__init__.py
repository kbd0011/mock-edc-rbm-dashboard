"""Edit-check engine for IMM-PSO-3001 synthetic data."""
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
import uuid


@dataclass
class Query:
    query_id:   str
    timestamp:  str
    site:       str
    subjid:     str
    form:       str
    field:      str
    check_id:   str
    severity:   str
    message:    str
    status:     str = "Open"

    @classmethod
    def new(cls, *, site, subjid, form, field, check_id, severity, message):
        return cls(
            query_id=str(uuid.uuid4()),
            timestamp=datetime.now(timezone.utc).isoformat(timespec="seconds"),
            site=site or "",
            subjid=subjid or "",
            form=form,
            field=field,
            check_id=check_id,
            severity=severity,
            message=message,
        )

    def to_dict(self):
        return asdict(self)
