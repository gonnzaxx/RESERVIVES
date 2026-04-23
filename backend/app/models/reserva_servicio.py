"""
Modelo de Reserva de Servicio.

Gestiona la relación de las reservas de los servicios.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.reserva_espacio import EstadoReserva


class ReservaServicio(Base):
    """Modelo SQLAlchemy para la tabla 'reservas_servicios'."""
    __tablename__ = "reservas_servicios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    servicio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("servicios.id", ondelete="CASCADE"), nullable=False
    )
    fecha_inicio: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    fecha_fin: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    observaciones: Mapped[str | None] = mapped_column(Text)
    estado: Mapped[EstadoReserva] = mapped_column(
        Enum(EstadoReserva, name="estado_reserva", create_type=False),
        nullable=False,
        default=EstadoReserva.PENDIENTE
    )
    tokens_consumidos: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # Tramo horario asignado (nullable para compatibilidad con reservas antiguas)
    tramo_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tramos_horarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    usuario = relationship("Usuario", back_populates="reservas_servicios")
    servicio = relationship("Servicio", back_populates="reservas")
    tramo = relationship("TramoHorario", foreign_keys=[tramo_id])

    def __repr__(self) -> str:
        return f"<ReservaServicio {self.id} - {self.estado.value}>"
