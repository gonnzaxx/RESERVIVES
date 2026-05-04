"""
RESERVIVES - Repositorio de Lista de Espera.
"""

import uuid
from datetime import date

from sqlalchemy import func, select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lista_espera import ListaEspera, EstadoListaEspera
from app.repositories.base import BaseRepository


class ListaEsperaRepository(BaseRepository[ListaEspera]):

    def __init__(self, session: AsyncSession):
        super().__init__(ListaEspera, session)

    async def get_by_id(self, id: uuid.UUID) -> ListaEspera | None:
        result = await self.session.execute(
            select(ListaEspera)
            .options(
                selectinload(ListaEspera.usuario),
                selectinload(ListaEspera.espacio),
                selectinload(ListaEspera.tramo),
            )
            .where(ListaEspera.id == id)
        )
        return result.scalar_one_or_none()

    async def get_by_usuario(
        self, usuario_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> list[ListaEspera]:
        result = await self.session.execute(
            select(ListaEspera)
            .options(
                selectinload(ListaEspera.espacio),
                selectinload(ListaEspera.tramo),
            )
            .where(
                and_(
                    ListaEspera.usuario_id == usuario_id,
                    ListaEspera.estado == EstadoListaEspera.ACTIVA,
                )
            )
            .order_by(ListaEspera.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_entrada_activa(
        self,
        usuario_id: uuid.UUID,
        espacio_id: uuid.UUID,
        tramo_id: uuid.UUID,
        fecha: date,
    ) -> ListaEspera | None:
        """Comprueba si el usuario ya está en la lista para este slot."""
        result = await self.session.execute(
            select(ListaEspera).where(
                and_(
                    ListaEspera.usuario_id == usuario_id,
                    ListaEspera.espacio_id == espacio_id,
                    ListaEspera.tramo_id == tramo_id,
                    ListaEspera.fecha == fecha,
                    ListaEspera.estado.in_(
                        [EstadoListaEspera.ACTIVA, EstadoListaEspera.NOTIFICADA]
                    ),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_siguiente_en_cola(
        self,
        espacio_id: uuid.UUID,
        tramo_id: uuid.UUID,
        fecha: date,
    ) -> ListaEspera | None:
        """Devuelve la primera entrada activa en cola (menor posición)."""
        result = await self.session.execute(
            select(ListaEspera)
            .options(
                selectinload(ListaEspera.usuario),
                selectinload(ListaEspera.espacio),
            )
            .where(
                and_(
                    ListaEspera.espacio_id == espacio_id,
                    ListaEspera.tramo_id == tramo_id,
                    ListaEspera.fecha == fecha,
                    ListaEspera.estado == EstadoListaEspera.ACTIVA,
                )
            )
            .order_by(ListaEspera.posicion.asc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_proxima_posicion(
        self,
        espacio_id: uuid.UUID,
        tramo_id: uuid.UUID,
        fecha: date,
    ) -> int:
        """Calcula la siguiente posición libre en la cola."""
        result = await self.session.execute(
            select(func.max(ListaEspera.posicion)).where(
                and_(
                    ListaEspera.espacio_id == espacio_id,
                    ListaEspera.tramo_id == tramo_id,
                    ListaEspera.fecha == fecha,
                    ListaEspera.estado.in_(
                        [EstadoListaEspera.ACTIVA, EstadoListaEspera.NOTIFICADA]
                    ),
                )
            )
        )
        max_pos = result.scalar_one_or_none()
        return (max_pos or 0) + 1

    async def count_activos(
        self,
        espacio_id: uuid.UUID,
        tramo_id: uuid.UUID,
        fecha: date,
    ) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(ListaEspera).where(
                and_(
                    ListaEspera.espacio_id == espacio_id,
                    ListaEspera.tramo_id == tramo_id,
                    ListaEspera.fecha == fecha,
                    ListaEspera.estado.in_(
                        [EstadoListaEspera.ACTIVA, EstadoListaEspera.NOTIFICADA]
                    ),
                )
            )
        )
        return int(result.scalar_one() or 0)
