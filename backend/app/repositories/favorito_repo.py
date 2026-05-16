"""
Repositorio de favoritos. Gestiona los espacios y servicios marcados como favoritos por cada usuario.
"""

import uuid

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.favorito import FavoritoEspacio, FavoritoServicio


class FavoritoRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # Devuelve los espacios favoritos del usuario.
    async def get_espacios_by_usuario(self, usuario_id: uuid.UUID):
        result = await self.session.execute(
            select(FavoritoEspacio).where(FavoritoEspacio.usuario_id == usuario_id)
        )
        return result.scalars().all()

    # Devuelve los servicios favoritos del usuario.
    async def get_servicios_by_usuario(self, usuario_id: uuid.UUID):
        result = await self.session.execute(
            select(FavoritoServicio).where(FavoritoServicio.usuario_id == usuario_id)
        )
        return result.scalars().all()

    # Añade un espacio a favoritos del usuario.
    async def add_espacio(self, usuario_id: uuid.UUID, espacio_id: uuid.UUID):
        favorito = FavoritoEspacio(usuario_id=usuario_id, espacio_id=espacio_id)
        self.session.add(favorito)
        await self.session.flush()
        return favorito

    # Elimina un espacio de favoritos del usuario.
    async def remove_espacio(self, usuario_id: uuid.UUID, espacio_id: uuid.UUID):
        await self.session.execute(
            delete(FavoritoEspacio).where(
                FavoritoEspacio.usuario_id == usuario_id,
                FavoritoEspacio.espacio_id == espacio_id
            )
        )
        await self.session.flush()

    # Añade un servicio a favoritos del usuario.
    async def add_servicio(self, usuario_id: uuid.UUID, servicio_id: uuid.UUID):
        favorito = FavoritoServicio(usuario_id=usuario_id, servicio_id=servicio_id)
        self.session.add(favorito)
        await self.session.flush()
        return favorito

    # Elimina un servicio de favoritos del usuario.
    async def remove_servicio(self, usuario_id: uuid.UUID, servicio_id: uuid.UUID):
        await self.session.execute(
            delete(FavoritoServicio).where(
                FavoritoServicio.usuario_id == usuario_id,
                FavoritoServicio.servicio_id == servicio_id
            )
        )
        await self.session.flush()