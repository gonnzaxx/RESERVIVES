"""
Repositorio de Reservas.

Esta clase contiene las operaciones de acceso a datos para las reservas de espacios.
También incluye consultas para la detección de solapamiento de reservas.
"""

import uuid
from datetime import datetime

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.reserva_espacio import ReservaEspacio, EstadoReserva
from app.repositories.base import BaseRepository


class ReservaRepository(BaseRepository[ReservaEspacio]):
    """Repositorio para operaciones con reservas de espacios."""

    def __init__(self, session: AsyncSession):
        super().__init__(ReservaEspacio, session)

    async def get_by_id(self, id: uuid.UUID) -> ReservaEspacio | None:
        """Obtiene una reserva con sus relaciones usuario, espacio y tramo."""
        result = await self.session.execute(
            select(ReservaEspacio).options(
                selectinload(ReservaEspacio.usuario),
                selectinload(ReservaEspacio.espacio),
                selectinload(ReservaEspacio.tramo)
            ).where(ReservaEspacio.id == id)
        )
        return result.scalar_one_or_none()

    async def get_by_usuario(
            self, usuario_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ReservaEspacio]:
        """Obtiene las reservas de un usuario con sus relaciones."""
        result = await self.session.execute(
            select(ReservaEspacio)
            .options(
                selectinload(ReservaEspacio.espacio),
                selectinload(ReservaEspacio.usuario),
                selectinload(ReservaEspacio.tramo)
            )
            .where(ReservaEspacio.usuario_id == usuario_id)
            .order_by(ReservaEspacio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_espacio(
            self, espacio_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ReservaEspacio]:
        """Obtiene las reservas de un espacio con sus relaciones."""
        result = await self.session.execute(
            select(ReservaEspacio)
            .options(
                selectinload(ReservaEspacio.usuario),
                selectinload(ReservaEspacio.tramo)
            )
            .where(ReservaEspacio.espacio_id == espacio_id)
            .order_by(ReservaEspacio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def check_solapamiento(
            self,
            espacio_id: uuid.UUID,
            fecha_inicio: datetime,
            fecha_fin: datetime,
            excluir_reserva_id: uuid.UUID | None = None,
    ) -> bool:
        """
        Verifica si existe una reserva solapada en el mismo espacio.
        Devuelve True si hay solapamiento (conflicto).
        Se excluyen reservas RECHAZADAS y CANCELADAS.
        """
        query = select(ReservaEspacio.id).where(
            and_(
                ReservaEspacio.espacio_id == espacio_id,
                ReservaEspacio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                # Condición de solapamiento temporal
                ReservaEspacio.fecha_inicio < fecha_fin,
                ReservaEspacio.fecha_fin > fecha_inicio,
            )
        )
        # Si estamos editando una reserva, excluirla del check
        if excluir_reserva_id:
            query = query.where(ReservaEspacio.id != excluir_reserva_id)

        result = await self.session.execute(query.limit(1))
        return result.scalar_one_or_none() is not None

    async def get_activas_usuario(self, usuario_id: uuid.UUID) -> int:
        """Cuenta las reservas activas (pendientes o aprobadas) de un usuario."""
        result = await self.session.execute(
            select(func.count()).select_from(ReservaEspacio).where(
                and_(
                    ReservaEspacio.usuario_id == usuario_id,
                    ReservaEspacio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                    ReservaEspacio.fecha_fin > datetime.now(),
                )
            )
        )
        return int(result.scalar_one() or 0)

    async def get_by_estado(
            self, estado: EstadoReserva, skip: int = 0, limit: int = 50
    ) -> list[ReservaEspacio]:
        """Obtiene reservas filtradas por estado con sus relaciones."""
        result = await self.session.execute(
            select(ReservaEspacio)
            .options(
                selectinload(ReservaEspacio.usuario),
                selectinload(ReservaEspacio.espacio),
                selectinload(ReservaEspacio.tramo)
            )
            .where(ReservaEspacio.estado == estado)
            .order_by(ReservaEspacio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_all_with_relations(
            self, skip: int = 0, limit: int = 50
    ) -> list[ReservaEspacio]:
        """Obtiene todas las reservas con usuario, espacio y tramo cargados."""
        result = await self.session.execute(
            select(ReservaEspacio)
            .options(
                selectinload(ReservaEspacio.usuario),
                selectinload(ReservaEspacio.espacio),
                selectinload(ReservaEspacio.tramo)
            )
            .order_by(ReservaEspacio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_reservas_dia(self, espacio_id: uuid.UUID, fecha: datetime) -> list[ReservaEspacio]:
        """Obtiene todas las reservas activas para un espacio en un día concreto."""
        inicio_dia = fecha.replace(hour=0, minute=0, second=0, microsecond=0)
        fin_dia = fecha.replace(hour=23, minute=59, second=59, microsecond=999999)

        result = await self.session.execute(
            select(ReservaEspacio).where(
                and_(
                    ReservaEspacio.espacio_id == espacio_id,
                    ReservaEspacio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                    ReservaEspacio.fecha_inicio < fin_dia,
                    ReservaEspacio.fecha_fin > inicio_dia,
                )
            )
        )
        return list(result.scalars().all())