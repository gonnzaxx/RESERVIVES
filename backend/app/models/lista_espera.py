"""
RESERVIVES - Modelo de Lista de Espera.

Permite a los usuarios apuntarse a un tramo ocupado.
Cuando se libera (cancelación de reserva), el siguiente en la cola
recibe una notificación push/in-app para reservar.
"""

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class EstadoListaEspera(str, enum.Enum):
    ACTIVA = "ACTIVA"
    NOTIFICADA = "NOTIFICADA"    # Se notificó al usuario, tiene tiempo para reservar
    RESERVADA = "RESERVADA"      # El usuario realizó la reserva
    EXPIRADA = "EXPIRADA"        # La ventana de notificación expiró sin acción
    CANCELADA = "CANCELADA"      # El usuario abandonó la lista


class ListaEspera(Base):
    """
    Entrada en la lista de espera para un espacio, fecha y tramo concretos.
    La posición determina el orden de notificación cuando se libera un slot.
    """
    __tablename__ = "lista_espera"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False
    )
    espacio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("espacios.id", ondelete="CASCADE"), nullable=False
    )
    tramo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tramos_horarios.id", ondelete="CASCADE"), nullable=False
    )
    fecha: Mapped[date] = mapped_column(Date, nullable=False)
    posicion: Mapped[int] = mapped_column(Integer, nullable=False)
    estado: Mapped[EstadoListaEspera] = mapped_column(
        Enum(EstadoListaEspera, name="estado_lista_espera", create_type=False),
        nullable=False,
        default=EstadoListaEspera.ACTIVA,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    usuario = relationship("Usuario")
    espacio = relationship("Espacio")
    tramo = relationship("TramoHorario")

    def __repr__(self) -> str:
        return f"<ListaEspera pos={self.posicion} {self.espacio_id} {self.fecha}>"
