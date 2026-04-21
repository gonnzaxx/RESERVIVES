"""Repositorio para operaciones con el modelo Incidencia."""

import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.incidencia import Incidencia
from app.repositories.base import BaseRepository


class IncidenciaRepository(BaseRepository[Incidencia]):

    def __init__(self, session: AsyncSession):
        super().__init__(model=Incidencia, session=session)

    async def get_by_usuario(self, usuario_id: uuid.UUID) -> Sequence[Incidencia]:
        """Obtiene las incidencias de un usuario."""
        result = await self.session.execute(
            select(Incidencia)
            .where(Incidencia.usuario_id == usuario_id)
            .order_by(Incidencia.created_at.desc())
        )
        return result.scalars().all()

    async def get_all_with_users(self, skip: int = 0, limit: int = 100) -> Sequence[Incidencia]:
        """Obtiene las incidencias con los datos del usuario cargados."""
        result = await self.session.execute(
            select(Incidencia)
            .options(joinedload(Incidencia.usuario))
            .order_by(Incidencia.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return result.scalars().all()