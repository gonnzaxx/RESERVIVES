"""
RESERVIVES - Router de Reservas Recurrentes.

Endpoints para crear, consultar y gestionar reservas periódicas.
La aprobación es exclusiva del rol ADMIN / JEFE_ESTUDIOS.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_backoffice_section
from app.models.notificacion import TipoNotificacion
from app.models.reserva_recurrente import EstadoReservaRecurrente
from app.models.usuario import Usuario
from app.repositories.reserva_recurrente_repo import ReservaRecurrenteRepository
from app.schemas.reserva import (
    ReservaRecurrenteCreate,
    ReservaRecurrenteRechazarBody,
    ReservaRecurrenteResponse,
)
from app.services.notification_service import NotificationService
from app.services.reserva_recurrente_service import ReservaRecurrenteService
from app.services.websocket_manager import admin_ws_manager
from app.utils.exceptions import ReservivesException
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/reservas-recurrentes", tags=["Reservas Recurrentes"])


def _to_response(rec) -> ReservaRecurrenteResponse:
    resp = ReservaRecurrenteResponse.model_validate(rec)
    if rec.usuario:
        resp.nombre_usuario = f"{rec.usuario.nombre} {rec.usuario.apellidos}"
    if rec.espacio:
        resp.nombre_espacio = rec.espacio.nombre
    if rec.tramo:
        resp.nombre_tramo = rec.tramo.nombre
    return resp


@router.get("/", response_model=list[ReservaRecurrenteResponse], summary="Listar reservas recurrentes")
async def listar_reservas_recurrentes(
    estado: EstadoReservaRecurrente | None = None,
    skip: int = 0,
    limit: int = 50,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lista reservas recurrentes.
    - Admin: todas.
    - Usuario: solo las propias.
    """
    repo = ReservaRecurrenteRepository(db)
    if can_access_backoffice_section(current_user.rol, BackofficeSection.BOOKINGS):
        if estado:
            reservas = await repo.get_by_estado(estado, skip, limit)
        else:
            reservas = await repo.get_all_with_relations(skip, limit)
    else:
        reservas = await repo.get_by_usuario(current_user.id, skip, limit)
        if estado:
            reservas = [r for r in reservas if r.estado == estado]

    return [_to_response(r) for r in reservas]


@router.get("/{reserva_id}", response_model=ReservaRecurrenteResponse)
async def obtener_reserva_recurrente(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    repo = ReservaRecurrenteRepository(db)
    reserva = await repo.get_by_id(reserva_id)
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva recurrente no encontrada")

    es_admin = can_access_backoffice_section(current_user.rol, BackofficeSection.BOOKINGS)
    if not es_admin and reserva.usuario_id != current_user.id:
        raise HTTPException(status_code=403, detail="No puedes ver esta reserva")

    return _to_response(reserva)


@router.post("/", response_model=ReservaRecurrenteResponse, status_code=201,
             summary="Solicitar reserva recurrente")
async def crear_reserva_recurrente(
    data: ReservaRecurrenteCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Crea una solicitud de reserva recurrente. Queda en estado PENDIENTE_APROBACION
    hasta que un administrador la revise.
    """
    try:
        service = ReservaRecurrenteService(db)
        reserva = await service.crear_reserva_recurrente(current_user, data)
        repo = ReservaRecurrenteRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        nombre_espacio = reserva.espacio.nombre if reserva.espacio else "espacio"
        await notification_service.notify_admins(
            tipo=TipoNotificacion.NUEVA_RESERVA_RECURRENTE_PENDIENTE,
            titulo="Nueva solicitud de reserva recurrente",
            mensaje=(
                f'{current_user.nombre} solicita reservar "{nombre_espacio}" '
                f'de forma {reserva.tipo_recurrencia.value.lower()} '
                f'desde {reserva.fecha_inicio} hasta {reserva.fecha_fin_recurrencia}.'
            ),
            referencia_id=str(reserva.id),
            email_data={
                "template_key": "admin_nueva_reserva_pendiente",
                "context": {
                    "usuario": f"{current_user.nombre} {current_user.apellidos}",
                    "recurso": f"{nombre_espacio} (recurrente {reserva.tipo_recurrencia.value.lower()})",
                    "inicio": str(reserva.fecha_inicio),
                    "fin": str(reserva.fecha_fin_recurrencia),
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_recurrente_created"})

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/aprobar", response_model=ReservaRecurrenteResponse,
             summary="Aprobar reserva recurrente")
async def aprobar_reserva_recurrente(
    reserva_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Aprueba la solicitud y genera las primeras instancias de reserva. Solo admin."""
    try:
        service = ReservaRecurrenteService(db)
        reserva = await service.aprobar_reserva_recurrente(reserva_id, admin)
        repo = ReservaRecurrenteRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        nombre_espacio = reserva.espacio.nombre if reserva.espacio else "espacio"
        await notification_service.create_for_user(
            usuario_id=reserva.usuario_id,
            tipo=TipoNotificacion.RESERVA_RECURRENTE_APROBADA,
            titulo="Reserva recurrente aprobada",
            mensaje=(
                f'Tu solicitud de reserva {reserva.tipo_recurrencia.value.lower()} '
                f'en "{nombre_espacio}" ha sido aprobada. '
                f'Las reservas se generarán automáticamente hasta el {reserva.fecha_fin_recurrencia}.'
            ),
            referencia_id=str(reserva.id),
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_recurrente_aprobada"})

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/rechazar", response_model=ReservaRecurrenteResponse,
             summary="Rechazar reserva recurrente")
async def rechazar_reserva_recurrente(
    reserva_id: uuid.UUID,
    body: ReservaRecurrenteRechazarBody | None = None,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Rechaza la solicitud con motivo opcional. Solo admin."""
    try:
        motivo = body.motivo_rechazo if body else None
        service = ReservaRecurrenteService(db)
        reserva = await service.rechazar_reserva_recurrente(reserva_id, admin, motivo)
        repo = ReservaRecurrenteRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        nombre_espacio = reserva.espacio.nombre if reserva.espacio else "espacio"
        msg = (
            f'Tu solicitud de reserva {reserva.tipo_recurrencia.value.lower()} '
            f'en "{nombre_espacio}" ha sido rechazada.'
        )
        if motivo:
            msg += f" Motivo: {motivo}"

        await notification_service.create_for_user(
            usuario_id=reserva.usuario_id,
            tipo=TipoNotificacion.RESERVA_RECURRENTE_RECHAZADA,
            titulo="Reserva recurrente rechazada",
            mensaje=msg,
            referencia_id=str(reserva.id),
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_recurrente_rechazada"})

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/cancelar", response_model=ReservaRecurrenteResponse,
             summary="Cancelar reserva recurrente")
async def cancelar_reserva_recurrente(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancela un patrón recurrente y sus instancias futuras."""
    try:
        service = ReservaRecurrenteService(db)
        reserva = await service.cancelar_reserva_recurrente(reserva_id, current_user)
        repo = ReservaRecurrenteRepository(db)
        reserva = await repo.get_by_id(reserva.id)
        await admin_ws_manager.broadcast_admin({"event": "reserva_recurrente_cancelada"})
        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)
