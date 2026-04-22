import uuid
from datetime import datetime, date

from pydantic import BaseModel, Field

from app.models.reserva_espacio import EstadoReserva
from app.schemas.tramo import TramoHorarioResponse


class ReservaResponse(BaseModel):
    """Schema de respuesta para una reserva de espacio."""
    id: uuid.UUID
    usuario_id: uuid.UUID
    espacio_id: uuid.UUID
    fecha_inicio: datetime
    fecha_fin: datetime
    observaciones: str | None = None
    estado: EstadoReserva
    tokens_consumidos: int
    tramo_id: uuid.UUID | None = None
    tramo: TramoHorarioResponse | None = None
    # Datos aplanados del usuario y espacio para facilitar las vistas
    nombre_usuario: str | None = None
    nombre_espacio: str | None = None
    tipo_espacio: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ReservaCreate(BaseModel):
    """
    Schema para crear una reserva de espacio con tramo horario.
    """
    espacio_id: uuid.UUID
    fecha: date
    tramo_id: uuid.UUID
    observaciones: str | None = Field(None, max_length=500)


class ReservaUpdate(BaseModel):
    """Schema para actualizar/modificar una reserva."""
    fecha_inicio: datetime | None = None
    fecha_fin: datetime | None = None
    observaciones: str | None = Field(None, max_length=500)
    estado: EstadoReserva | None = None


class ReservaRechazarBody(BaseModel):
    """Body opcional para rechazar una reserva con un motivo."""
    motivo_rechazo: str | None = Field(None, max_length=500)


# --- Schemas para reservas de servicios ---

class ReservaServicioResponse(BaseModel):
    """Schema de respuesta para una reserva de servicio."""
    id: uuid.UUID
    usuario_id: uuid.UUID
    servicio_id: uuid.UUID
    fecha_inicio: datetime
    fecha_fin: datetime
    observaciones: str | None = None
    estado: EstadoReserva
    tokens_consumidos: int
    tramo_id: uuid.UUID | None = None
    tramo: TramoHorarioResponse | None = None
    nombre_usuario: str | None = None
    nombre_servicio: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ReservaServicioCreate(BaseModel):
    """
    Schema para crear una reserva de servicio con tramo horario.
    """
    servicio_id: uuid.UUID
    fecha: date
    tramo_id: uuid.UUID
    observaciones: str | None = Field(None, max_length=500)


