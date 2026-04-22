import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class AnuncioResponse(BaseModel):
    """Schema de respuesta para un anuncio."""
    id: uuid.UUID
    autor_id: uuid.UUID
    titulo: str
    contenido: str
    imagen_url: str | None = None
    destacado: bool
    activo: bool
    fecha_publicacion: datetime
    fecha_expiracion: datetime | None = None
    nombre_autor: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AnuncioCreate(BaseModel):
    """Schema para crear un anuncio."""
    titulo: str = Field(..., min_length=1, max_length=200)
    contenido: str = Field(..., min_length=1)
    imagen_url: str | None = None
    destacado: bool = False
    fecha_expiracion: datetime | None = None


class AnuncioUpdate(BaseModel):
    """Schema para actualizar un anuncio."""
    titulo: str | None = Field(None, min_length=1, max_length=200)
    contenido: str | None = Field(None, min_length=1)
    imagen_url: str | None = None
    destacado: bool | None = None
    activo: bool | None = None
    fecha_expiracion: datetime | None = None
