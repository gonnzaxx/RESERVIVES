"""
RESERVIVES - Servicio de Reservas.

Lógica de negocio para crear, modificar y gestionar reservas.
Incluye control de concurrencia, validación de roles,
y gestión de tokens.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.espacio import TipoEspacio
from app.models.historial_tokens import HistorialTokens, TipoMovimientoToken
from app.models.reserva_espacio import EstadoReserva, ReservaEspacio
from app.models.reserva_servicio import ReservaServicio
from app.models.usuario import RolUsuario, Usuario
from app.repositories.espacio_repo import EspacioRepository
from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
from app.repositories.servicio_repo import ServicioRepository
from app.schemas.reserva import (
    ReservaCreate,
    ReservaServicioCreate,
)
from app.utils.exceptions import (
    ConflictException,
    ForbiddenException,
    InsufficientTokensException,
    NotFoundException,
    ValidationException,
)
from app.utils.datetime_utils import ensure_utc_aware
from app.utils.role_access import (
    BackofficeSection,
    MAX_USER_TOKENS,
    can_access_backoffice_section,
    uses_tokens,
)


class ReservaEspacioService:
    """Servicio con la lógica de negocio para reservas de espacios."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.reserva_espacio_repo = ReservaEspacioRepository(session)
        self.espacio_repo = EspacioRepository(session)

    async def crear_reserva(
        self, usuario: Usuario, data: ReservaCreate
    ) -> ReservaEspacio:
        """
        Crea una nueva reserva validando todas las reglas de negocio:
        1. El espacio existe y es reservable
        2. El usuario tiene el rol adecuado
        3. El tramo es válido y está disponible
        4. No hay solapamiento temporal
        5. El alumno tiene tokens suficientes
        """
        # 1. Verificar que el espacio existe y es reservable
        espacio = await self.espacio_repo.get_by_id_with_roles(data.espacio_id)
        if not espacio:
            raise NotFoundException("Espacio", str(data.espacio_id))
        if not espacio.reservable or not espacio.activo:
            raise ValidationException("Este espacio no está disponible para reservas")

        # 2. Verificar permisos de rol
        roles_permitidos = [rp.rol for rp in espacio.roles_permitidos]
        if usuario.rol.value not in roles_permitidos and usuario.rol != RolUsuario.ADMIN:
            raise ForbiddenException(
                f"Los usuarios con rol {usuario.rol.value} no pueden reservar este espacio"
            )

        # Regla: alumnos solo pueden reservar pistas
        if usuario.rol == RolUsuario.ALUMNO and espacio.tipo == TipoEspacio.AULA:
            raise ForbiddenException("Los alumnos solo pueden reservar pistas deportivas")

        # 3. Calcular fecha_inicio y fecha_fin según el sistema de tramos
        from app.services.tramo_service import TramoService
        tramo_svc = TramoService(self.session)
        tramo = await tramo_svc.get_tramo_by_id(data.tramo_id)
        if not tramo or not tramo.activo:
            raise ValidationException("El tramo horario seleccionado no es válido")

        disponibilidad = await tramo_svc.get_disponibilidad_espacio(data.espacio_id, data.fecha)
        disp_tramo = next((d for d in disponibilidad if d.tramo.id == data.tramo_id), None)
        if not disp_tramo:
            raise ValidationException("El tramo no existe para este espacio")
        if not disp_tramo.permitido:
            raise ValidationException("Este tramo no está habilitado para este espacio")
        if disp_tramo.reservado:
            raise ConflictException("Este tramo ya está reservado para esa fecha")

        fecha_inicio = datetime.combine(data.fecha, tramo.hora_inicio).replace(tzinfo=timezone.utc)
        fecha_fin = datetime.combine(data.fecha, tramo.hora_fin).replace(tzinfo=timezone.utc)
        tramo_id_para_guardar = data.tramo_id

        # 4. Validar fechas
        inicio_utc = ensure_utc_aware(fecha_inicio)
        fin_utc = ensure_utc_aware(fecha_fin)

        if fecha_inicio >= fecha_fin:
            raise ValidationException("La fecha de inicio debe ser anterior a la de fin")
        if inicio_utc < datetime.now(timezone.utc):
            raise ValidationException("No se puede hacer una reserva en el pasado")
        if fecha_inicio.weekday() >= 5 or fecha_fin.weekday() >= 5:
            raise ValidationException("No se permiten reservas en sabado o domingo")

        # 5. Verificar solapamiento
        hay_solapamiento = await self.reserva_espacio_repo.check_solapamiento(
            espacio_id=data.espacio_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
        )
        if hay_solapamiento:
            raise ConflictException(
                "Ya existe una reserva en este espacio para el horario seleccionado"
            )

        # 6. Gestión de tokens (solo alumnos)
        tokens_necesarios = 0
        if uses_tokens(usuario.rol):
            tokens_necesarios = espacio.precio_tokens
            if usuario.tokens < tokens_necesarios:
                raise InsufficientTokensException(usuario.tokens, tokens_necesarios)

        # 7. Determinar estado inicial
        estado = EstadoReserva.PENDIENTE
        if espacio.tipo == TipoEspacio.PISTA and not espacio.requiere_autorizacion:
            estado = EstadoReserva.APROBADA

        # 8. Crear la reserva
        reserva = ReservaEspacio(
            usuario_id=usuario.id,
            espacio_id=data.espacio_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            observaciones=data.observaciones,
            estado=estado,
            tokens_consumidos=tokens_necesarios,
            tramo_id=tramo_id_para_guardar,
        )
        reserva = await self.reserva_espacio_repo.create(reserva)

        # 9. Descontar tokens si es alumno
        if tokens_necesarios > 0:
            usuario.tokens -= tokens_necesarios
            historial = HistorialTokens(
                usuario_id=usuario.id,
                cantidad=-tokens_necesarios,
                tipo=TipoMovimientoToken.CONSUMO_RESERVA,
                motivo=f"Reserva de {espacio.nombre}",
                reserva_id=reserva.id,
            )
            self.session.add(historial)
            await self.session.flush()

        return reserva


    async def cancelar_reserva(
        self, reserva_id: uuid.UUID, usuario: Usuario
    ) -> ReservaEspacio:
        """
        Cancela una reserva y devuelve tokens si corresponde.
        Solo el propietario o un admin puede cancelar.
        """
        reserva = await self.reserva_espacio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva", str(reserva_id))

        # Verificar permisos
        if reserva.usuario_id != usuario.id and usuario.rol != RolUsuario.ADMIN:
            raise ForbiddenException("No puedes cancelar una reserva de otro usuario")

        if reserva.estado in [EstadoReserva.CANCELADA, EstadoReserva.RECHAZADA]:
            raise ValidationException("Esta reserva ya está cancelada o rechazada")

        # Cancelar la reserva
        reserva.estado = EstadoReserva.CANCELADA

        # Devolver tokens si se consumieron
        if reserva.tokens_consumidos > 0:
            propietario = reserva.usuario if reserva.usuario else usuario
            propietario.tokens = min(MAX_USER_TOKENS, propietario.tokens + reserva.tokens_consumidos)
            # Registrar devolución
            historial = HistorialTokens(
                usuario_id=reserva.usuario_id,
                cantidad=reserva.tokens_consumidos,
                tipo=TipoMovimientoToken.DEVOLUCION,
                motivo=f"Cancelación de reserva",
                reserva_id=reserva.id,
            )
            self.session.add(historial)

        await self.session.flush()
        return reserva

    async def aprobar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaEspacio:
        """Aprueba una reserva pendiente. Solo admin."""
        if not can_access_backoffice_section(admin.rol, BackofficeSection.BOOKINGS):
            raise ForbiddenException("No tienes permisos para aprobar reservas")

        reserva = await self.reserva_espacio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva", str(reserva_id))
        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden aprobar reservas pendientes")

        reserva.estado = EstadoReserva.APROBADA
        await self.session.flush()
        return reserva

    async def rechazar_reserva(
        self, reserva_id: uuid.UUID, admin: Usuario
    ) -> ReservaEspacio:
        """Rechaza una reserva pendiente y devuelve tokens. Solo admin."""
        if not can_access_backoffice_section(admin.rol, BackofficeSection.BOOKINGS):
            raise ForbiddenException("No tienes permisos para rechazar reservas")

        reserva = await self.reserva_espacio_repo.get_by_id(reserva_id)
        if not reserva:
            raise NotFoundException("Reserva", str(reserva_id))
        if reserva.estado != EstadoReserva.PENDIENTE:
            raise ValidationException("Solo se pueden rechazar reservas pendientes")

        reserva.estado = EstadoReserva.RECHAZADA

        # Devolver tokens
        if reserva.tokens_consumidos > 0:
            # Obtener el usuario propietario de la reserva
            from app.repositories.usuario_repo import UsuarioRepository
            usuario_repo = UsuarioRepository(self.session)
            propietario = await usuario_repo.get_by_id(reserva.usuario_id)
            if propietario:
                propietario.tokens = min(MAX_USER_TOKENS, propietario.tokens + reserva.tokens_consumidos)
                historial = HistorialTokens(
                    usuario_id=reserva.usuario_id,
                    cantidad=reserva.tokens_consumidos,
                    tipo=TipoMovimientoToken.DEVOLUCION,
                    motivo="Reserva rechazada por administrador",
                    reserva_id=reserva.id,
                )
                self.session.add(historial)

        await self.session.flush()
        return reserva

