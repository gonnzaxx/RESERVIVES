"""
Repositorio de Servicios del Instituto.
Esta clase simplemente obtendrá los servicios activos.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.servicio import Servicio
from app.repositories.base import BaseRepository


class ServicioRepository(BaseRepository[Servicio]):

    def __init__(self, session: AsyncSession):
        super().__init__(Servicio, session)

    async def get_activos(self) -> list[Servicio]:
        """Obtiene todos los servicios activos ordenados."""
        result = await self.session.execute(
            select(Servicio)
            .where(Servicio.activo == True)
            .order_by(Servicio.orden)
        )
        return list(result.scalars().all())
