"""
Modelos de Cafetería.

Representa la información y relación de las categorías y
los productos de la cafetería.
De momento la utilidad es únicamente informativas pero la estructura está
preparada para futuras funcionalidades de reserva.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CategoriaCafeteria(Base):
    """Modelo SQLAlchemy para la tabla 'categorias_cafeteria'."""
    __tablename__ = "categorias_cafeteria"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str] = mapped_column(String(100), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)
    imagen_url: Mapped[str | None] = mapped_column(String(500))
    orden: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    activa: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones
    productos = relationship(
        "ProductoCafeteria", back_populates="categoria",
        lazy="selectin", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<CategoriaCafeteria '{self.nombre}'>"


class ProductoCafeteria(Base):
    """Modelo SQLAlchemy para la tabla 'productos_cafeteria'."""
    __tablename__ = "productos_cafeteria"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    categoria_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("categorias_cafeteria.id", ondelete="CASCADE"), nullable=False
    )
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text)
    imagen_url: Mapped[str | None] = mapped_column(String(500))
    precio: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    disponible: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    destacado: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    orden: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relaciones
    categoria = relationship("CategoriaCafeteria", back_populates="productos")

    def __repr__(self) -> str:
        return f"<ProductoCafeteria '{self.nombre}' ({self.precio}€)>"