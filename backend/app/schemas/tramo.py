"""
RESERVIVES - Schemas de Tramo Horario.

Modelos Pydantic para la serialización de tramos y disponibilidad.
"""

from datetime import time
from uuid import UUID

from pydantic import BaseModel


class TramoHorarioResponse(BaseModel):
    """Schema de respuesta de un tramo horario."""
    id: UUID
    nombre: str
    turno: str
    numero: int
    hora_inicio: time
    hora_fin: time
    es_recreo: bool
    activo: bool

    model_config = {"from_attributes": True}


class TramoDisponibilidadResponse(BaseModel):
    """
    Respuesta del endpoint de disponibilidad diaria.
    Combina los datos del tramo con su estado actual para un recurso y fecha.
    """
    tramo: TramoHorarioResponse
    disponible: bool    # True = se puede reservar (permitido AND NOT reservado)
    permitido: bool     # True = el admin lo tiene habilitado para este recurso
    reservado: bool     # True = ya hay una reserva activa en ese tramo+fecha
    mensaje: str | None = None
