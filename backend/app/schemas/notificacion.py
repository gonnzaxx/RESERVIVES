import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.notificacion import (
    CanalNotificacion,
    EstadoEntregaNotificacion,
    TipoNotificacion,
)


class NotificacionResponse(BaseModel):
    id: uuid.UUID
    tipo: TipoNotificacion
    titulo: str
    mensaje: str
    leida: bool
    created_at: datetime

    class Config:
        from_attributes = True


class PreferenciasNotificacionResponse(BaseModel):
    reserva_aprobada: bool
    reserva_rechazada: bool
    nuevo_espacio: bool
    nuevo_servicio: bool
    nuevo_anuncio: bool
    email_reservas: bool
    email_anuncios: bool

    class Config:
        from_attributes = True


class PreferenciasNotificacionUpdate(BaseModel):
    reserva_aprobada: bool = True
    reserva_rechazada: bool = True
    nuevo_espacio: bool = True
    nuevo_servicio: bool = True
    nuevo_anuncio: bool = True
    email_reservas: bool = True
    email_anuncios: bool = True


class NotificacionEntregaResponse(BaseModel):
    canal: CanalNotificacion
    estado: EstadoEntregaNotificacion
    detalle: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class NotificacionesCountResponse(BaseModel):
    no_leidas: int


class PushTokenCreate(BaseModel):
    token: str = Field(..., min_length=20, max_length=512)
    plataforma: str = Field(default="unknown", min_length=2, max_length=32)
