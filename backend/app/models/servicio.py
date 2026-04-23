"""
Modelo de Servicio del Instituto.

Gestiona la información de los servicios ofrecidos por el centro.
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Servicio(Base):
    """Modelo SQLAlchemy para la tabla 'servicios'."""
    __tablename__ = "servicios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)
    imagen_url: Mapped[str | None] = mapped_column(String(500))
    ubicacion: Mapped[str | None] = mapped_column(String(200))
    horario: Mapped[str | None] = mapped_column(String(300))
    precio_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    antelacion_dias: Mapped[int] = mapped_column(Integer, nullable=False, default=7)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    orden: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    reservas = relationship("ReservaServicio", back_populates="servicio", lazy="selectin", cascade="all, delete-orphan", passive_deletes=True)
    tramos_permitidos = relationship(
        "ServicioTramoPermitido", back_populates="servicio",
        lazy="selectin", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Servicio '{self.nombre}'>"
