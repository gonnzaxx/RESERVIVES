from datetime import datetime, timezone
from zoneinfo import ZoneInfo

DEFAULT_APP_TIMEZONE = "Europe/Madrid"


def ensure_utc_aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def to_timezone(value: datetime, tz_name: str = DEFAULT_APP_TIMEZONE) -> datetime:
    return ensure_utc_aware(value).astimezone(ZoneInfo(tz_name))


def format_for_humans(value: datetime | None, tz_name: str = DEFAULT_APP_TIMEZONE) -> str:
    if value is None:
        return "-"
    return to_timezone(value, tz_name).strftime("%d/%m/%Y %H:%M")
