"""
Repositorio de Espacios.

Esta clase tiene las operaciones de acceso a datos para la entidad Espacio.
"""

import uuid

from sqlalchemy import select
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.espacio import Espacio, EspacioRolPermitido, TipoEspacio
from app.repositories.base import BaseRepository


class EspacioRepository(BaseRepository[Espacio]):

    def __init__(self, session: AsyncSession):
        super().__init__(Espacio, session)

    async def get_all(self, solo_activos: bool = True) -> list[Espacio]:
        """Obtiene todos los espacios."""
        query = select(Espacio).options(
            selectinload(Espacio.roles_permitidos)
        )

        if solo_activos:
            query = query.where(Espacio.activo == True)

        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_by_id_with_roles(self, id: uuid.UUID) -> Espacio | None:
        """Obtiene un espacio con sus roles por UUID."""
        result = await self.session.execute(
            select(Espacio)
            .options(selectinload(Espacio.roles_permitidos))
            .where(Espacio.id == id)
        )
        return result.scalar_one_or_none()

    async def get_by_tipo(
        self, tipo: TipoEspacio, solo_activos: bool = True
    ) -> list[Espacio]:
        """Obtiene espacios filtrados por tipo."""
        query = select(Espacio).options(
            selectinload(Espacio.roles_permitidos)
        ).where(Espacio.tipo == tipo)
        if solo_activos:
            query = query.where(Espacio.activo == True)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_reservables(self, solo_activos: bool = True) -> list[Espacio]:
        """Obtiene todos los espacios que son reservables."""
        query = select(Espacio).options(
            selectinload(Espacio.roles_permitidos)
        ).where(Espacio.reservable == True)
        if solo_activos:
            query = query.where(Espacio.activo == True)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def set_roles_permitidos(
            self, espacio_id: uuid.UUID, roles: list[str]
    ) -> None:
        """Actualiza los roles permitidos de un espacio."""

        # eliminar roles existentes
        await self.session.execute(
            delete(EspacioRolPermitido).where(
                EspacioRolPermitido.espacio_id == espacio_id
            )
        )

        await self.session.flush()

        # crear nuevos roles
        for rol in roles:
            new_role = EspacioRolPermitido(espacio_id=espacio_id, rol=rol)
            self.session.add(new_role)

        await self.session.flush()
