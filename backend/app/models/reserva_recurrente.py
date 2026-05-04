"""
RESERVIVES - Modelo de Reserva Recurrente.

Almacena el patrón de recurrencia de una reserva de espacio.
Requiere aprobación administrativa antes de generar instancias.
Cada instancia aprobada se materializa como una ReservaEspacio normal.
"""

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TipoRecurrencia(str, enum.Enum):
    SEMANAL = "SEMANAL"
    QUINCENAL = "QUINCENAL"
    MENSUAL = "MENSUAL"


class EstadoReservaRecurrente(str, enum.Enum):
    PENDIENTE_APROBACION = "PENDIENTE_APROBACION"
    APROBADA = "APROBADA"
    RECHAZADA = "RECHAZADA"
    CANCELADA = "CANCELADA"


class ReservaRecurrente(Base):
    """
    Patrón de reserva periódica que el admin debe aprobar.
    Una vez aprobada, el scheduler genera instancias (ReservaEspacio)
    automáticamente según el tipo de recurrencia hasta fecha_fin_recurrencia.
    """
    __tablename__ = "reservas_recurrentes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    espacio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("espacios.id", ondelete="CASCADE"), nullable=False
    )
    tramo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tramos_horarios.id", ondelete="CASCADE"), nullable=False
    )
    tipo_recurrencia: Mapped[TipoRecurrencia] = mapped_column(
        Enum(TipoRecurrencia, name="tipo_recurrencia", create_type=False),
        nullable=False,
    )
    fecha_inicio: Mapped[date] = mapped_column(Date, nullable=False)
    fecha_fin_recurrencia: Mapped[date] = mapped_column(Date, nullable=False)
    estado: Mapped[EstadoReservaRecurrente] = mapped_column(
        Enum(EstadoReservaRecurrente, name="estado_reserva_recurrente", create_type=False),
        nullable=False,
        default=EstadoReservaRecurrente.PENDIENTE_APROBACION,
    )
    observaciones: Mapped[str | None] = mapped_column(Text)
    motivo_rechazo: Mapped[str | None] = mapped_column(Text)
    tokens_por_instancia: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # Fecha de la última instancia generada para este patrón
    ultima_instancia_generada: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    usuario = relationship("Usuario")
    espacio = relationship("Espacio")
    tramo = relationship("TramoHorario")
    instancias = relationship(
        "ReservaEspacio",
        back_populates="reserva_recurrente",
        foreign_keys="ReservaEspacio.reserva_recurrente_id",
    )

    def __repr__(self) -> str:
        return f"<ReservaRecurrente {self.id} - {self.tipo_recurrencia.value} - {self.estado.value}>"
