"""
Modelo de Historial de Tokens.

Registro de todos los movimientos de tokens:
recargas mensuales, consumos por reservas, ajustes
del admin y devoluciones por cancelación de reservas.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TipoMovimientoToken(str, enum.Enum):
    """Tipos de movimiento de tokens."""
    RECARGA_MENSUAL = "RECARGA_MENSUAL"
    CONSUMO_RESERVA = "CONSUMO_RESERVA"
    AJUSTE_ADMIN = "AJUSTE_ADMIN"
    DEVOLUCION = "DEVOLUCION"


class HistorialTokens(Base):
    """Modelo SQLAlchemy para la tabla 'historial_tokens'."""
    __tablename__ = "historial_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    cantidad: Mapped[int] = mapped_column(Integer, nullable=False)
    tipo: Mapped[TipoMovimientoToken] = mapped_column(
        Enum(TipoMovimientoToken, name="tipo_movimiento_token", create_type=False),
        nullable=False
    )
    motivo: Mapped[str | None] = mapped_column(String(300))
    reserva_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reservas_espacios.id", ondelete="SET NULL")
    )
    reserva_servicio_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("reservas_servicios.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones
    usuario = relationship("Usuario", back_populates="historial_tokens")

    def __repr__(self) -> str:
        return f"<HistorialTokens {self.tipo.value}: {self.cantidad}>"
