"""
Modelo de Espacio.

Representa los espacios reservables del instituto (pistas deportivas y aulas).
También incluye la tabla intermedia de roles permitidos por espacio.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TipoEspacio(str, enum.Enum):
    """Tipos de espacio disponibles."""
    PISTA = "PISTA"
    AULA = "AULA"


class Espacio(Base):
    """Modelo SQLAlchemy para la tabla 'espacios'."""
    __tablename__ = "espacios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)
    imagen_url: Mapped[str | None] = mapped_column(String(500))
    tipo: Mapped[TipoEspacio] = mapped_column(
        Enum(TipoEspacio, name="tipo_espacio", create_type=False),
        nullable=False
    )
    precio_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reservable: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    requiere_autorizacion: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    antelacion_dias: Mapped[int] = mapped_column(Integer, nullable=False, default=7)
    ubicacion: Mapped[str | None] = mapped_column(String(200))
    capacidad: Mapped[int | None] = mapped_column(Integer)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    roles_permitidos = relationship(
        "EspacioRolPermitido", back_populates="espacio",
        lazy="selectin", cascade="all, delete-orphan"
    )
    reservas = relationship("ReservaEspacio", back_populates="espacio", lazy="selectin")
    tramos_permitidos = relationship(
        "EspacioTramoPermitido", back_populates="espacio",
        lazy="selectin", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Espacio {self.nombre} ({self.tipo.value})>"


class EspacioRolPermitido(Base):
    """Tabla intermedia: qué roles pueden reservar cada espacio."""
    __tablename__ = "espacio_rol_permitido"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    espacio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("espacios.id", ondelete="CASCADE"), nullable=False
    )
    rol: Mapped[str] = mapped_column(
        Enum("ALUMNO", "PROFESOR", "ADMIN", name="rol_usuario", create_type=False),
        nullable=False
    )

    # Relación inversa
    espacio = relationship("Espacio", back_populates="roles_permitidos")