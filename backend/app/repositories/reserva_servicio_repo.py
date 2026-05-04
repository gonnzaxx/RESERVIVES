"""
RESERVIVES - Repositorio de Reservas de Servicios.

Encapsula todas las queries de base de datos relativas a ReservaServicio,
siguiendo el mismo patrón que ReservaEspacioRepository (reserva_espacio_repo.py).
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.reserva_espacio import EstadoReserva
from app.models.reserva_servicio import ReservaServicio
from app.repositories.base import BaseRepository


class ReservaServicioRepository(BaseRepository[ReservaServicio]):
    """Repositorio para operaciones con reservas de servicios."""

    def __init__(self, session: AsyncSession):
        super().__init__(ReservaServicio, session)

    async def get_by_id(self, id: uuid.UUID) -> ReservaServicio | None:
        """Obtiene una reserva de servicio con sus relaciones usuario, servicio y tramo."""
        result = await self.session.execute(
            select(ReservaServicio).options(
                selectinload(ReservaServicio.usuario),
                selectinload(ReservaServicio.servicio),
                selectinload(ReservaServicio.tramo),
            ).where(ReservaServicio.id == id)
        )
        return result.scalar_one_or_none()

    async def get_by_usuario(
        self, usuario_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ReservaServicio]:
        """Obtiene las reservas de servicio de un usuario con sus relaciones."""
        result = await self.session.execute(
            select(ReservaServicio)
            .options(
                selectinload(ReservaServicio.servicio),
                selectinload(ReservaServicio.usuario),
                selectinload(ReservaServicio.tramo),
            )
            .where(ReservaServicio.usuario_id == usuario_id)
            .order_by(ReservaServicio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_servicio(
        self, servicio_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ReservaServicio]:
        """Obtiene las reservas de un servicio concreto con sus relaciones."""
        result = await self.session.execute(
            select(ReservaServicio)
            .options(
                selectinload(ReservaServicio.usuario),
                selectinload(ReservaServicio.tramo),
            )
            .where(ReservaServicio.servicio_id == servicio_id)
            .order_by(ReservaServicio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_estado(
        self, estado: EstadoReserva, skip: int = 0, limit: int = 50
    ) -> list[ReservaServicio]:
        """Obtiene reservas de servicio filtradas por estado con sus relaciones."""
        result = await self.session.execute(
            select(ReservaServicio)
            .options(
                selectinload(ReservaServicio.usuario),
                selectinload(ReservaServicio.servicio),
                selectinload(ReservaServicio.tramo),
            )
            .where(ReservaServicio.estado == estado)
            .order_by(ReservaServicio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_all_with_relations(
        self, skip: int = 0, limit: int = 50
    ) -> list[ReservaServicio]:
        """Obtiene todas las reservas de servicio con relaciones cargadas."""
        result = await self.session.execute(
            select(ReservaServicio)
            .options(
                selectinload(ReservaServicio.usuario),
                selectinload(ReservaServicio.servicio),
                selectinload(ReservaServicio.tramo),
            )
            .order_by(ReservaServicio.fecha_inicio.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_activas_usuario(self, usuario_id: uuid.UUID) -> int:
        """Cuenta las reservas de servicio activas (pendientes o aprobadas) de un usuario."""
        result = await self.session.execute(
            select(func.count()).select_from(ReservaServicio).where(
                and_(
                    ReservaServicio.usuario_id == usuario_id,
                    ReservaServicio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                    ReservaServicio.fecha_fin > datetime.now(timezone.utc),
                )
            )
        )
        return int(result.scalar_one() or 0)

    async def check_solapamiento(
        self,
        servicio_id: uuid.UUID,
        fecha_inicio: datetime,
        fecha_fin: datetime,
        excluir_reserva_id: uuid.UUID | None = None,
    ) -> bool:
        """
        Verifica si existe una reserva solapada para el mismo servicio.
        Devuelve True si hay solapamiento.
        Se excluyen reservas RECHAZADAS y CANCELADAS.
        """
        query = select(ReservaServicio.id).where(
            and_(
                ReservaServicio.servicio_id == servicio_id,
                ReservaServicio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                ReservaServicio.fecha_inicio < fecha_fin,
                ReservaServicio.fecha_fin > fecha_inicio,
            )
        )
        if excluir_reserva_id:
            query = query.where(ReservaServicio.id != excluir_reserva_id)

        result = await self.session.execute(query.limit(1))
        return result.scalar_one_or_none() is not None
