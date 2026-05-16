"""
IES LUIS VIVES APP - Rate limiting del asistente IA (Vivi).

Contador persistente en PostgreSQL; el UPSERT es atómico y funciona
con múltiples workers. Ventana deslizante de 1 minuto, máximo 10 peticiones.
"""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

_RATE_LIMIT_WINDOW = timedelta(minutes=1)
_RATE_LIMIT_MAX_REQUESTS = 10


# Crea la tabla de rate limit si no existe (se llama antes de cada consulta)
async def ensure_ai_rate_limit_table(session: AsyncSession) -> None:
    await session.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS ai_rate_limits (
                user_id UUID PRIMARY KEY,
                window_start TIMESTAMP WITH TIME ZONE NOT NULL,
                request_count INTEGER NOT NULL DEFAULT 0,
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
            )
            """
        )
    )


# Incrementa el contador de peticiones del usuario en la ventana actual.
# Si la ventana ha expirado, la reinicia. Devuelve el conteo resultante.
# El UPSERT es atómico: seguro entre múltiples workers/procesos.
async def consume_ai_request_quota(
    session: AsyncSession,
    user_id: UUID,
    *,
    max_requests: int = _RATE_LIMIT_MAX_REQUESTS,
    window: timedelta = _RATE_LIMIT_WINDOW,
) -> int:
    await ensure_ai_rate_limit_table(session)

    now = datetime.now(timezone.utc)
    min_allowed = now - window
    result = await session.execute(
        text(
            """
            INSERT INTO ai_rate_limits (user_id, window_start, request_count, updated_at)
            VALUES (:user_id, :now, 1, :now)
            ON CONFLICT (user_id) DO UPDATE SET
                window_start = CASE
                    WHEN ai_rate_limits.window_start < :min_allowed THEN :now
                    ELSE ai_rate_limits.window_start
                END,
                request_count = CASE
                    WHEN ai_rate_limits.window_start < :min_allowed THEN 1
                    ELSE ai_rate_limits.request_count + 1
                END,
                updated_at = :now
            RETURNING request_count
            """
        ),
        {
            "user_id": str(user_id),
            "now": now,
            "min_allowed": min_allowed,
        },
    )
    count = int(result.scalar_one())
    return count


# Devuelve True si el usuario ha superado el límite de peticiones en la ventana
def is_ai_rate_limited(count: int, *, max_requests: int = _RATE_LIMIT_MAX_REQUESTS) -> bool:
    return count > max_requests
