"""
RESERVIVES - Servicio de Reservas Recurrentes.

Gestiona la creación, aprobación, rechazo y generación de instancias
de reservas periódicas. El flujo es:
  1. Usuario solicita una reserva recurrente → estado PENDIENTE_APROBACION
  2. Admin aprueba → estado APROBADA, se genera la primera instancia
  3. Scheduler diario genera las siguientes instancias hasta fecha_fin
"""

import uuid
from datetime import date, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.historial_tokens import HistorialTokens, TipoMovimientoToken
from app.models.reserva_espacio import EstadoReserva, ReservaEspacio
from app.models.reserva_recurrente import (
    EstadoReservaRecurrente,
    ReservaRecurrente,
    TipoRecurrencia,
)
from app.models.usuario import RolUsuario, Usuario
from app.repositories.espacio_repo import EspacioRepository
from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
from app.repositories.reserva_recurrente_repo import ReservaRecurrenteRepository
from app.schemas.reserva import DuracionPlan, ReservaRecurrenteCreate
from app.utils.datetime_utils import local_slot_to_utc_range
from app.utils.exceptions import (
    ConflictException,
    ForbiddenException,
    InsufficientTokensException,
    NotFoundException,
    ValidationException,
)
from app.utils.logging import get_logger
from app.utils.role_access import (
    BackofficeSection,
    MAX_USER_TOKENS,
    can_access_backoffice_section,
    uses_tokens,
)

_DIAS_ANTICIPACION_INSTANCIAS = 30  # Cuántos días adelante generar instancias


class ReservaRecurrenteService:

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = ReservaRecurrenteRepository(session)
        self.reserva_repo = ReservaEspacioRepository(session)
        self.espacio_repo = EspacioRepository(session)
        self.logger = get_logger("app.services.reserva_recurrente")

    async def crear_reserva_recurrente(
        self, usuario: Usuario, data: ReservaRecurrenteCreate
    ) -> ReservaRecurrente:
        """Crea una solicitud de reserva recurrente pendiente de aprobación admin."""
        if usuario.rol == RolUsuario.ALUMNO:
            raise ForbiddenException(
                "Los alumnos no pueden solicitar reservas recurrentes"
            )

        fecha_fin_recurrencia = data.fecha_fin_recurrencia
        tipo_recurrencia = data.tipo_recurrencia
        if data.duracion_plan is not None:
            tipo_recurrencia = TipoRecurrencia.SEMANAL
            fecha_fin_recurrencia = self._compute_end_date_from_plan(
                data.fecha_inicio,
                data.duracion_plan,
            )

        if fecha_fin_recurrencia is None:
            raise ValidationException("Debes indicar fecha fin o duración del plan")
        if data.fecha_inicio >= fecha_fin_recurrencia:
            raise ValidationException(
                "La fecha de inicio debe ser anterior a la de fin de recurrencia"
            )
        if data.fecha_inicio < date.today():
            raise ValidationException("La fecha de inicio no puede ser en el pasado")
        if data.fecha_inicio.weekday() >= 5:
            raise ValidationException("La fecha de inicio no puede ser en fin de semana")

        espacio = await self.espacio_repo.get_by_id_with_roles(data.espacio_id)
        if not espacio or not espacio.reservable or not espacio.activo:
            raise NotFoundException("Espacio", str(data.espacio_id))

        from app.services.tramo_service import TramoService
        tramo_svc = TramoService(self.session)
        tramo = await tramo_svc.get_tramo_by_id(data.tramo_id)
        if not tramo or not tramo.activo:
            raise ValidationException("El tramo horario seleccionado no es válido")

        tokens_por_instancia = espacio.precio_tokens if uses_tokens(usuario.rol) else 0

        reserva_rec = ReservaRecurrente(
            usuario_id=usuario.id,
            espacio_id=data.espacio_id,
            tramo_id=data.tramo_id,
            tipo_recurrencia=tipo_recurrencia,
            fecha_inicio=data.fecha_inicio,
            fecha_fin_recurrencia=fecha_fin_recurrencia,
            estado=EstadoReservaRecurrente.PENDIENTE_APROBACION,
            observaciones=data.observaciones,
            tokens_por_instancia=tokens_por_instancia,
        )
        reserva_rec = await self.repo.create(reserva_rec)
        return reserva_rec

    @staticmethod
    def _compute_end_date_from_plan(fecha_inicio: date, plan: DuracionPlan) -> date:
        if plan == DuracionPlan.DIAS_15:
            return fecha_inicio + timedelta(days=15)
        if plan == DuracionPlan.MES_1:
            return fecha_inicio + timedelta(days=30)
        return fecha_inicio + timedelta(days=90)

    async def aprobar_reserva_recurrente(
        self, reserva_recurrente_id: uuid.UUID, admin: Usuario
    ) -> ReservaRecurrente:
        """Admin aprueba el patrón y se generan las primeras instancias."""
        if not can_access_backoffice_section(admin.rol, BackofficeSection.BOOKINGS):
            raise ForbiddenException("No tienes permisos para aprobar reservas recurrentes")

        reserva_rec = await self.repo.get_by_id(reserva_recurrente_id)
        if not reserva_rec:
            raise NotFoundException("ReservaRecurrente", str(reserva_recurrente_id))
        if reserva_rec.estado != EstadoReservaRecurrente.PENDIENTE_APROBACION:
            raise ValidationException("Solo se pueden aprobar solicitudes pendientes")

        reserva_rec.estado = EstadoReservaRecurrente.APROBADA
        await self.session.flush()

        await self._generar_instancias(reserva_rec)
        return reserva_rec

    async def rechazar_reserva_recurrente(
        self, reserva_recurrente_id: uuid.UUID, admin: Usuario, motivo: str | None = None
    ) -> ReservaRecurrente:
        """Admin rechaza el patrón."""
        if not can_access_backoffice_section(admin.rol, BackofficeSection.BOOKINGS):
            raise ForbiddenException("No tienes permisos para rechazar reservas recurrentes")

        reserva_rec = await self.repo.get_by_id(reserva_recurrente_id)
        if not reserva_rec:
            raise NotFoundException("ReservaRecurrente", str(reserva_recurrente_id))
        if reserva_rec.estado != EstadoReservaRecurrente.PENDIENTE_APROBACION:
            raise ValidationException("Solo se pueden rechazar solicitudes pendientes")

        reserva_rec.estado = EstadoReservaRecurrente.RECHAZADA
        reserva_rec.motivo_rechazo = motivo
        await self.session.flush()
        return reserva_rec

    async def cancelar_reserva_recurrente(
        self, reserva_recurrente_id: uuid.UUID, usuario: Usuario
    ) -> ReservaRecurrente:
        """Cancela un patrón y sus instancias futuras pendientes/aprobadas."""
        reserva_rec = await self.repo.get_by_id(reserva_recurrente_id)
        if not reserva_rec:
            raise NotFoundException("ReservaRecurrente", str(reserva_recurrente_id))

        es_admin = can_access_backoffice_section(usuario.rol, BackofficeSection.BOOKINGS)
        if reserva_rec.usuario_id != usuario.id and not es_admin:
            raise ForbiddenException("No puedes cancelar una reserva recurrente de otro usuario")

        if reserva_rec.estado == EstadoReservaRecurrente.CANCELADA:
            raise ValidationException("Este patrón ya está cancelado")

        reserva_rec.estado = EstadoReservaRecurrente.CANCELADA

        # Cancelar instancias futuras PENDIENTE y APROBADA
        from sqlalchemy import select, and_
        from datetime import datetime, timezone

        result = await self.session.execute(
            select(ReservaEspacio).where(
                and_(
                    ReservaEspacio.reserva_recurrente_id == reserva_rec.id,
                    ReservaEspacio.estado.in_(
                        [EstadoReserva.PENDIENTE, EstadoReserva.APROBADA]
                    ),
                    ReservaEspacio.fecha_inicio > datetime.now(timezone.utc),
                )
            )
        )
        instancias_futuras = list(result.scalars().all())
        for inst in instancias_futuras:
            inst.estado = EstadoReserva.CANCELADA
            if inst.tokens_consumidos > 0:
                propietario = reserva_rec.usuario
                if propietario:
                    propietario.tokens = min(
                        MAX_USER_TOKENS,
                        propietario.tokens + inst.tokens_consumidos,
                    )
                    self.session.add(
                        HistorialTokens(
                            usuario_id=reserva_rec.usuario_id,
                            cantidad=inst.tokens_consumidos,
                            tipo=TipoMovimientoToken.DEVOLUCION,
                            motivo="Cancelación de reserva recurrente",
                            reserva_id=inst.id,
                        )
                    )

        await self.session.flush()
        return reserva_rec

    async def generar_instancias_pendientes(self) -> int:
        """
        Tarea del scheduler: genera instancias para los próximos
        _DIAS_ANTICIPACION_INSTANCIAS días de todos los patrones aprobados.
        Devuelve el número de instancias creadas.
        """
        hoy = date.today()
        patrones = await self.repo.get_aprobadas_pendientes_de_generacion(hoy)
        total_creadas = 0

        for patron in patrones:
            creadas = await self._generar_instancias(patron)
            total_creadas += creadas

        return total_creadas

    async def _generar_instancias(self, patron: ReservaRecurrente) -> int:
        """
        Genera las instancias concretas (ReservaEspacio) del patrón
        hasta _DIAS_ANTICIPACION_INSTANCIAS días en el futuro.
        Evita duplicados comprobando solapamiento antes de crear.
        """
        hoy = date.today()
        horizonte = hoy + timedelta(days=_DIAS_ANTICIPACION_INSTANCIAS)
        ultima = patron.ultima_instancia_generada or (patron.fecha_inicio - timedelta(days=1))

        fechas = self._calcular_fechas(
            patron=patron,
            desde=max(ultima + timedelta(days=1), hoy),
            hasta=min(horizonte, patron.fecha_fin_recurrencia),
        )

        creadas = 0
        for fecha in fechas:
            if fecha.weekday() >= 5:
                continue

            fecha_inicio, fecha_fin = local_slot_to_utc_range(
                fecha, patron.tramo.hora_inicio, patron.tramo.hora_fin
            )

            hay_conflicto = await self.reserva_repo.check_solapamiento(
                espacio_id=patron.espacio_id,
                fecha_inicio=fecha_inicio,
                fecha_fin=fecha_fin,
            )
            if hay_conflicto:
                self.logger.info(
                    "recurring_instance_skipped_conflict",
                    extra={"extra_data": {"patron_id": str(patron.id), "fecha": str(fecha)}},
                )
                continue

            # Descontar tokens si aplica
            tokens = patron.tokens_por_instancia
            if tokens > 0:
                from app.repositories.usuario_repo import UsuarioRepository
                usuario_repo = UsuarioRepository(self.session)
                propietario = await usuario_repo.get_by_id(patron.usuario_id)
                if propietario and propietario.tokens >= tokens:
                    propietario.tokens -= tokens
                    self.session.add(
                        HistorialTokens(
                            usuario_id=patron.usuario_id,
                            cantidad=-tokens,
                            tipo=TipoMovimientoToken.CONSUMO_RESERVA,
                            motivo=f"Instancia recurrente de {patron.espacio.nombre if patron.espacio else 'espacio'}",
                        )
                    )
                elif propietario:
                    # Sin tokens suficientes → se omite esta instancia
                    self.logger.info(
                        "recurring_instance_skipped_tokens",
                        extra={"extra_data": {"patron_id": str(patron.id), "fecha": str(fecha)}},
                    )
                    continue

            instancia = ReservaEspacio(
                usuario_id=patron.usuario_id,
                espacio_id=patron.espacio_id,
                tramo_id=patron.tramo_id,
                fecha_inicio=fecha_inicio,
                fecha_fin=fecha_fin,
                estado=EstadoReserva.APROBADA,
                tokens_consumidos=tokens,
                observaciones=patron.observaciones,
                reserva_recurrente_id=patron.id,
            )
            self.session.add(instancia)
            patron.ultima_instancia_generada = fecha
            creadas += 1

        await self.session.flush()
        return creadas

    @staticmethod
    def _calcular_fechas(
        patron: ReservaRecurrente, desde: date, hasta: date
    ) -> list[date]:
        """Genera las fechas que corresponden al patrón de recurrencia."""
        fechas: list[date] = []
        if patron.tipo_recurrencia == TipoRecurrencia.SEMANAL:
            delta = timedelta(weeks=1)
        elif patron.tipo_recurrencia == TipoRecurrencia.QUINCENAL:
            delta = timedelta(weeks=2)
        else:  # MENSUAL – misma fecha del mes cada mes
            delta = None

        if delta is not None:
            # Calcular el primer día del patrón que cae en o después de `desde`
            cursor = patron.fecha_inicio
            while cursor < desde:
                cursor += delta
            while cursor <= hasta:
                fechas.append(cursor)
                cursor += delta
        else:
            # MENSUAL
            cursor = patron.fecha_inicio
            while cursor <= hasta:
                if cursor >= desde:
                    fechas.append(cursor)
                # Avanzar un mes
                mes = cursor.month + 1
                anio = cursor.year + (mes - 1) // 12
                mes = ((mes - 1) % 12) + 1
                # Mismo día, si existe en ese mes
                import calendar
                max_dia = calendar.monthrange(anio, mes)[1]
                cursor = cursor.replace(year=anio, month=mes, day=min(cursor.day, max_dia))

        return fechas
