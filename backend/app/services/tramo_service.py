"""
RESERVIVES - Servicio de Tramos Horarios.

Lógica de negocio para consultar tramos y calcular disponibilidad
por espacio o servicio en un día concreto.
"""

from datetime import date, datetime, time as time_type, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import and_, delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.reserva_espacio import EstadoReserva, ReservaEspacio
from app.models.reserva_servicio import ReservaServicio
from app.models.tramo_horario import EspacioTramoPermitido, ServicioTramoPermitido, TramoHorario
from app.schemas.tramo import TramoDisponibilidadResponse, TramoHorarioResponse
from app.utils.datetime_utils import DEFAULT_APP_TIMEZONE, combine_local_date_time


class TramoService:
    """Servicio para la gestión de tramos horarios y su disponibilidad."""

    def __init__(self, db: AsyncSession):
        self.db = db

    # Devuelve todos los tramos activos ordenados por turno y número
    async def get_todos_los_tramos(self) -> list[TramoHorario]:
        result = await self.db.execute(
            select(TramoHorario)
            .where(TramoHorario.activo == True)  # noqa: E712
            .order_by(TramoHorario.turno.desc(), TramoHorario.numero)
        )
        return list(result.scalars().all())

    # Busca un tramo por su UUID; devuelve None si no existe
    async def get_tramo_by_id(self, tramo_id: UUID) -> TramoHorario | None:
        result = await self.db.execute(
            select(TramoHorario).where(TramoHorario.id == tramo_id)
        )
        return result.scalar_one_or_none()
        
    # Devuelve todos los tramos incluidos los inactivos (para el backoffice)
    async def get_todos_los_tramos_admin(self) -> list[TramoHorario]:
        result = await self.db.execute(
            select(TramoHorario).order_by(TramoHorario.turno.desc(), TramoHorario.numero)
        )
        return list(result.scalars().all())

    # Crea un nuevo tramo horario. Lanza ValueError si la combinación turno+numero ya existe.
    async def crear_tramo(self, datos: dict) -> TramoHorario:
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

    # Actualiza los campos indicados de un tramo existente. Lanza ValueError si no existe.
    async def actualizar_tramo(self, tramo_id: UUID, datos: dict) -> TramoHorario:
        tramo = await self.get_tramo_by_id(tramo_id)
        if not tramo:
            raise ValueError("Tramo no encontrado")
        for campo, valor in datos.items():
            setattr(tramo, campo, valor)
        await self.db.commit()
        await self.db.refresh(tramo)
        return tramo

    # Elimina físicamente el tramo horario de la base de datos
    async def eliminar_tramo(self, tramo_id: UUID) -> None:
        tramo = await self.get_tramo_by_id(tramo_id)
        if not tramo:
            raise ValueError("Tramo no encontrado")
        await self.db.delete(tramo)
        await self.db.commit()

    # Devuelve la disponibilidad de todos los tramos activos para un espacio y fecha concretos
    async def get_disponibilidad_espacio(
        self, espacio_id: UUID, fecha: date, usuario_id: UUID | None = None
    ) -> list[TramoDisponibilidadResponse]:
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

        tramos_propios_ids: set = set()
        if usuario_id:
            result = await self.db.execute(
                select(ReservaEspacio.tramo_id).where(
                    and_(
                        ReservaEspacio.espacio_id == espacio_id,
                        ReservaEspacio.usuario_id == usuario_id,
                        ReservaEspacio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                        ReservaEspacio.tramo_id.isnot(None),
                        ReservaEspacio.fecha_inicio >= inicio_dia,
                        ReservaEspacio.fecha_inicio < fin_dia,
                    )
                )
            )
            tramos_propios_ids = set(result.scalars().all())

        return self._build_response(tramos, tramos_permitidos_ids, tramos_ocupados_ids, todos_permitidos, fecha, tramos_propios_ids)

    # Devuelve la disponibilidad de todos los tramos activos para un servicio y fecha concretos
    async def get_disponibilidad_servicio(
        self, servicio_id: UUID, fecha: date, usuario_id: UUID | None = None
    ) -> list[TramoDisponibilidadResponse]:
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

        tramos_propios_ids: set = set()
        if usuario_id:
            result = await self.db.execute(
                select(ReservaServicio.tramo_id).where(
                    and_(
                        ReservaServicio.servicio_id == servicio_id,
                        ReservaServicio.usuario_id == usuario_id,
                        ReservaServicio.estado.in_([EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]),
                        ReservaServicio.tramo_id.isnot(None),
                        ReservaServicio.fecha_inicio >= inicio_dia,
                        ReservaServicio.fecha_inicio < fin_dia,
                    )
                )
            )
            tramos_propios_ids = set(result.scalars().all())

        return self._build_response(tramos, tramos_permitidos_ids, tramos_ocupados_ids, todos_permitidos, fecha, tramos_propios_ids)

    # Construye la lista de disponibilidad cruzando tramos con ocupados y permitidos.
    # Marca cada tramo como disponible, reservado, no permitido o pasado.
    @staticmethod
    def _build_response(
        tramos: list[TramoHorario],
        permitidos_ids: set,
        ocupados_ids: set,
        todos_permitidos: bool,
        fecha: date,
        propios_ids: set | None = None,
    ) -> list[TramoDisponibilidadResponse]:
        resultado = []
        tz = ZoneInfo(DEFAULT_APP_TIMEZONE)
        ahora_local = datetime.now(tz)
        
        for tramo in tramos:
            permitido = todos_permitidos or (tramo.id in permitidos_ids)
            reservado = tramo.id in ocupados_ids
            reservado_por_mi = propios_ids is not None and tramo.id in propios_ids
            
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
                reservado_por_mi=reservado_por_mi,
                mensaje=mensaje,
            ))
        return resultado

    # Reemplaza los tramos permitidos de un espacio (borra los anteriores y añade los nuevos)
    async def configurar_tramos_espacio(self, espacio_id: UUID, tramo_ids: list[UUID]) -> None:
        await self.db.execute(
            delete(EspacioTramoPermitido).where(
                EspacioTramoPermitido.espacio_id == espacio_id
            )
        )
        for tramo_id in tramo_ids:
            self.db.add(EspacioTramoPermitido(espacio_id=espacio_id, tramo_id=tramo_id))
        await self.db.flush()

    # Reemplaza los tramos permitidos de un servicio (borra los anteriores y añade los nuevos)
    async def configurar_tramos_servicio(self, servicio_id: UUID, tramo_ids: list[UUID]) -> None:
        await self.db.execute(
            delete(ServicioTramoPermitido).where(
                ServicioTramoPermitido.servicio_id == servicio_id
            )
        )
        for tramo_id in tramo_ids:
            self.db.add(ServicioTramoPermitido(servicio_id=servicio_id, tramo_id=tramo_id))
        await self.db.flush()

    # IDs de tramos permitidos para un espacio; lista vacía significa que todos están permitidos
    async def get_tramos_permitidos_espacio(self, espacio_id: UUID) -> list[UUID]:
        result = await self.db.execute(
            select(EspacioTramoPermitido.tramo_id)
            .where(EspacioTramoPermitido.espacio_id == espacio_id)
        )
        return list(result.scalars().all())

    # IDs de tramos permitidos para un servicio; lista vacía significa que todos están permitidos
    async def get_tramos_permitidos_servicio(self, servicio_id: UUID) -> list[UUID]:
        result = await self.db.execute(
            select(ServicioTramoPermitido.tramo_id)
            .where(ServicioTramoPermitido.servicio_id == servicio_id)
        )
        return list(result.scalars().all())
