import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    check_reservas_habilitadas,
    get_current_user,
    require_backoffice_section,
)
from app.models.notificacion import TipoNotificacion
from app.models.reserva_espacio import EstadoReserva
from app.models.reserva_servicio import ReservaServicio
from app.models.usuario import Usuario
from app.repositories.reserva_servicio_repo import ReservaServicioRepository
from app.schemas.reserva import ReservaRechazarBody, ReservaServicioCreate, ReservaServicioResponse
from app.services.notification_service import NotificationService
from app.services.reserva_servicio_service import ReservaServicioService
from app.services.websocket_manager import admin_ws_manager
from app.utils.datetime_utils import format_for_humans
from app.utils.exceptions import ReservivesException
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/servicios", tags=["Reservas Servicios"])


def _to_reserva_servicio_response(reserva: ReservaServicio) -> ReservaServicioResponse:
    resp = ReservaServicioResponse.model_validate(reserva)
    if reserva.usuario:
        resp.nombre_usuario = f"{reserva.usuario.nombre} {reserva.usuario.apellidos}"
    if reserva.servicio:
        resp.nombre_servicio = reserva.servicio.nombre
    return resp


async def _get_reserva_servicio_con_relaciones(
    db: AsyncSession,
    reserva_id: uuid.UUID,
) -> ReservaServicio | None:
    """Helper: recarga una ReservaServicio con todas las relaciones necesarias para la respuesta."""
    repo = ReservaServicioRepository(db)
    return await repo.get_by_id(reserva_id)


@router.post(
    "/reservar",
    response_model=ReservaServicioResponse,
    status_code=201,
    summary="Reservar servicio",
    dependencies=[Depends(check_reservas_habilitadas)],
)
async def reservar_servicio(
    data: ReservaServicioCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Reserva un servicio del instituto usando el sistema de tramos.
    Valida disponibilidad del tramo, solapamientos y tokens.
    """
    try:
        service = ReservaServicioService(db)
        reserva = await service.crear_reserva(current_user, data)
        reserva_full = await _get_reserva_servicio_con_relaciones(db, reserva.id)
        if not reserva_full:
            raise HTTPException(status_code=500, detail="No se pudo recuperar la reserva creada")

        notification_service = NotificationService(db)
        await notification_service.dispatch_email_only(
            usuario_id=current_user.id,
            template_key="reserva_creada",
            context={
                "nombre": current_user.nombre,
                "recurso": reserva_full.servicio.nombre if reserva_full.servicio else "servicio",
                "inicio": format_for_humans(reserva_full.fecha_inicio),
                "fin": format_for_humans(reserva_full.fecha_fin),
                "estado": "PENDIENTE",
            },
        )
        await notification_service.notify_admins(
            tipo=TipoNotificacion.NUEVA_RESERVA_PENDIENTE,
            titulo="Nueva solicitud de servicio",
            mensaje=f'{current_user.nombre} ha solicitado el servicio "{reserva_full.servicio.nombre if reserva_full.servicio else "servicio"}". Necesita aprobacion.',
            referencia_id=str(reserva_full.id),
            email_data={
                "template_key": "admin_nueva_reserva_pendiente",
                "context": {
                    "usuario": f"{current_user.nombre} {current_user.apellidos}",
                    "recurso": reserva_full.servicio.nombre if reserva_full.servicio else "servicio",
                    "inicio": format_for_humans(reserva_full.fecha_inicio),
                    "fin": format_for_humans(reserva_full.fecha_fin),
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_servicio_created"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva_full.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_servicio_created",
                "data": {
                    "reservation_id": str(reserva_full.id),
                    "resource_type": "servicio",
                },
            },
        )

        return _to_reserva_servicio_response(reserva_full)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post(
    "/reservas/{reserva_id}/cancelar",
    response_model=ReservaServicioResponse,
    summary="Cancelar reserva de servicio",
)
async def cancelar_reserva_servicio(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancela una reserva de servicio y devuelve tokens si corresponde."""
    try:
        service = ReservaServicioService(db)
        reserva = await service.cancelar_reserva(reserva_id, current_user)
        reserva_full = await _get_reserva_servicio_con_relaciones(db, reserva.id)

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva_full.usuario_id,
            tipo=TipoNotificacion.RESERVA_CANCELADA,
            titulo="Reserva de servicio cancelada",
            mensaje=f'Confirmamos la cancelacion de "{reserva_full.servicio.nombre if reserva_full.servicio else "servicio"}" para {format_for_humans(reserva_full.fecha_inicio)}.',
            referencia_id=str(reserva_full.id),
        )
        await notification_service.dispatch_email_only(
            usuario_id=reserva_full.usuario_id,
            template_key="reserva_cancelada",
            context={
                "nombre": current_user.nombre,
                "recurso": reserva_full.servicio.nombre if reserva_full.servicio else "servicio",
                "inicio": format_for_humans(reserva_full.fecha_inicio),
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_servicio_cancelada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva_full.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_servicio_cancelada",
                "data": {
                    "reservation_id": str(reserva_full.id),
                    "resource_type": "servicio",
                },
            },
        )

        return _to_reserva_servicio_response(reserva_full)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.get("/reservas", response_model=list[ReservaServicioResponse], summary="Mis reservas de servicios")
async def mis_reservas_servicios(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene las reservas de servicios del usuario actual."""
    repo = ReservaServicioRepository(db)
    reservas = await repo.get_by_usuario(current_user.id)
    return [_to_reserva_servicio_response(r) for r in reservas]


@router.get(
    "/reservas/detalle/{reserva_id}",
    response_model=ReservaServicioResponse,
    summary="Obtener una reserva de servicio",
)
async def obtener_reserva_servicio(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    repo = ReservaServicioRepository(db)
    reserva = await repo.get_by_id(reserva_id)
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    can_view_all = can_access_backoffice_section(
        current_user.rol,
        BackofficeSection.BOOKINGS,
    )
    if not can_view_all and reserva.usuario_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="No puedes ver esta reserva",
        )

    return _to_reserva_servicio_response(reserva)


@router.get(
    "/reservas/todas",
    response_model=list[ReservaServicioResponse],
    summary="Todas las reservas de servicios",
)
async def todas_reservas_servicios(
    estado: EstadoReserva | None = None,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Lista todas las reservas de servicios. Solo admin. Filtra por estado si se indica."""
    repo = ReservaServicioRepository(db)
    if estado:
        reservas = await repo.get_by_estado(estado)
    else:
        reservas = await repo.get_all_with_relations()
    return [_to_reserva_servicio_response(r) for r in reservas]


@router.post(
    "/reservas/{reserva_id}/aprobar",
    response_model=ReservaServicioResponse,
    summary="Aprobar reserva de servicio",
)
async def aprobar_reserva_servicio(
    reserva_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Aprueba una reserva de servicio pendiente. Solo admin."""
    try:
        service = ReservaServicioService(db)
        reserva = await service.aprobar_reserva(reserva_id, admin)
        reserva_full = await _get_reserva_servicio_con_relaciones(db, reserva.id)
        if not reserva_full:
            raise HTTPException(status_code=500, detail="No se pudo recuperar la reserva aprobada")

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva_full.usuario_id,
            tipo=TipoNotificacion.RESERVA_APROBADA,
            titulo="Reserva de servicio aprobada",
            mensaje=(
                f'Tu reserva de "{reserva_full.servicio.nombre if reserva_full.servicio else "servicio"}" '
                f'ha sido aprobada.'
            ),
            referencia_id=str(reserva_full.id),
            email_data={
                "template_key": "reserva_servicio_aprobada",
                "context": {
                    "nombre": reserva_full.usuario.nombre if reserva_full.usuario else "usuario",
                    "recurso": reserva_full.servicio.nombre if reserva_full.servicio else "servicio",
                    "inicio": format_for_humans(reserva_full.fecha_inicio),
                    "fin": format_for_humans(reserva_full.fecha_fin),
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_servicio_aprobada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva_full.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_servicio_aprobada",
                "data": {
                    "reservation_id": str(reserva_full.id),
                    "resource_type": "servicio",
                },
            },
        )

        return _to_reserva_servicio_response(reserva_full)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post(
    "/reservas/{reserva_id}/rechazar",
    response_model=ReservaServicioResponse,
    summary="Rechazar reserva de servicio",
)
async def rechazar_reserva_servicio(
    reserva_id: uuid.UUID,
    body: ReservaRechazarBody = None,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Rechaza una reserva de servicio pendiente y devuelve tokens. Solo admin."""
    try:
        service = ReservaServicioService(db)
        reserva = await service.rechazar_reserva(reserva_id, admin)
        reserva_full = await _get_reserva_servicio_con_relaciones(db, reserva.id)
        if not reserva_full:
            raise HTTPException(status_code=500, detail="No se pudo recuperar la reserva rechazada")

        motivo = (
            (body.motivo_rechazo if body and body.motivo_rechazo else None)
            or "Consulta con administracion si necesitas mas informacion."
        )

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva_full.usuario_id,
            tipo=TipoNotificacion.RESERVA_RECHAZADA,
            titulo="Reserva de servicio rechazada",
            mensaje=(
                f'Tu reserva de "{reserva_full.servicio.nombre if reserva_full.servicio else "servicio"}" '
                f'ha sido rechazada.'
            ),
            referencia_id=str(reserva_full.id),
            email_data={
                "template_key": "reserva_servicio_rechazada",
                "context": {
                    "nombre": reserva_full.usuario.nombre if reserva_full.usuario else "usuario",
                    "recurso": reserva_full.servicio.nombre if reserva_full.servicio else "servicio",
                    "inicio": format_for_humans(reserva_full.fecha_inicio),
                    "fin": format_for_humans(reserva_full.fecha_fin),
                    "motivo": motivo,
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_servicio_rechazada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva_full.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_servicio_rechazada",
                "data": {
                    "reservation_id": str(reserva_full.id),
                    "resource_type": "servicio",
                },
            },
        )

        return _to_reserva_servicio_response(reserva_full)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)
