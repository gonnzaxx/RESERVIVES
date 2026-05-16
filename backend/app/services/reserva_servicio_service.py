"""
RESERVIVES - Servicio de Reservas de Servicios.

Lógica de negocio para crear, cancelar, aprobar y rechazar reservas de servicios.
Sigue el mismo patrón que ReservaEspacioService (reserva_espacio_service.py), encapsulando
toda la lógica fuera del router.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.historial_tokens import HistorialTokens, TipoMovimientoToken
from app.models.reserva_espacio import EstadoReserva
from app.models.reserva_servicio import ReservaServicio
from app.models.usuario import RolUsuario, Usuario
from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
from app.repositories.reserva_servicio_repo import ReservaServicioRepository
from app.repositories.servicio_repo import ServicioRepository
from app.schemas.reserva import ReservaServicioCreate
from app.services.tramo_service import TramoService
from app.utils.datetime_utils import ensure_utc_aware, local_slot_to_utc_range
from app.utils.exceptions import (
    ConflictException,
    ForbiddenException,
    InsufficientTokensException,
    NotFoundException,
    ValidationException,
)
from app.utils.logging import get_logger
from app.utils.non_working_days import is_non_working_day
from app.utils.role_access import (
    BackofficeSection,
    MAX_USER_TOKENS,
    can_access_backoffice_section,
    uses_tokens,
)


class ReservaServicioService:
    """Servicio con la lógica de negocio para reservas de servicios."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.reserva_servicio_repo = ReservaServicioRepository(session)
        self.servicio_repo = ServicioRepository(session)
        self.logger = get_logger("app.services.reserva_servicio")

    async def crear_reserva(
        self, usuario: Usuario, data: ReservaServicioCreate
    ) -> ReservaServicio:
        """
        Crea una nueva reserva de servicio validando todas las reglas de negocio:
        1. El servicio existe y está activo
        2. El tramo es válido y está disponible
        3. No hay solapamiento temporal
        4. El alumno tiene tokens suficientes
        """
        # 1. Verificar que el servicio existe y está activo
        servicio = await self.servicio_repo.get_by_id(data.servicio_id)
        if not servicio or not servicio.activo:
            raise NotFoundException("Servicio", str(data.servicio_id))

        # 1b. Verificar que el rol del usuario tiene acceso al servicio
        roles_permitidos = [rp.rol for rp in servicio.roles_permitidos]
        roles_sin_restriccion = {RolUsuario.ADMINISTRADOR, RolUsuario.JEFATURA}
        if roles_permitidos and usuario.rol not in roles_sin_restriccion and usuario.rol not in roles_permitidos:
            raise ForbiddenException("Tu rol no tiene permiso para reservar este servicio")

        # 2. Validar tramo y disponibilidad
        tramo_svc = TramoService(self.session)
        tramo = await tramo_svc.get_tramo_by_id(data.tramo_id)
        if not tramo or not tramo.activo:
            raise ValidationException("El tramo horario seleccionado no es válido")

        disponibilidad = await tramo_svc.get_disponibilidad_servicio(data.servicio_id, data.fecha)
        disp_tramo = next((d for d in disponibilidad if d.tramo.id == data.tramo_id), None)
        if not disp_tramo:
            raise ValidationException("El tramo no existe para este servicio")
        if not disp_tramo.permitido:
            raise ValidationException("Este tramo no está habilitado para este servicio")
        if disp_tramo.reservado:
            raise ConflictException("Este tramo ya está reservado para esa fecha")

        # Convierte el slot horario local del instituto a UTC para persistir en BD
        fecha_inicio, fecha_fin = local_slot_to_utc_range(
            data.fecha,
            tramo.hora_inicio,
            tramo.hora_fin,
        )
        self.logger.info(
            "service_reservation_slot_computed",
            extra={
                "extra_data": {
                    "fecha": str(data.fecha),
                    "tramo_id": str(data.tramo_id),
                    "hora_inicio_local": str(tramo.hora_inicio),
                    "hora_fin_local": str(tramo.hora_fin),
                    "fecha_inicio_utc": fecha_inicio.isoformat(),
                    "fecha_fin_utc": fecha_fin.isoformat(),
                }
            },
        )

        # 3. Validar fechas
        inicio_utc = ensure_utc_aware(fecha_inicio)

        if fecha_inicio >= fecha_fin:
            raise ValidationException("La fecha de inicio debe ser anterior a la de fin")
        if inicio_utc < datetime.now(timezone.utc):
            raise ValidationException("No se puede hacer una reserva en el pasado")
        if fecha_inicio.weekday() >= 5 or fecha_fin.weekday() >= 5:
            raise ValidationException("No se permiten reservas en sábado o domingo")

        if await is_non_working_day(self.session, data.fecha):
            raise ValidationException("Este día es no laborable y no admite reservas")

        # 4. Verificar solapamiento en el recurso
        hay_solapamiento = await self.reserva_servicio_repo.check_solapamiento(
            servicio_id=data.servicio_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
        )
        if hay_solapamiento:
            raise ConflictException(
                "Ya existe una reserva en este servicio para el horario seleccionado"
            )

        # 4b. Verificar solapamiento del usuario con cualquier otro recurso
        espacio_repo = ReservaEspacioRepository(self.session)
        if await self.reserva_servicio_repo.check_solapamiento_usuario(usuario.id, fecha_inicio, fecha_fin):
            raise ConflictException("Ya tienes una reserva de servicio en este horario")
        if await espacio_repo.check_solapamiento_usuario(usuario.id, fecha_inicio, fecha_fin):
            raise ConflictException("Ya tienes una reserva de espacio en este horario")

        # 5. Gestión de tokens (solo alumnos)
        tokens_necesarios = 0
        if uses_tokens(usuario.rol):
            tokens_necesarios = servicio.precio_tokens
            if usuario.tokens < tokens_necesarios:
                raise InsufficientTokensException(usuario.tokens, tokens_necesarios)

        # 6. Crear la reserva (servicios siempre pasan por PENDIENTE)
        reserva = ReservaServicio(
            usuario_id=usuario.id,
            servicio_id=data.servicio_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            observaciones=data.observaciones,
            estado=EstadoReserva.PENDIENTE,
            tokens_consumidos=tokens_necesarios,
            tramo_id=data.tramo_id,
        )
        reserva = await self.reserva_servicio_repo.create(reserva)

        # 7. Descontar tokens si es alumno
        if tokens_necesarios > 0:
            usuario.tokens -= tokens_necesarios
            historial = HistorialTokens(
                usuario_id=usuario.id,
                cantidad=-tokens_necesarios,
                tipo=TipoMovimientoToken.CONSUMO_RESERVA,
                motivo=f"Reserva de servicio: {servicio.nombre}",
                reserva_servicio_id=reserva.id,
            )
            self.session.add(historial)
            await self.session.flush()

        return reserva

    async def cancelar_reserva(
        self, reserva_id: uuid.UUID, usuario: Usuario
    ) -> ReservaServicio:
        """
        Cancela una reserva de servicio y devuelve tokens si corresponde.
        Solo el propietario o un admin puede cancelar.
        """
        reserva = await self.reserva_servicio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva de servicio", str(reserva_id))

        is_owner = reserva.usuario_id == usuario.id
        is_admin_or_jefatura = usuario.rol in {RolUsuario.ADMINISTRADOR, RolUsuario.JEFATURA}
        is_gestor_of_service = False
        if usuario.rol == RolUsuario.GESTOR_SERVICIO:
            servicio = await self.servicio_repo.get_by_id(reserva.servicio_id)
            is_gestor_of_service = servicio and servicio.gestor_usuario_id == usuario.id

        if not (is_owner or is_admin_or_jefatura or is_gestor_of_service):
            raise ForbiddenException("No puedes cancelar una reserva de otro usuario")

        if reserva.estado in [EstadoReserva.CANCELADA, EstadoReserva.RECHAZADA]:
            raise ValidationException("Esta reserva ya está cancelada o rechazada")

        reserva.estado = EstadoReserva.CANCELADA

        if reserva.tokens_consumidos > 0:
            propietario = reserva.usuario if reserva.usuario else usuario
            propietario.tokens = min(MAX_USER_TOKENS, propietario.tokens + reserva.tokens_consumidos)
            historial = HistorialTokens(
                usuario_id=reserva.usuario_id,
                cantidad=reserva.tokens_consumidos,
                tipo=TipoMovimientoToken.DEVOLUCION,
                motivo="Cancelación de reserva de servicio",
                reserva_servicio_id=reserva.id,
            )
            self.session.add(historial)

        await self.session.flush()
        return reserva

    async def _can_manage_service_reservation(self, admin: Usuario, reserva: ReservaServicio) -> bool:
        if can_access_backoffice_section(admin.rol, BackofficeSection.BOOKINGS):
            if admin.rol in {RolUsuario.ADMINISTRADOR, RolUsuario.JEFATURA, RolUsuario.CONTROL}:
                return True
            if admin.rol == RolUsuario.GESTOR_SERVICIO:
                servicio = await self.servicio_repo.get_by_id(reserva.servicio_id)
                return servicio is not None and servicio.gestor_usuario_id == admin.id
        return False

    async def aprobar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaServicio:
        """Aprueba una reserva de servicio pendiente."""
        reserva = await self.reserva_servicio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva de servicio", str(reserva_id))

        if not await self._can_manage_service_reservation(admin, reserva):
            raise ForbiddenException("No tienes permisos para aprobar esta reserva")

        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden aprobar reservas pendientes")

        reserva.estado = EstadoReserva.APROBADA
        await self.session.flush()
        return reserva

    async def rechazar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaServicio:
        """Rechaza una reserva de servicio pendiente y devuelve tokens."""
        reserva = await self.reserva_servicio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva de servicio", str(reserva_id))

        if not await self._can_manage_service_reservation(admin, reserva):
            raise ForbiddenException("No tienes permisos para rechazar esta reserva")

        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden rechazar reservas pendientes")

        reserva.estado = EstadoReserva.RECHAZADA

        if reserva.tokens_consumidos > 0 and reserva.usuario:
            reserva.usuario.tokens = min(MAX_USER_TOKENS, reserva.usuario.tokens + reserva.tokens_consumidos)
            historial = HistorialTokens(
                usuario_id=reserva.usuario_id,
                cantidad=reserva.tokens_consumidos,
                tipo=TipoMovimientoToken.DEVOLUCION,
                motivo="Reserva de servicio rechazada por administrador",
                reserva_servicio_id=reserva.id,
            )
            self.session.add(historial)

        await self.session.flush()
        return reserva
