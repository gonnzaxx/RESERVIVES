"""
Modelo de Historial de Tokens.

Registro de las incidencias.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, String, Text, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class EstadoIncidencia(str, enum.Enum):
    PENDIENTE = "PENDIENTE"
    RESUELTA = "RESUELTA"
    DESCARTADA = "DESCARTADA"


class Incidencia(Base):
    __tablename__ = "incidencias"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    descripcion: Mapped[str] = mapped_column(Text, nullable=False)
    imagen_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    estado: Mapped[EstadoIncidencia] = mapped_column(
        Enum(EstadoIncidencia, name="estado_incidencia", create_type=False),
        nullable=False,
        default=EstadoIncidencia.PENDIENTE
    )
    comentario_admin: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    usuario = relationship("Usuario", back_populates="incidencias", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Incidencia {self.id} - {self.estado}>"
