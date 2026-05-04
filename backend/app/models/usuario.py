"""
Modelo de Usuario.

Gestiona la información y los tipos de usuarios.
Para la autenticación se utiliza Microsoft EntraID
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RolUsuario(str, enum.Enum):
    """Roles disponibles en la aplicación."""
    ALUMNO = "ALUMNO"
    PROFESOR = "PROFESOR"
    ADMIN = "ADMIN"
    CAFETERIA = "CAFETERIA"
    JEFE_ESTUDIOS = "JEFE_ESTUDIOS"
    SECRETARIA = "SECRETARIA"
    PROFESOR_SERVICIO = "PROFESOR_SERVICIO"


class Usuario(Base):
    """Modelo SQLAlchemy para la tabla 'usuarios'."""
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
    rol_override: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
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
    reservas = relationship("ReservaEspacio", back_populates="usuario", lazy="selectin")
    anuncios = relationship("Anuncio", back_populates="autor", lazy="selectin")
    historial_tokens = relationship("HistorialTokens", back_populates="usuario", lazy="selectin")
    reservas_servicios = relationship("ReservaServicio", back_populates="usuario", lazy="selectin")
    notificaciones = relationship("Notificacion", back_populates="usuario", lazy="noload")
    dispositivos_push = relationship("DispositivoPush", back_populates="usuario", lazy="noload")
    incidencias = relationship("Incidencia", back_populates="usuario", lazy="noload")
    preferencias_notificacion = relationship(
        "PreferenciasNotificacion",
        back_populates="usuario",
        uselist=False,
        lazy="noload",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Usuario {self.nombre} {self.apellidos} ({self.rol.value})>"
