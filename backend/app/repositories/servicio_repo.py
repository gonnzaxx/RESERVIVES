"""
Repositorio de servicios del instituto.
"""

import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.servicio import Servicio, ServicioRolPermitido
from app.repositories.base import BaseRepository


class ServicioRepository(BaseRepository[Servicio]):

    def __init__(self, session: AsyncSession):
        super().__init__(Servicio, session)

    async def get_activos(self) -> list[Servicio]:
        """Obtiene todos los servicios activos ordenados."""
        result = await self.session.execute(
            select(Servicio)
            .options(selectinload(Servicio.roles_permitidos))
            .where(Servicio.activo == True)
            .order_by(Servicio.orden)
        )
        return list(result.scalars().all())

    async def get_all(self, skip: int = 0, limit: int = 100) -> list[Servicio]:
        """Obtiene todos los servicios con sus roles."""
        result = await self.session.execute(
            select(Servicio)
            .options(selectinload(Servicio.roles_permitidos))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_id(self, id: uuid.UUID) -> Servicio | None:
        """Obtiene un servicio con sus roles por UUID."""
        result = await self.session.execute(
            select(Servicio)
            .options(selectinload(Servicio.roles_permitidos))
            .where(Servicio.id == id)
        )
        return result.scalar_one_or_none()

    async def set_roles_permitidos(self, servicio_id: uuid.UUID, roles: list[str]) -> None:
        """Actualiza los roles permitidos de un servicio."""
        await self.session.execute(
            delete(ServicioRolPermitido).where(
                ServicioRolPermitido.servicio_id == servicio_id
            )
        )
        await self.session.flush()
        for rol in roles:
            self.session.add(ServicioRolPermitido(servicio_id=servicio_id, rol=rol))
        await self.session.flush()
