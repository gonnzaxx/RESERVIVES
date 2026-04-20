"""
Modelo de Tramo Horario.

Gestiona los tramos fijos del instituto y su configuración
por espacio y servicio.
"""

import uuid
from datetime import time

from sqlalchemy import Boolean, ForeignKey, Integer, String, Time, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TramoHorario(Base):
    """Modelo SQLAlchemy de la tabla tramos_horarios"""

    """
    Tramos horarios fijos del instituto.
    Se inicializan una vez en la base de datos y nunca cambian su hora.
    Son el catálogo global de slots disponibles.
    """
    __tablename__ = "tramos_horarios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str] = mapped_column(String(50), nullable=False)
    # "MAÑANA" | "TARDE"
    turno: Mapped[str] = mapped_column(String(10), nullable=False)
    # Número de orden dentro del turno (0=RECREO, 1..7)
    numero: Mapped[int] = mapped_column(Integer, nullable=False)
    hora_inicio: Mapped[time] = mapped_column(Time, nullable=False)
    hora_fin: Mapped[time] = mapped_column(Time, nullable=False)
    es_recreo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("turno", "numero", name="uq_tramo_turno_numero"),
    )

    def __repr__(self) -> str:
        return f"<TramoHorario {self.turno}-{self.nombre} {self.hora_inicio}-{self.hora_fin}>"


class EspacioTramoPermitido(Base):
    """Modelo SQLAlchemy de la tabla espacio_tramos_permitidos"""
    """
    Configura qué tramos permite cada espacio.
    - Sin registros para un espacio: todos los tramos están permitidos.
    - Con registros: solo esos tramos están permitidos.
    """
    __tablename__ = "espacio_tramos_permitidos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    espacio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("espacios.id", ondelete="CASCADE"), nullable=False
    )
    tramo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tramos_horarios.id", ondelete="CASCADE"), nullable=False
    )

    __table_args__ = (
        UniqueConstraint("espacio_id", "tramo_id", name="uq_espacio_tramo"),
    )

    espacio = relationship("Espacio", back_populates="tramos_permitidos")
    tramo = relationship("TramoHorario")


class ServicioTramoPermitido(Base):
    """
    Configura qué tramos permite cada servicio.
    Misma lógica que EspacioTramoPermitido.
    """
    __tablename__ = "servicio_tramos_permitidos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    servicio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("servicios.id", ondelete="CASCADE"), nullable=False
    )
    tramo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tramos_horarios.id", ondelete="CASCADE"), nullable=False
    )

    __table_args__ = (
        UniqueConstraint("servicio_id", "tramo_id", name="uq_servicio_tramo"),
    )

    servicio = relationship("Servicio", back_populates="tramos_permitidos")
    tramo = relationship("TramoHorario")