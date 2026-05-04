"""
Modelo de Notificaciones.

Gestiona la informacion de las notificaciones dentro de la app (IN-APP),
preferencias de usuario, historial de entregas, tipos y estados y el
registro de tokens push.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TipoNotificacion(str, enum.Enum):
    RESERVA_APROBADA = "RESERVA_APROBADA"
    RESERVA_RECHAZADA = "RESERVA_RECHAZADA"
    NUEVO_ESPACIO = "NUEVO_ESPACIO"
    NUEVO_SERVICIO = "NUEVO_SERVICIO"
    NUEVO_ANUNCIO = "NUEVO_ANUNCIO"
    NUEVA_RESERVA_PENDIENTE = "NUEVA_RESERVA_PENDIENTE"
    RESERVA_CANCELADA = "RESERVA_CANCELADA"
    RECARGA_TOKENS = "RECARGA_TOKENS"
    NUEVA_ENCUESTA = "NUEVA_ENCUESTA"
    NUEVA_INCIDENCIA = "NUEVA_INCIDENCIA"
    INCIDENCIA_RESUELTA = "INCIDENCIA_RESUELTA"
    # Reservas recurrentes
    RESERVA_RECURRENTE_APROBADA = "RESERVA_RECURRENTE_APROBADA"
    RESERVA_RECURRENTE_RECHAZADA = "RESERVA_RECURRENTE_RECHAZADA"
    NUEVA_RESERVA_RECURRENTE_PENDIENTE = "NUEVA_RESERVA_RECURRENTE_PENDIENTE"
    # Lista de espera
    LISTA_ESPERA_DISPONIBLE = "LISTA_ESPERA_DISPONIBLE"


class CanalNotificacion(str, enum.Enum):
    IN_APP = "IN_APP"
    EMAIL = "EMAIL"
    PUSH = "PUSH"


class EstadoEntregaNotificacion(str, enum.Enum):
    ENVIADA = "ENVIADA"
    FALLIDA = "FALLIDA"
    LEIDA = "LEIDA"


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    tipo: Mapped[TipoNotificacion] = mapped_column(
        Enum(TipoNotificacion, name="tipo_notificacion", create_type=False),
        nullable=False,
    )
    titulo: Mapped[str] = mapped_column(String(180), nullable=False)
    mensaje: Mapped[str] = mapped_column(Text, nullable=False)
    leida: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    referencia_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    usuario = relationship("Usuario", back_populates="notificaciones")
    entregas = relationship(
        "NotificacionEntrega",
        back_populates="notificacion",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class PreferenciasNotificacion(Base):
    __tablename__ = "preferencias_notificacion"

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        primary_key=True,
    )
    reserva_aprobada: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    reserva_rechazada: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    nuevo_espacio: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    nuevo_servicio: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    nuevo_anuncio: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    email_reservas: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    email_anuncios: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    usuario = relationship("Usuario", back_populates="preferencias_notificacion")


class NotificacionEntrega(Base):
    __tablename__ = "notificacion_entregas"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    notificacion_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("notificaciones.id", ondelete="CASCADE"),
        nullable=False,
    )
    canal: Mapped[CanalNotificacion] = mapped_column(
        Enum(CanalNotificacion, name="canal_notificacion", create_type=False),
        nullable=False,
    )
    estado: Mapped[EstadoEntregaNotificacion] = mapped_column(
        Enum(
            EstadoEntregaNotificacion,
            name="estado_entrega_notificacion",
            create_type=False,
        ),
        nullable=False,
        default=EstadoEntregaNotificacion.ENVIADA,
    )
    detalle: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    notificacion = relationship("Notificacion", back_populates="entregas")


class DispositivoPush(Base):
    __tablename__ = "dispositivos_push"
    __table_args__ = (
        UniqueConstraint("usuario_id", "token", name="uq_dispositivo_push_usuario_token"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    plataforma: Mapped[str] = mapped_column(String(32), nullable=False, default="unknown")
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    usuario = relationship("Usuario", back_populates="dispositivos_push")