import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


# Categorías 
class CategoriaResponse(BaseModel):
    """Schema de respuesta para una categoría de cafetería."""
    id: uuid.UUID
    nombre: str
    descripcion: str | None = None
    imagen_url: str | None = None
    orden: int
    activa: bool
    productos: list["ProductoResponse"] = []

    class Config:
        from_attributes = True


class CategoriaCreate(BaseModel):
    """Schema para crear una categoría."""
    nombre: str = Field(..., min_length=1, max_length=100)
    descripcion: str | None = None
    imagen_url: str | None = None
    orden: int = 0


class CategoriaUpdate(BaseModel):
    """Schema para actualizar una categoría."""
    nombre: str | None = Field(None, min_length=1, max_length=100)
    descripcion: str | None = None
    imagen_url: str | None = None
    orden: int | None = None
    activa: bool | None = None


# Productos

class ProductoResponse(BaseModel):
    """Schema de respuesta para un producto de cafetería."""
    id: uuid.UUID
    categoria_id: uuid.UUID
    nombre: str
    descripcion: str | None = None
    imagen_url: str | None = None
    precio: Decimal
    disponible: bool
    destacado: bool
    orden: int

    class Config:
        from_attributes = True


class ProductoCreate(BaseModel):
    """Schema para crear un producto."""
    categoria_id: uuid.UUID
    nombre: str = Field(..., min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    precio: Decimal = Field(..., ge=0)
    disponible: bool = True
    destacado: bool = False
    orden: int = 0


class ProductoUpdate(BaseModel):
    """Schema para actualizar un producto."""
    categoria_id: uuid.UUID | None = None
    nombre: str | None = Field(None, min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    precio: Decimal | None = Field(None, ge=0)
    disponible: bool | None = None
    destacado: bool | None = None
    orden: int | None = None
