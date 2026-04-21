"""
Repositorio de Cafetería.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.cafeteria import CategoriaCafeteria, ProductoCafeteria
from app.repositories.base import BaseRepository


class CategoriaRepository(BaseRepository[CategoriaCafeteria]):
    """Repositorio para categorías de cafetería."""

    def __init__(self, session: AsyncSession):
        super().__init__(CategoriaCafeteria, session)

    async def get_activas_con_productos(self) -> list[CategoriaCafeteria]:
        """Obtiene las categorías activas con sus productos disponibles."""
        result = await self.session.execute(
            select(CategoriaCafeteria)
            .options(selectinload(CategoriaCafeteria.productos))
            .where(CategoriaCafeteria.activa == True)
            .order_by(CategoriaCafeteria.orden)
        )
        return list(result.scalars().all())


class ProductoRepository(BaseRepository[ProductoCafeteria]):
    """Repositorio para productos de cafetería."""

    def __init__(self, session: AsyncSession):
        super().__init__(ProductoCafeteria, session)

    async def get_by_categoria(self, categoria_id) -> list[ProductoCafeteria]:
        """Obtiene productos de una categoría específica."""
        result = await self.session.execute(
            select(ProductoCafeteria)
            .where(ProductoCafeteria.categoria_id == categoria_id)
            .order_by(ProductoCafeteria.orden)
        )
        return list(result.scalars().all())

    async def get_disponibles(self) -> list[ProductoCafeteria]:
        """Obtiene todos los productos disponibles."""
        result = await self.session.execute(
            select(ProductoCafeteria)
            .where(ProductoCafeteria.disponible == True)
            .order_by(ProductoCafeteria.orden)
        )
        return list(result.scalars().all())

    async def get_destacados(self) -> list[ProductoCafeteria]:
        """Obtiene los productos destacados."""
        result = await self.session.execute(
            select(ProductoCafeteria)
            .where(ProductoCafeteria.destacado == True, ProductoCafeteria.disponible == True)
            .order_by(ProductoCafeteria.orden)
        )
        return list(result.scalars().all())
