"""
Modelo de Encuesta.

Definición de modelos para el sistema de encuestas, gestión de opciones
y control de participación de usuarios mediante votos.
"""

import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Encuesta(Base):
    """Modelo SQLAlchemy para la tabla encuestas."""
    __tablename__ = "encuestas"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    titulo: Mapped[str] = mapped_column(String(500), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    fecha_fin: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    activa: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    opciones: Mapped[list["EncuestaOpcion"]] = relationship(
        "EncuestaOpcion", back_populates="encuesta", cascade="all, delete-orphan", order_by="EncuestaOpcion.orden"
    )
    votos: Mapped[list["VotoEncuesta"]] = relationship("VotoEncuesta", back_populates="encuesta", cascade="all, delete-orphan")


class EncuestaOpcion(Base):
    """Modelo SQLAlchemy para la tabla encuesta_opciones."""
    __tablename__ = "encuesta_opciones"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    encuesta_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("encuestas.id", ondelete="CASCADE"), nullable=False
    )

    texto: Mapped[str] = mapped_column(String(255), nullable=False)
    orden: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    encuesta: Mapped["Encuesta"] = relationship("Encuesta", back_populates="opciones")
    votos: Mapped[list["VotoEncuesta"]] = relationship("VotoEncuesta", back_populates="opcion")


class VotoEncuesta(Base):
    """Modelo SQLAlchemy para la tabla votos_encuesta."""
    __tablename__ = "votos_encuesta"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    encuesta_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("encuestas.id", ondelete="CASCADE"), nullable=False
    )
    opcion_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("encuesta_opciones.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    usuario: Mapped["Usuario"] = relationship("Usuario")
    encuesta: Mapped["Encuesta"] = relationship("Encuesta", back_populates="votos")
    opcion: Mapped["EncuestaOpcion"] = relationship("EncuestaOpcion", back_populates="votos")

    __table_args__ = (
        UniqueConstraint("usuario_id", "encuesta_id", name="uq_voto_usuario_encuesta"),
    )