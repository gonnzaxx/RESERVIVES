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
from app.models.usuario import Usuario
from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
from app.schemas.reserva import ReservaCreate, ReservaRechazarBody, ReservaResponse, ReservaUpdate
from app.services.notification_service import NotificationService
from app.services.reserva_espacio_service import ReservaEspacioService
from app.services.websocket_manager import admin_ws_manager
from app.utils.datetime_utils import format_for_humans
from app.utils.exceptions import ReservivesException
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/reservas-espacios", tags=["Reservas Espacios"])


def _to_response(reserva) -> ReservaResponse:
    """Convierte un modelo ReservaEspacio a su schema de respuesta con datos aplanados."""
    resp = ReservaResponse.model_validate(reserva)
    if reserva.usuario:
        resp.nombre_usuario = f"{reserva.usuario.nombre} {reserva.usuario.apellidos}"
    if reserva.espacio:
        resp.nombre_espacio = reserva.espacio.nombre
        resp.tipo_espacio = reserva.espacio.tipo.value
    return resp


@router.get("/", response_model=list[ReservaResponse], summary="Listar reservas")
async def listar_reservas(
    estado: EstadoReserva | None = None,
    skip: int = 0,
    limit: int = 50,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lista reservas.
    - Admin: ve todas las reservas.
    - Alumno/Profesor: solo ve sus propias reservas.
    """
    repo = ReservaEspacioRepository(db)

    if can_access_backoffice_section(current_user.rol, BackofficeSection.BOOKINGS):
        if estado:
            reservas = await repo.get_by_estado(estado, skip, limit)
        else:
            reservas = await repo.get_all_with_relations(skip, limit)
    else:
        reservas = await repo.get_by_usuario(current_user.id, skip, limit)

    return [_to_response(r) for r in reservas]


@router.get("/{reserva_id}", response_model=ReservaResponse, summary="Obtener una reserva")
async def obtener_reserva(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene los datos de una reserva especifica."""
    repo = ReservaEspacioRepository(db)
    reserva = await repo.get_by_id(reserva_id)
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    can_view_all = can_access_backoffice_section(current_user.rol, BackofficeSection.BOOKINGS)
    if not can_view_all and reserva.usuario_id != current_user.id:
        raise HTTPException(status_code=403, detail="No puedes ver esta reserva")

    return _to_response(reserva)


@router.post(
    "/",
    response_model=ReservaResponse,
    status_code=201,
    summary="Crear una reserva",
    dependencies=[Depends(check_reservas_habilitadas)],
)
async def crear_reserva(
    data: ReservaCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Crea una nueva reserva de espacio.
    Valida permisos de rol, solapamiento temporal y tokens.
    """
    try:
        service = ReservaEspacioService(db)
        reserva = await service.crear_reserva(current_user, data)
        repo = ReservaEspacioRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        await notification_service.dispatch_email_only(
            usuario_id=current_user.id,
            template_key="reserva_creada",
            context={
                "nombre": current_user.nombre,
                "recurso": reserva.espacio.nombre if reserva.espacio else "instalacion",
                "inicio": format_for_humans(reserva.fecha_inicio),
                "fin": format_for_humans(reserva.fecha_fin),
                "estado": reserva.estado.value,
            },
        )

        if reserva.estado == EstadoReserva.PENDIENTE:
            await notification_service.notify_admins(
                tipo=TipoNotificacion.NUEVA_RESERVA_PENDIENTE,
                titulo="Nueva solicitud de reserva",
                mensaje=f'{current_user.nombre} ha solicitado reservar "{reserva.espacio.nombre if reserva.espacio else "un espacio"}". Necesita aprobacion.',
                referencia_id=str(reserva.id),
                email_data={
                    "template_key": "admin_nueva_reserva_pendiente",
                    "context": {
                        "usuario": f"{current_user.nombre} {current_user.apellidos}",
                        "recurso": reserva.espacio.nombre if reserva.espacio else "espacio",
                        "inicio": format_for_humans(reserva.fecha_inicio),
                        "fin": format_for_humans(reserva.fecha_fin),
                    },
                },
            )

        await admin_ws_manager.broadcast_admin({"event": "reserva_created"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_created",
                "data": {
                    "reservation_id": str(reserva.id),
                    "resource_type": "espacio",
                },
            },
        )

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/cancelar", response_model=ReservaResponse, summary="Cancelar reserva")
async def cancelar_reserva(
    reserva_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancela una reserva y devuelve tokens si corresponde."""
    try:
        service = ReservaEspacioService(db)
        reserva = await service.cancelar_reserva(reserva_id, current_user)
        repo = ReservaEspacioRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva.usuario_id,
            tipo=TipoNotificacion.RESERVA_CANCELADA,
            titulo="Reserva cancelada",
            mensaje=f'Confirmamos la cancelacion de "{reserva.espacio.nombre if reserva.espacio else "espacio"}" para {format_for_humans(reserva.fecha_inicio)}.',
            referencia_id=str(reserva.id),
        )
        await notification_service.dispatch_email_only(
            usuario_id=reserva.usuario_id,
            template_key="reserva_cancelada",
            context={
                "nombre": current_user.nombre,
                "recurso": reserva.espacio.nombre if reserva.espacio else "espacio",
                "inicio": format_for_humans(reserva.fecha_inicio),
            },
        )

        # Notificar al siguiente en la lista de espera si existe
        if reserva.tramo_id:
            from app.services.lista_espera_service import ListaEsperaService
            lista_svc = ListaEsperaService(db)
            await lista_svc.procesar_cancelacion(
                espacio_id=reserva.espacio_id,
                tramo_id=reserva.tramo_id,
                fecha=reserva.fecha_inicio.date(),
                notification_service=notification_service,
            )

        await admin_ws_manager.broadcast_admin({"event": "reserva_cancelada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_cancelada",
                "data": {
                    "reservation_id": str(reserva.id),
                    "resource_type": "espacio",
                },
            },
        )

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/aprobar", response_model=ReservaResponse, summary="Aprobar reserva")
async def aprobar_reserva(
    reserva_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Aprueba una reserva pendiente. Solo admin."""
    try:
        service = ReservaEspacioService(db)
        reserva = await service.aprobar_reserva(reserva_id, admin)
        repo = ReservaEspacioRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva.usuario_id,
            tipo=TipoNotificacion.RESERVA_APROBADA,
            titulo="Reserva aprobada",
            mensaje=f'Tu reserva de "{reserva.espacio.nombre if reserva.espacio else "espacio"}" ha sido aprobada.',
            referencia_id=str(reserva.id),
            email_data={
                "template_key": "reserva_aula_profesor_aprobada"
                if (
                    reserva.usuario
                    and reserva.espacio
                    and reserva.usuario.rol.value == "PROFESOR"
                    and reserva.espacio.tipo.value == "AULA"
                )
                else "reserva_aprobada",
                "context": {
                    "nombre": reserva.usuario.nombre if reserva.usuario else "usuario",
                    "recurso": reserva.espacio.nombre if reserva.espacio else "espacio",
                    "inicio": format_for_humans(reserva.fecha_inicio),
                    "fin": format_for_humans(reserva.fecha_fin),
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_aprobada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_aprobada",
                "data": {
                    "reservation_id": str(reserva.id),
                    "resource_type": "espacio",
                },
            },
        )

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post("/{reserva_id}/rechazar", response_model=ReservaResponse, summary="Rechazar reserva")
async def rechazar_reserva(
    reserva_id: uuid.UUID,
    body: ReservaRechazarBody = None,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    """Rechaza una reserva pendiente y devuelve tokens. Solo admin."""
    try:
        service = ReservaEspacioService(db)
        reserva = await service.rechazar_reserva(reserva_id, admin)
        repo = ReservaEspacioRepository(db)
        reserva = await repo.get_by_id(reserva.id)

        motivo = (
            (body.motivo_rechazo if body and body.motivo_rechazo else None)
            or "Consulta con administracion si necesitas mas informacion."
        )

        notification_service = NotificationService(db)
        await notification_service.create_for_user(
            usuario_id=reserva.usuario_id,
            tipo=TipoNotificacion.RESERVA_RECHAZADA,
            titulo="Reserva rechazada",
            mensaje=f'Tu reserva de "{reserva.espacio.nombre if reserva.espacio else "espacio"}" ha sido rechazada.',
            referencia_id=str(reserva.id),
            email_data={
                "template_key": "reserva_aula_profesor_rechazada"
                if (
                    reserva.usuario
                    and reserva.espacio
                    and reserva.usuario.rol.value == "PROFESOR"
                    and reserva.espacio.tipo.value == "AULA"
                )
                else "reserva_rechazada",
                "context": {
                    "nombre": reserva.usuario.nombre if reserva.usuario else "usuario",
                    "recurso": reserva.espacio.nombre if reserva.espacio else "espacio",
                    "inicio": format_for_humans(reserva.fecha_inicio),
                    "fin": format_for_humans(reserva.fecha_fin),
                    "motivo": motivo,
                },
            },
        )
        await admin_ws_manager.broadcast_admin({"event": "reserva_rechazada"})
        await admin_ws_manager.broadcast_reservation_event(
            reserva.usuario_id,
            {
                "type": "reservation_updated",
                "event": "reserva_rechazada",
                "data": {
                    "reservation_id": str(reserva.id),
                    "resource_type": "espacio",
                },
            },
        )

        return _to_response(reserva)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.get("/espacio/{espacio_id}", response_model=list[ReservaResponse], summary="Reservas de un espacio")
async def reservas_por_espacio(
    espacio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene las reservas de un espacio especifico."""
    repo = ReservaEspacioRepository(db)
    reservas = await repo.get_by_espacio(espacio_id)
    return [_to_response(r) for r in reservas]
