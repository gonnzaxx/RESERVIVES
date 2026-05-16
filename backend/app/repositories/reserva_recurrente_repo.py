"""
RESERVIVES - Repositorio de Reservas Recurrentes.
"""

import uuid
from datetime import date

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.reserva_recurrente import ReservaRecurrente, EstadoReservaRecurrente
from app.repositories.base import BaseRepository


class ReservaRecurrenteRepository(BaseRepository[ReservaRecurrente]):

    def __init__(self, session: AsyncSession):
        super().__init__(ReservaRecurrente, session)

    # Obtiene una reserva recurrente con usuario, espacio y tramo cargados.
    async def get_by_id(self, id: uuid.UUID) -> ReservaRecurrente | None:
        result = await self.session.execute(
            select(ReservaRecurrente)
            .options(
                selectinload(ReservaRecurrente.usuario),
                selectinload(ReservaRecurrente.espacio),
                selectinload(ReservaRecurrente.tramo),
            )
            .where(ReservaRecurrente.id == id)
        )
        return result.scalar_one_or_none()

    # Devuelve las reservas recurrentes de un usuario ordenadas por fecha de creación.
    async def get_by_usuario(
        self, usuario_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ReservaRecurrente]:
        result = await self.session.execute(
            select(ReservaRecurrente)
            .options(
                selectinload(ReservaRecurrente.espacio),
                selectinload(ReservaRecurrente.tramo),
            )
            .where(ReservaRecurrente.usuario_id == usuario_id)
            .order_by(ReservaRecurrente.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    # Filtra reservas recurrentes por estado con todas sus relaciones.
    async def get_by_estado(
        self,
        estado: EstadoReservaRecurrente,
        skip: int = 0,
        limit: int = 50,
    ) -> list[ReservaRecurrente]:
        result = await self.session.execute(
            select(ReservaRecurrente)
            .options(
                selectinload(ReservaRecurrente.usuario),
                selectinload(ReservaRecurrente.espacio),
                selectinload(ReservaRecurrente.tramo),
            )
            .where(ReservaRecurrente.estado == estado)
            .order_by(ReservaRecurrente.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_aprobadas_pendientes_de_generacion(
        self, hoy: date
    ) -> list[ReservaRecurrente]:
        """Devuelve patrones aprobados cuya próxima instancia aún no se ha generado."""
        result = await self.session.execute(
            select(ReservaRecurrente)
            .options(
                selectinload(ReservaRecurrente.espacio),
                selectinload(ReservaRecurrente.tramo),
            )
            .where(
                and_(
                    ReservaRecurrente.estado == EstadoReservaRecurrente.APROBADA,
                    ReservaRecurrente.fecha_fin_recurrencia >= hoy,
                )
            )
        )
        return list(result.scalars().all())

    # Obtiene todas las reservas recurrentes con relaciones cargadas.
    async def get_all_with_relations(
        self, skip: int = 0, limit: int = 50
    ) -> list[ReservaRecurrente]:
        result = await self.session.execute(
            select(ReservaRecurrente)
            .options(
                selectinload(ReservaRecurrente.usuario),
                selectinload(ReservaRecurrente.espacio),
                selectinload(ReservaRecurrente.tramo),
            )
            .order_by(ReservaRecurrente.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())
