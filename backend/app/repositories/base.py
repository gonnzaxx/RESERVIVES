"""
Repositorio base genérico.

Proporciona operaciones CRUD comunes para todos los modelos.
"""

import uuid
from typing import Generic, Type, TypeVar

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import Base

# Tipo genérico para los modelos SQLAlchemy
ModelType = TypeVar("ModelType", bound=Base)


class BaseRepository(Generic[ModelType]):
    """Repositorio base con operaciones CRUD genéricas."""

    def __init__(self, model: Type[ModelType], session: AsyncSession):
        self.model = model
        self.session = session

    async def get_by_id(self, id: uuid.UUID) -> ModelType | None:
        """Obtiene una entidad por su ID."""
        result = await self.session.execute(
            select(self.model).where(self.model.id == id)
        )
        return result.scalar_one_or_none()

    async def get_all(
        self, skip: int = 0, limit: int = 100
    ) -> list[ModelType]:
        """Obtiene todas las entidades con paginación."""
        result = await self.session.execute(
            select(self.model).offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def count(self) -> int:
        """Cuenta el total de entidades."""
        result = await self.session.execute(
            select(func.count()).select_from(self.model)
        )
        return result.scalar_one()

    async def create(self, entity: ModelType) -> ModelType:
        """Crea una nueva entidad."""
        self.session.add(entity)
        await self.session.flush()
        await self.session.refresh(entity)
        return entity

    async def update(self, entity: ModelType, data: dict) -> ModelType:
        """Actualiza una entidad con los datos proporcionados."""
        for key, value in data.items():
            if value is not None:
                setattr(entity, key, value)
        await self.session.flush()
        await self.session.refresh(entity)
        return entity

    async def delete(self, entity: ModelType) -> None:
        """Elimina una entidad."""
        await self.session.delete(entity)
        await self.session.flush()
