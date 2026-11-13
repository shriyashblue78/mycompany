from datetime import datetime, date
from typing import Any, Optional


def parse_firestore_date(val: Any) -> Optional[datetime]:
    """
    Parses a date field from Firestore which could be:
    - Firestore Timestamp object (has .to_datetime() or .seconds)
    - Python datetime
    - ISO 8601 string
    - date object
    """
    if val is None:
        return None
    if isinstance(val, datetime):
        return val
    if isinstance(val, date):
        return datetime.combine(val, datetime.min.time())
    if hasattr(val, "to_datetime") and callable(val.to_datetime):
        return val.to_datetime()
    if isinstance(val, str):
        val = val.strip()
        if not val:
            return None
        # Handle trailing Z or offsets
        val = val.replace("Z", "+00:00")
        try:
            return datetime.fromisoformat(val)
        except Exception:
            for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y"):
                try:
                    return datetime.strptime(val, fmt)
                except ValueError:
                    continue
    return None


def parse_float(val: Any, default: float = 0.0) -> float:
    """Safely converts numeric, integer, or string representations to float."""
    if val is None:
        return default
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        val = val.strip().replace(",", "")
        try:
            return float(val)
        except ValueError:
            return default
    return default

