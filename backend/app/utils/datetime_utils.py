from datetime import date, datetime, time, timezone
from zoneinfo import ZoneInfo

DEFAULT_APP_TIMEZONE = "Europe/Madrid"


# Si el datetime no tiene zona horaria, asume UTC
def ensure_utc_aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


# Convierte un datetime a la zona horaria indicada (por defecto Europe/Madrid)
def to_timezone(value: datetime, tz_name: str = DEFAULT_APP_TIMEZONE) -> datetime:
    return ensure_utc_aware(value).astimezone(ZoneInfo(tz_name))


# Formatea un datetime en la zona horaria local como "DD/MM/YYYY HH:MM"
# Devuelve "-" si el valor es None
def format_normalize(value: datetime | None, tz_name: str = DEFAULT_APP_TIMEZONE) -> str:
    if value is None:
        return "-"
    return to_timezone(value, tz_name).strftime("%d/%m/%Y %H:%M")


# Combina una fecha y hora locales con zona horaria de la aplicación
def combine_local_date_time(d: date, t: time, tz_name: str = DEFAULT_APP_TIMEZONE) -> datetime:
    return datetime.combine(d, t).replace(tzinfo=ZoneInfo(tz_name))


# Convierte una fecha y tramo local a rango UTC (inicio, fin)
def local_slot_to_utc_range(
    d: date,
    start_time: time,
    end_time: time,
    tz_name: str = DEFAULT_APP_TIMEZONE,
) -> tuple[datetime, datetime]:
    start_local = combine_local_date_time(d, start_time, tz_name)
    end_local = combine_local_date_time(d, end_time, tz_name)
    return start_local.astimezone(timezone.utc), end_local.astimezone(timezone.utc)
