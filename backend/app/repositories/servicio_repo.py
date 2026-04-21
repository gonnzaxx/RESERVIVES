"""
Repositorio de Servicios del Instituto.
Esta clase simplemente obtendrá los servicios activos.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.servicio import ServicioInstituto
from app.repositories.base import BaseRepository


class ServicioRepository(BaseRepository[ServicioInstituto]):

    def __init__(self, session: AsyncSession):
        super().__init__(ServicioInstituto, session)

    async def get_activos(self) -> list[ServicioInstituto]:
        """Obtiene todos los servicios activos ordenados."""
        result = await self.session.execute(
            select(ServicioInstituto)
            .where(ServicioInstituto.activo == True)
            .order_by(ServicioInstituto.orden)
        )
        return list(result.scalars().all())
