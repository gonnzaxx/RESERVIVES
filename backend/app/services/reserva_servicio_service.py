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
from app.repositories.reserva_servicio_repo import ReservaServicioRepository
from app.repositories.servicio_repo import ServicioRepository
from app.schemas.reserva import ReservaServicioCreate
from app.utils.datetime_utils import ensure_utc_aware
from app.utils.exceptions import (
    ConflictException,
    ForbiddenException,
    InsufficientTokensException,
    NotFoundException,
    ValidationException,
)


class ReservaServicioService:
    """Servicio con la lógica de negocio para reservas de servicios."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.reserva_servicio_repo = ReservaServicioRepository(session)
        self.servicio_repo = ServicioRepository(session)

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

        # 2. Validar tramo y disponibilidad
        from app.services.tramo_service import TramoService
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

        fecha_inicio = datetime.combine(data.fecha, tramo.hora_inicio).replace(tzinfo=timezone.utc)
        fecha_fin = datetime.combine(data.fecha, tramo.hora_fin).replace(tzinfo=timezone.utc)

        # 3. Validar fechas
        inicio_utc = ensure_utc_aware(fecha_inicio)

        if fecha_inicio >= fecha_fin:
            raise ValidationException("La fecha de inicio debe ser anterior a la de fin")
        if inicio_utc < datetime.now(timezone.utc):
            raise ValidationException("No se puede hacer una reserva en el pasado")
        if fecha_inicio.weekday() >= 5 or fecha_fin.weekday() >= 5:
            raise ValidationException("No se permiten reservas en sábado o domingo")

        # 4. Verificar solapamiento
        hay_solapamiento = await self.reserva_servicio_repo.check_solapamiento(
            servicio_id=data.servicio_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
        )
        if hay_solapamiento:
            raise ConflictException(
                "Ya existe una reserva en este servicio para el horario seleccionado"
            )

        # 5. Gestión de tokens (solo alumnos)
        tokens_necesarios = 0
        if usuario.rol == RolUsuario.ALUMNO:
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

        if reserva.usuario_id != usuario.id and usuario.rol != RolUsuario.ADMIN:
            raise ForbiddenException("No puedes cancelar una reserva de otro usuario")

        if reserva.estado in [EstadoReserva.CANCELADA, EstadoReserva.RECHAZADA]:
            raise ValidationException("Esta reserva ya está cancelada o rechazada")

        reserva.estado = EstadoReserva.CANCELADA

        if reserva.tokens_consumidos > 0:
            propietario = reserva.usuario if reserva.usuario else usuario
            propietario.tokens += reserva.tokens_consumidos
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

    async def aprobar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaServicio:
        """Aprueba una reserva de servicio pendiente. Solo admin."""
        if admin.rol != RolUsuario.ADMIN:
            raise ForbiddenException("Solo el administrador puede aprobar reservas")

        reserva = await self.reserva_servicio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva de servicio", str(reserva_id))
        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden aprobar reservas pendientes")

        reserva.estado = EstadoReserva.APROBADA
        await self.session.flush()
        return reserva

    async def rechazar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaServicio:
        """Rechaza una reserva de servicio pendiente y devuelve tokens. Solo admin."""
        if admin.rol != RolUsuario.ADMIN:
            raise ForbiddenException("Solo el administrador puede rechazar reservas")

        reserva = await self.reserva_servicio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva de servicio", str(reserva_id))
        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden rechazar reservas pendientes")

        reserva.estado = EstadoReserva.RECHAZADA

        if reserva.tokens_consumidos > 0 and reserva.usuario:
            reserva.usuario.tokens += reserva.tokens_consumidos
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
