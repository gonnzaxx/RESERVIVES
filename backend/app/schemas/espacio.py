import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.espacio import TipoEspacio
from app.models.usuario import RolUsuario


class EspacioResponse(BaseModel):
    """Schema de respuesta completa de un espacio."""
    id: uuid.UUID
    nombre: str
    descripcion: str | None = None
    imagen_url: str | None = None
    tipo: TipoEspacio
    precio_tokens: int
    reservable: bool
    requiere_autorizacion: bool
    antelacion_dias: int
    ubicacion: str | None = None
    capacidad: int | None = None
    activo: bool
    roles_permitidos: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class EspacioResumen(BaseModel):
    """Schema reducido de espacio (para listas)."""
    id: uuid.UUID
    nombre: str
    tipo: TipoEspacio
    imagen_url: str | None = None
    precio_tokens: int
    reservable: bool
    ubicacion: str | None = None

    class Config:
        from_attributes = True


class EspacioCreate(BaseModel):
    """Schema para crear un espacio."""
    nombre: str = Field(..., min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    tipo: TipoEspacio
    precio_tokens: int = Field(ge=0, default=0)
    reservable: bool = True
    requiere_autorizacion: bool = False
    antelacion_dias: int = Field(ge=1, default=7)
    ubicacion: str | None = None
    capacidad: int | None = Field(None, ge=1)
    roles_permitidos: list[RolUsuario] = [RolUsuario.ALUMNO, RolUsuario.PROFESOR]


class EspacioUpdate(BaseModel):
    """Schema para actualizar un espacio."""
    nombre: str | None = Field(None, min_length=1, max_length=150)
    descripcion: str | None = None
    imagen_url: str | None = None
    tipo: TipoEspacio | None = None
    precio_tokens: int | None = Field(None, ge=0)
    reservable: bool | None = None
    requiere_autorizacion: bool | None = None
    antelacion_dias: int | None = Field(None, ge=1)
    ubicacion: str | None = None
    capacidad: int | None = Field(None, ge=1)
    activo: bool | None = None
    roles_permitidos: list[RolUsuario] | None = None
