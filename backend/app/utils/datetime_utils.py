from datetime import date, datetime, time, timezone
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


def combine_local_date_time(d: date, t: time, tz_name: str = DEFAULT_APP_TIMEZONE) -> datetime:
    """Build a timezone-aware datetime in the app local timezone."""
    return datetime.combine(d, t).replace(tzinfo=ZoneInfo(tz_name))


def local_slot_to_utc_range(
    d: date,
    start_time: time,
    end_time: time,
    tz_name: str = DEFAULT_APP_TIMEZONE,
) -> tuple[datetime, datetime]:
    """Convert a local date+slot to UTC datetimes for persistence."""
    start_local = combine_local_date_time(d, start_time, tz_name)
    end_local = combine_local_date_time(d, end_time, tz_name)
    return start_local.astimezone(timezone.utc), end_local.astimezone(timezone.utc)
