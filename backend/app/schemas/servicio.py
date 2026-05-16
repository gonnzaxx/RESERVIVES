import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class GestorInfo(BaseModel):
    """Info resumida del gestor asignado a un servicio."""
    id: uuid.UUID
    nombre: str
    apellidos: str
    email: str

    class Config:
        from_attributes = True


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
    gestor_usuario_id: uuid.UUID | None = None
    gestor: GestorInfo | None = None
    roles_permitidos: list[str] = []
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
    gestor_usuario_id: uuid.UUID | None = None
    roles_permitidos: list[str] = []


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
    gestor_usuario_id: uuid.UUID | None = None
    roles_permitidos: list[str] | None = None
