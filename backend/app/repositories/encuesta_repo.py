""" Repositorio de encuestas

Gestiona las encuestas registradas y activas. 
"""

import uuid
from typing import Sequence, Optional
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.models.encuesta import Encuesta, EncuestaOpcion, VotoEncuesta
from app.repositories.base import BaseRepository


class EncuestaRepository(BaseRepository[Encuesta]):
    def __init__(self, db):
        super().__init__(Encuesta, db)

    async def get_with_options(self, encuesta_id: uuid.UUID) -> Optional[Encuesta]:
        result = await self.session.execute(
            select(Encuesta)
            .where(Encuesta.id == encuesta_id)
            .options(selectinload(Encuesta.opciones))
        )
        return result.scalar_one_or_none()

    async def list_active(self) -> Sequence[Encuesta]:
        result = await self.session.execute(
            select(Encuesta)
            .where(Encuesta.activa == True, Encuesta.fecha_fin > func.now())
            .options(selectinload(Encuesta.opciones))
            .order_by(Encuesta.created_at.desc())
        )
        return result.scalars().all()

    async def get_results(self, encuesta_id: uuid.UUID) -> dict:
        # Reesultados de una encuesta en específico
        encuesta = await self.get_with_options(encuesta_id)
        if not encuesta:
            return None

        # Count votes per option
        votes_result = await self.session.execute(
            select(EncuestaOpcion.id, func.count(VotoEncuesta.id))
            .outerjoin(VotoEncuesta, VotoEncuesta.opcion_id == EncuestaOpcion.id)
            .where(EncuestaOpcion.encuesta_id == encuesta_id)
            .group_by(EncuestaOpcion.id)
        )
        counts = {row[0]: row[1] for row in votes_result.all()}

        total_votos = sum(counts.values())

        return {
            "encuesta": encuesta,
            "counts": counts,
            "total_votos": total_votos
        }

    async def user_has_voted(self, usuario_id: uuid.UUID, encuesta_id: uuid.UUID) -> Optional[uuid.UUID]:
        result = await self.session.execute(
            select(VotoEncuesta.opcion_id)
            .where(VotoEncuesta.usuario_id == usuario_id, VotoEncuesta.encuesta_id == encuesta_id)
        )
        return result.scalar_one_or_none()

    async def cast_vote(self, usuario_id: uuid.UUID, encuesta_id: uuid.UUID, opcion_id: uuid.UUID) -> VotoEncuesta:
        voto = VotoEncuesta(
            usuario_id=usuario_id,
            encuesta_id=encuesta_id,
            opcion_id=opcion_id
        )
        self.session.add(voto)
        await self.session.flush()
        return voto