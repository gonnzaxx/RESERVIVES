"""Repositorio de anuncios

Gestiona los anuncios tanto activos como pasados. 
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from datetime import datetime

from app.models.anuncio import Anuncio
from app.repositories.base import BaseRepository


class AnuncioRepository(BaseRepository[Anuncio]):
    """Repositorio para operaciones con anuncios."""

    def __init__(self, session: AsyncSession):
        super().__init__(Anuncio, session)

    async def get_activos(self, skip: int = 0, limit: int = 50) -> list[Anuncio]:
        """Obtiene los anuncios activos y no expirados."""
        now = datetime.now()
        result = await self.session.execute(
            select(Anuncio)
            .options(selectinload(Anuncio.autor))
            .where(Anuncio.activo == True)
            .where(
                (Anuncio.fecha_expiracion == None) |
                (Anuncio.fecha_expiracion > now)
            )
            .order_by(Anuncio.destacado.desc(), Anuncio.fecha_publicacion.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_all_with_autor(
        self, skip: int = 0, limit: int = 50
    ) -> list[Anuncio]:
        """Obtiene todos los anuncios con datos del autor."""
        result = await self.session.execute(
            select(Anuncio)
            .options(selectinload(Anuncio.autor))
            .order_by(Anuncio.fecha_publicacion.desc())
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())