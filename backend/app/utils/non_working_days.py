import json
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.configuracion import Configuracion


# Comprueba si una fecha es día no laborable según la configuración del sistema
# Acepta fechas concretas ("YYYY-MM-DD") y meses completos ("YYYY-MM")
async def is_non_working_day(session: AsyncSession, fecha: date) -> bool:
    result = await session.execute(
        select(Configuracion.valor).where(Configuracion.clave == "dias_no_laborables")
    )
    raw = result.scalar_one_or_none()
    if not raw:
        return False
    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        return False
    date_str = fecha.strftime("%Y-%m-%d")
    month_str = fecha.strftime("%Y-%m")
    return date_str in data.get("dates", []) or month_str in data.get("months", [])
