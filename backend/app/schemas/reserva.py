import uuid
from datetime import datetime, date

from pydantic import BaseModel, Field
from enum import Enum

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


class BookingKind(str):
    ESPACIO = "ESPACIO"
    SERVICIO = "SERVICIO"


# Reservas Recurrentes 

from app.models.reserva_recurrente import TipoRecurrencia, EstadoReservaRecurrente


class DuracionPlan(str, Enum):
    DIAS_15 = "DIAS_15"
    MES_1 = "MES_1"
    TRIMESTRE_3 = "TRIMESTRE_3"


class ReservaRecurrenteCreate(BaseModel):
    espacio_id: uuid.UUID
    tramo_id: uuid.UUID
    tipo_recurrencia: TipoRecurrencia
    fecha_inicio: date
    fecha_fin_recurrencia: date | None = None
    duracion_plan: DuracionPlan | None = None
    observaciones: str | None = Field(None, max_length=500)


class ReservaRecurrenteResponse(BaseModel):
    id: uuid.UUID
    usuario_id: uuid.UUID
    espacio_id: uuid.UUID
    tramo_id: uuid.UUID
    tipo_recurrencia: TipoRecurrencia
    fecha_inicio: date
    fecha_fin_recurrencia: date
    estado: EstadoReservaRecurrente
    observaciones: str | None = None
    motivo_rechazo: str | None = None
    tokens_por_instancia: int
    ultima_instancia_generada: date | None = None
    nombre_usuario: str | None = None
    nombre_espacio: str | None = None
    nombre_tramo: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ReservaRecurrenteRechazarBody(BaseModel):
    motivo_rechazo: str | None = Field(None, max_length=500)


# Lista de Espera 

from app.models.lista_espera import EstadoListaEspera  # noqa: E402


class ListaEsperaCreate(BaseModel):
    espacio_id: uuid.UUID
    tramo_id: uuid.UUID
    fecha: date


class ListaEsperaResponse(BaseModel):
    id: uuid.UUID
    usuario_id: uuid.UUID
    espacio_id: uuid.UUID
    tramo_id: uuid.UUID
    fecha: date
    posicion: int
    estado: EstadoListaEspera
    nombre_usuario: str | None = None
    nombre_espacio: str | None = None
    nombre_tramo: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# Calendario de disponibilidad 

from app.schemas.tramo import TramoDisponibilidadResponse  


class CalendarioDiaResponse(BaseModel):
    fecha: date
    dia_semana: str
    tramos: list[TramoDisponibilidadResponse]


class ReservaBackofficeResponse(BaseModel):
    id: uuid.UUID
    tipo_reserva: str
    usuario_id: uuid.UUID
    nombre_usuario: str | None = None
    email_usuario: str | None = None
    recurso_id: uuid.UUID
    nombre_recurso: str | None = None
    estado: EstadoReserva
    fecha_inicio: datetime
    fecha_fin: datetime
    observaciones: str | None = None
    tokens_consumidos: int
    created_at: datetime
    updated_at: datetime


class ReservaCancelacionBackofficeBody(BaseModel):
    tipo_reserva: str = Field(..., description="ESPACIO o SERVICIO")
    motivo: str = Field(..., min_length=3, max_length=500)


