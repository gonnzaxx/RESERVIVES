"""
RESERVIVES - Servicio de Tramos Horarios.

Lógica de negocio para consultar tramos y calcular disponibilidad
por espacio o servicio en un día concreto.
"""

from datetime import date, datetime, time as time_type, timezone
from uuid import UUID

from sqlalchemy import select, and_, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.reserva_espacio import ReservaEspacio, EstadoReserva
from app.models.reserva_servicio import ReservaServicio
from app.models.tramo_horario import TramoHorario, EspacioTramoPermitido, ServicioTramoPermitido
from app.schemas.tramo import TramoHorarioResponse, TramoDisponibilidadResponse
from app.utils.datetime_utils import combine_local_date_time


class TramoService:
    """Servicio para la gestión de tramos horarios y su disponibilidad."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_todos_los_tramos(self) -> list[TramoHorario]:
        """Devuelve todos los tramos activos ordenados por turno y número."""
        result = await self.db.execute(
            select(TramoHorario)
            .where(TramoHorario.activo == True)  # noqa: E712
            .order_by(TramoHorario.turno.desc(), TramoHorario.numero)
        )
        return list(result.scalars().all())

    async def get_tramo_by_id(self, tramo_id: UUID) -> TramoHorario | None:
        """Obtiene un tramo por su ID."""
        result = await self.db.execute(
            select(TramoHorario).where(TramoHorario.id == tramo_id)
        )
        return result.scalar_one_or_none()
        
    async def get_todos_los_tramos_admin(self) -> list[TramoHorario]:
        """Devuelve TODOS los tramos (activos e inactivos) para el backoffice."""
        result = await self.db.execute(
            select(TramoHorario).order_by(TramoHorario.turno.desc(), TramoHorario.numero)
        )
        return list(result.scalars().all())

    async def crear_tramo(self, datos: dict) -> TramoHorario:
        """Crea un nuevo tramo horario. Lanza ValueError si turno+numero ya existe."""
        from sqlalchemy.exc import IntegrityError
        tramo = TramoHorario(**datos)
        self.db.add(tramo)
        try:
            await self.db.flush()
        except IntegrityError:
            await self.db.rollback()
            raise ValueError(f"Ya existe un tramo con turno '{datos['turno']}' y número {datos['numero']}")
        await self.db.commit()
        await self.db.refresh(tramo)
        return tramo

    async def actualizar_tramo(self, tramo_id: UUID, datos: dict) -> TramoHorario:
        """Actualiza los campos indicados de un tramo. Lanza ValueError si no existe."""
        tramo = await self.get_tramo_by_id(tramo_id)
        if not tramo:
            raise ValueError("Tramo no encontrado")
        for campo, valor in datos.items():
            setattr(tramo, campo, valor)
        await self.db.commit()
        await self.db.refresh(tramo)
        return tramo

    async def eliminar_tramo(self, tramo_id: UUID) -> None:
        """Elimina físicamente el tramo horario."""
        tramo = await self.get_tramo_by_id(tramo_id)
        if not tramo:
            raise ValueError("Tramo no encontrado")
        await self.db.delete(tramo)
        await self.db.commit()

    async def get_disponibilidad_espacio(
        self, espacio_id: UUID, fecha: date
    ) -> list[TramoDisponibilidadResponse]:
        """
        Devuelve todos los tramos activos con su estado de disponibilidad
        para un espacio y fecha dados.
        """
        tramos = await self.get_todos_los_tramos()

        # Tramos permitidos para este espacio
        result = await self.db.execute(
            select(EspacioTramoPermitido.tramo_id)
            .where(EspacioTramoPermitido.espacio_id == espacio_id)
        )
        tramos_permitidos_ids = set(result.scalars().all())
        # Sin registros → todos están permitidos
        todos_permitidos = len(tramos_permitidos_ids) == 0

        # Tramos ocupados ese día (reservas PENDIENTE o APROBADA)
        inicio_dia = combine_local_date_time(fecha, time_type(0, 0)).astimezone(timezone.utc)
        fin_dia = combine_local_date_time(fecha, time_type(23, 59, 59)).astimezone(timezone.utc)
        result = await self.db.execute(
            select(ReservaEspacio.tramo_id).where(
                and_(
                    ReservaEspacio.espacio_id == espacio_id,
                    ReservaEspacio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                    ReservaEspacio.tramo_id.isnot(None),
                    ReservaEspacio.fecha_inicio >= inicio_dia,
                    ReservaEspacio.fecha_inicio < fin_dia,
                )
            )
        )
        tramos_ocupados_ids = set(result.scalars().all())

        return self._build_response(tramos, tramos_permitidos_ids, tramos_ocupados_ids, todos_permitidos, fecha)

    async def get_disponibilidad_servicio(
        self, servicio_id: UUID, fecha: date
    ) -> list[TramoDisponibilidadResponse]:
        """
        Devuelve todos los tramos activos con su estado de disponibilidad
        para un servicio y fecha dados.
        """
        tramos = await self.get_todos_los_tramos()

        result = await self.db.execute(
            select(ServicioTramoPermitido.tramo_id)
            .where(ServicioTramoPermitido.servicio_id == servicio_id)
        )
        tramos_permitidos_ids = set(result.scalars().all())
        todos_permitidos = len(tramos_permitidos_ids) == 0

        inicio_dia = combine_local_date_time(fecha, time_type(0, 0)).astimezone(timezone.utc)
        fin_dia = combine_local_date_time(fecha, time_type(23, 59, 59)).astimezone(timezone.utc)
        result = await self.db.execute(
            select(ReservaServicio.tramo_id).where(
                and_(
                    ReservaServicio.servicio_id == servicio_id,
                    ReservaServicio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                    ReservaServicio.tramo_id.isnot(None),
                    ReservaServicio.fecha_inicio >= inicio_dia,
                    ReservaServicio.fecha_inicio < fin_dia,
                )
            )
        )
        tramos_ocupados_ids = set(result.scalars().all())

        return self._build_response(tramos, tramos_permitidos_ids, tramos_ocupados_ids, todos_permitidos, fecha)

    @staticmethod
    def _build_response(
        tramos: list[TramoHorario],
        permitidos_ids: set,
        ocupados_ids: set,
        todos_permitidos: bool,
        fecha: date
    ) -> list[TramoDisponibilidadResponse]:
        from zoneinfo import ZoneInfo
        from app.utils.datetime_utils import DEFAULT_APP_TIMEZONE
        
        resultado = []
        tz = ZoneInfo(DEFAULT_APP_TIMEZONE)
        ahora_local = datetime.now(tz)
        
        for tramo in tramos:
            permitido = todos_permitidos or (tramo.id in permitidos_ids)
            reservado = tramo.id in ocupados_ids
            
            # Verificar si el tramo es pasado usando la zona horaria del instituto
            es_pasado = False
            if fecha < ahora_local.date():
                es_pasado = True
            elif fecha == ahora_local.date():
                inicio_tramo = datetime.combine(fecha, tramo.hora_inicio).replace(tzinfo=tz)
                if inicio_tramo < ahora_local:
                    es_pasado = True

            disponible = permitido and not reservado and not es_pasado

            mensaje = None
            if reservado:
                mensaje = "Ya reservado"
            elif not permitido:
                mensaje = "No permitido para este recurso"
            elif es_pasado:
                mensaje = "Horario pasado"

            resultado.append(TramoDisponibilidadResponse(
                tramo=TramoHorarioResponse.model_validate(tramo),
                disponible=disponible,
                permitido=permitido,
                reservado=reservado,
                mensaje=mensaje,
            ))
        return resultado

    async def configurar_tramos_espacio(self, espacio_id: UUID, tramo_ids: list[UUID]) -> None:
        """Reemplaza la configuración de tramos permitidos para un espacio."""
        await self.db.execute(
            delete(EspacioTramoPermitido).where(
                EspacioTramoPermitido.espacio_id == espacio_id
            )
        )
        for tramo_id in tramo_ids:
            self.db.add(EspacioTramoPermitido(espacio_id=espacio_id, tramo_id=tramo_id))
        await self.db.flush()

    async def configurar_tramos_servicio(self, servicio_id: UUID, tramo_ids: list[UUID]) -> None:
        """Reemplaza la configuración de tramos permitidos para un servicio."""
        await self.db.execute(
            delete(ServicioTramoPermitido).where(
                ServicioTramoPermitido.servicio_id == servicio_id
            )
        )
        for tramo_id in tramo_ids:
            self.db.add(ServicioTramoPermitido(servicio_id=servicio_id, tramo_id=tramo_id))
        await self.db.flush()

    async def get_tramos_permitidos_espacio(self, espacio_id: UUID) -> list[UUID]:
        """Devuelve los IDs de tramos permitidos para un espacio (vacío = todos)."""
        result = await self.db.execute(
            select(EspacioTramoPermitido.tramo_id)
            .where(EspacioTramoPermitido.espacio_id == espacio_id)
        )
        return list(result.scalars().all())

    async def get_tramos_permitidos_servicio(self, servicio_id: UUID) -> list[UUID]:
        """Devuelve los IDs de tramos permitidos para un servicio (vacío = todos)."""
        result = await self.db.execute(
            select(ServicioTramoPermitido.tramo_id)
            .where(ServicioTramoPermitido.servicio_id == servicio_id)
        )
        return list(result.scalars().all())
