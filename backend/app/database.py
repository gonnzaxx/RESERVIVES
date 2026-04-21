"""
RESERVIVES - Conexión a la base de datos.

Configura SQLAlchemy async para PostgreSQL y proporciona
la sesión de base de datos como dependencia de FastAPI.
"""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()

# Motor async de SQLAlchemy para PostgreSQL
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.APP_DEBUG,  # Log de consultas SQL en modo debug
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,       # Verifica conexión antes de usar
)

# Fábrica de sesiones async
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Clase base para todos los modelos SQLAlchemy."""
    pass


async def get_db() -> AsyncSession:
    """
    Dependencia de FastAPI que proporciona una sesión de BD.
    Se cierra automáticamente al finalizar la petición.
    """
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
