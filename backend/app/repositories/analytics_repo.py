"""Clase Anallytics Repository

Gestiona las métricas de datos en relacion a los espacios,
servicios y anuncios.
"""

import uuid
from sqlalchemy import select, func, desc
from app.models.reserva_espacio import ReservaEspacio, EstadoReserva
from app.models.espacio import Espacio, TipoEspacio
from app.models.servicio import Servicio
from app.models.reserva_servicio import ReservaServicio
from app.models.anuncio import Anuncio, AnuncioVisualizacion

class AnalyticsRepository:
    def __init__(self, db):
        self.db = db

    async def get_espacios_kpis(self, tipo: TipoEspacio):
        """Métricas de reservas por espacio (aula o pista)."""
        result = await self.db.execute(
            select(
                Espacio.nombre,
                func.count(ReservaEspacio.id).label("total_reservas")
            )
            .join(ReservaEspacio, ReservaEspacio.espacio_id == Espacio.id)
            .where(Espacio.tipo == tipo, ReservaEspacio.estado == EstadoReserva.APROBADA)
            .group_by(Espacio.id)
            .order_by(desc("total_reservas"))
        )
        return [{"nombre": row[0], "valor": row[1]} for row in result.all()]

    async def get_servicios_kpis(self):
        """Métricas de uso de servicios."""
        result = await self.db.execute(
            select(
                Servicio.nombre,
                func.count(ReservaServicio.id).label("total_usos")
            )
            .join(ReservaServicio, ReservaServicio.servicio_id == Servicio.id)
            .where(ReservaServicio.estado == EstadoReserva.APROBADA)
            .group_by(Servicio.id)
            .order_by(desc("total_usos"))
        )
        return [{"nombre": row[0], "valor": row[1]} for row in result.all()]

    async def get_anuncios_kpis(self):
        """Métricas de visualizaciones por anuncio (Top 10)."""
        result = await self.db.execute(
            select(
                Anuncio.titulo,
                func.count(AnuncioVisualizacion.id).label("vistas")
            )
            .join(AnuncioVisualizacion, AnuncioVisualizacion.anuncio_id == Anuncio.id)
            .group_by(Anuncio.id)
            .order_by(desc("vistas"))
            .limit(10)
        )
        return [{"nombre": row[0], "valor": row[1]} for row in result.all()]

    async def register_view(self, anuncio_id: uuid.UUID, usuario_id: uuid.UUID = None):
        view = AnuncioVisualizacion(anuncio_id=anuncio_id, usuario_id=usuario_id)
        self.db.add(view)
        await self.db.flush()