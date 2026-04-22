import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ServicioResponse(BaseModel):
    """Schema de respuesta para un servicio del instituto."""
    id: uuid.UUID
    nombre: str
    descripcion: str | None = None
    imagen_url: str | None = None
    ubicacion: str | None = None
    horario: str | None = None
    precio_tokens: int
    antelacion_dias: int
    activo: bool
    orden: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ServicioCreate(BaseModel):
    """Schema para crear un servicio."""
    nombre: str = Field(..., min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    ubicacion: str | None = None
    horario: str | None = None
    precio_tokens: int = Field(ge=0, default=0)
    antelacion_dias: int = Field(ge=1, default=7)
    orden: int = 0


class ServicioUpdate(BaseModel):
    """Schema para actualizar un servicio."""
    nombre: str | None = Field(None, min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    ubicacion: str | None = None
    horario: str | None = None
    precio_tokens: int | None = Field(None, ge=0)
    antelacion_dias: int | None = Field(None, ge=1)
    activo: bool | None = None
    orden: int | None = None
