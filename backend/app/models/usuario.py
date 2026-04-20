"""
Modelo de Usuario.
Esta clase representa a los usuarios registrados en la aplicacion.
La autenticación de estos se realiza mediante Microsoft EntraID.
El rol de cada usuario se determina automáticamente por el dominio del email:
  - @alumno.iesluisvives.org → ALUMNO
  - @profesor.iesluisvives.org → PROFESOR
  - @iesluisvives.org → ADMINISTRADOR
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RolUsuario(str, enum.Enum):
    """Definimos los roles disponibles en la aplicación."""
    ALUMNO = "ALUMNO"
    PROFESOR = "PROFESOR"
    ADMIN = "ADMIN"


class Usuario(Base):
    """Usamos SQLAlchemy para crear el modelo de la tabla usuarios."""
    __tablename__ = "usuarios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str] = mapped_column(String(100), nullable=False)
    apellidos: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    microsoft_id: Mapped[str | None] = mapped_column(String(255), unique=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    rol: Mapped[RolUsuario] = mapped_column(
        Enum(RolUsuario, name="rol_usuario", create_type=False),
        nullable=False,
        default=RolUsuario.ALUMNO
    )
    tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    reservas = relationship("Reserva", back_populates="usuario", lazy="selectin")
    anuncios = relationship("Anuncio", back_populates="autor", lazy="selectin")
    historial_tokens = relationship("HistorialTokens", back_populates="usuario", lazy="selectin")
    reservas_servicios = relationship("ReservaServicio", back_populates="usuario", lazy="selectin")
    notificaciones = relationship("Notificacion", back_populates="usuario", lazy="noload")
    dispositivos_push = relationship("DispositivoPush", back_populates="usuario", lazy="noload")
    preferencias_notificacion = relationship(
        "PreferenciasNotificacion",
        back_populates="usuario",
        uselist=False,
        lazy="noload",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Usuario {self.nombre} {self.apellidos} ({self.rol.value})>"
