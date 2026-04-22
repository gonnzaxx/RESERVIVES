import uuid
from datetime import datetime
from pydantic import BaseModel

from app.models.incidencia import EstadoIncidencia
from app.schemas.usuario import UsuarioResumen


class IncidenciaBase(BaseModel):
    descripcion: str
    imagen_url: str | None = None


class IncidenciaCreate(IncidenciaBase):
    pass


class IncidenciaUpdate(BaseModel):
    estado: EstadoIncidencia
    comentario_admin: str | None = None


class IncidenciaResponse(IncidenciaBase):
    id: uuid.UUID
    usuario_id: uuid.UUID
    estado: EstadoIncidencia
    comentario_admin: str | None
    created_at: datetime
    updated_at: datetime
    
    usuario: UsuarioResumen | None = None

    class Config:
        from_attributes = True

