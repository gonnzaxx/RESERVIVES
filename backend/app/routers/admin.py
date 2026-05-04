import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db, async_session
from app.models.usuario import Usuario
from app.models.reserva_espacio import ReservaEspacio
from app.models.reserva_servicio import ReservaServicio
from app.models.espacio import Espacio
from app.models.anuncio import Anuncio
from app.middleware.auth_middleware import require_backoffice_section
from app.services.auth_service import verificar_token_jwt
from app.services.notification_service import NotificationService
from app.services.reserva_espacio_service import ReservaEspacioService
from app.services.reserva_servicio_service import ReservaServicioService
from app.services.websocket_manager import admin_ws_manager
from app.utils.datetime_utils import format_for_humans
from app.utils.exceptions import ReservivesException
from app.utils.logging import get_logger
from app.utils.role_access import BackofficeSection, has_any_backoffice_access
from app.schemas.reserva import ReservaBackofficeResponse, ReservaCancelacionBackofficeBody
from app.models.notificacion import TipoNotificacion
from app.models.reserva_espacio import EstadoReserva
from pydantic import BaseModel

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = get_logger("app.routers.admin")

class AdminSummary(BaseModel):
    total_usuarios: int
    reservas_activas: int
    espacios_disponibles: int
    anuncios_activos: int


def _matches_calendar_filters(
    target: date,
    *,
    day: date | None,
    month: int | None,
    year: int | None,
) -> bool:
    if day and target != day:
        return False
    if month and target.month != month:
        return False
    if year and target.year != year:
        return False
    return True


def _to_backoffice_booking_from_space(item: ReservaEspacio) -> ReservaBackofficeResponse:
    user_name = None
    if item.usuario:
        user_name = f"{item.usuario.nombre} {item.usuario.apellidos}"
    return ReservaBackofficeResponse(
        id=item.id,
        tipo_reserva="ESPACIO",
        usuario_id=item.usuario_id,
        nombre_usuario=user_name,
        email_usuario=item.usuario.email if item.usuario else None,
        recurso_id=item.espacio_id,
        nombre_recurso=item.espacio.nombre if item.espacio else None,
        estado=item.estado,
        fecha_inicio=item.fecha_inicio,
        fecha_fin=item.fecha_fin,
        observaciones=item.observaciones,
        tokens_consumidos=item.tokens_consumidos,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


def _to_backoffice_booking_from_service(item: ReservaServicio) -> ReservaBackofficeResponse:
    user_name = None
    if item.usuario:
        user_name = f"{item.usuario.nombre} {item.usuario.apellidos}"
    return ReservaBackofficeResponse(
        id=item.id,
        tipo_reserva="SERVICIO",
        usuario_id=item.usuario_id,
        nombre_usuario=user_name,
        email_usuario=item.usuario.email if item.usuario else None,
        recurso_id=item.servicio_id,
        nombre_recurso=item.servicio.nombre if item.servicio else None,
        estado=item.estado,
        fecha_inicio=item.fecha_inicio,
        fecha_fin=item.fecha_fin,
        observaciones=item.observaciones,
        tokens_consumidos=item.tokens_consumidos,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )

@router.get("/summary", response_model=AdminSummary, summary="Obtener KPIs de Admin")
async def get_admin_summary(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SUMMARY)),
    db: AsyncSession = Depends(get_db)
):
    """
    Devuelve los KPIs principales para el dashboard de administrador.
    Solo accesible por usuarios con rol ADMIN.
    """
    # Total de usuarios
    total_usuarios_result = await db.execute(select(func.count(Usuario.id)))
    total_usuarios = total_usuarios_result.scalar_one_or_none() or 0

    # Reservas activas (estado == CONFIRMADA)
    reservas_activas_result = await db.execute(select(func.count(ReservaEspacio.id)))
    reservas_activas = reservas_activas_result.scalar_one_or_none() or 0

    # Espacios disponibles (activo == True)
    espacios_disponibles_result = await db.execute(select(func.count(Espacio.id)).where(Espacio.activo == True))
    espacios_disponibles = espacios_disponibles_result.scalar_one_or_none() or 0

    # Anuncios activos
    anuncios_activos_result = await db.execute(select(func.count(Anuncio.id)).where(Anuncio.activo == True))
    anuncios_activos = anuncios_activos_result.scalar_one_or_none() or 0

    return AdminSummary(
        total_usuarios=total_usuarios,
        reservas_activas=reservas_activas,
        espacios_disponibles=espacios_disponibles,
        anuncios_activos=anuncios_activos,
    )


@router.get(
    "/bookings",
    response_model=list[ReservaBackofficeResponse],
    summary="Historico global de reservas para BackOffice",
)
async def backoffice_bookings(
    day: date | None = None,
    month: int | None = Query(default=None, ge=1, le=12),
    year: int | None = Query(default=None, ge=2000, le=2100),
    tipo_reserva: str | None = Query(default=None, pattern="^(ESPACIO|SERVICIO)$"),
    estado: EstadoReserva | None = None,
    usuario_id: uuid.UUID | None = None,
    usuario_q: str | None = Query(default=None, min_length=2),
    limit: int = Query(default=200, ge=1, le=1000),
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    from app.repositories.reserva_espacio_repo import ReservaEspacioRepository
    from app.repositories.reserva_servicio_repo import ReservaServicioRepository

    espacio_repo = ReservaEspacioRepository(db)
    servicio_repo = ReservaServicioRepository(db)

    if estado:
        espacio_items = await espacio_repo.get_by_estado(estado, skip=0, limit=limit)
        servicio_items = await servicio_repo.get_by_estado(estado, skip=0, limit=limit)
    else:
        espacio_items = await espacio_repo.get_all_with_relations(skip=0, limit=limit)
        servicio_items = await servicio_repo.get_all_with_relations(skip=0, limit=limit)

    rows: list[ReservaBackofficeResponse] = []
    if tipo_reserva in (None, "ESPACIO"):
        rows.extend(_to_backoffice_booking_from_space(item) for item in espacio_items)
    if tipo_reserva in (None, "SERVICIO"):
        rows.extend(_to_backoffice_booking_from_service(item) for item in servicio_items)

    filtered: list[ReservaBackofficeResponse] = []
    for row in rows:
        start_date = row.fecha_inicio.date()
        if not _matches_calendar_filters(start_date, day=day, month=month, year=year):
            continue
        if usuario_id and row.usuario_id != usuario_id:
            continue
        if usuario_q:
            probe = usuario_q.strip().lower()
            full_text = f"{row.nombre_usuario or ''} {row.email_usuario or ''}".lower()
            if probe not in full_text:
                continue
        filtered.append(row)

    filtered.sort(key=lambda item: item.fecha_inicio, reverse=True)
    return filtered[:limit]


@router.post(
    "/bookings/{booking_id}/cancel",
    response_model=ReservaBackofficeResponse,
    summary="Cancelar una reserva desde BackOffice",
)
async def backoffice_cancel_booking(
    booking_id: uuid.UUID,
    body: ReservaCancelacionBackofficeBody,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.BOOKINGS)),
    db: AsyncSession = Depends(get_db),
):
    notification_service = NotificationService(db)
    reason = body.motivo.strip()
    if not reason:
        raise HTTPException(status_code=400, detail="El motivo de cancelacion es obligatorio")

    try:
        if body.tipo_reserva == "ESPACIO":
            service = ReservaEspacioService(db)
            reserva = await service.cancelar_reserva(booking_id, admin)
            if not reserva:
                raise HTTPException(status_code=404, detail="Reserva no encontrada")
            reserva.observaciones = (
                f"[Cancelada por BackOffice] {reason}\n{reserva.observaciones or ''}".strip()
            )
            await db.flush()
            from app.repositories.reserva_espacio_repo import ReservaEspacioRepository

            full = await ReservaEspacioRepository(db).get_by_id(reserva.id)
            if not full:
                raise HTTPException(status_code=404, detail="Reserva no encontrada")
            await notification_service.create_for_user(
                usuario_id=full.usuario_id,
                tipo=TipoNotificacion.RESERVA_CANCELADA,
                titulo="Reserva cancelada por BackOffice",
                mensaje=f'Se ha cancelado tu reserva de "{full.espacio.nombre if full.espacio else "espacio"}". Motivo: {reason}',
                referencia_id=str(full.id),
                email_data={
                    "template_key": "reserva_cancelada",
                    "context": {
                        "nombre": full.usuario.nombre if full.usuario else "usuario",
                        "recurso": full.espacio.nombre if full.espacio else "espacio",
                        "inicio": format_for_humans(full.fecha_inicio),
                        "motivo": reason,
                    },
                },
            )
            await admin_ws_manager.broadcast_admin({"event": "reserva_cancelada_backoffice"})
            return _to_backoffice_booking_from_space(full)

        if body.tipo_reserva == "SERVICIO":
            service = ReservaServicioService(db)
            reserva = await service.cancelar_reserva(booking_id, admin)
            if not reserva:
                raise HTTPException(status_code=404, detail="Reserva no encontrada")
            reserva.observaciones = (
                f"[Cancelada por BackOffice] {reason}\n{reserva.observaciones or ''}".strip()
            )
            await db.flush()
            from app.repositories.reserva_servicio_repo import ReservaServicioRepository

            full = await ReservaServicioRepository(db).get_by_id(reserva.id)
            if not full:
                raise HTTPException(status_code=404, detail="Reserva no encontrada")
            await notification_service.create_for_user(
                usuario_id=full.usuario_id,
                tipo=TipoNotificacion.RESERVA_CANCELADA,
                titulo="Reserva de servicio cancelada por BackOffice",
                mensaje=f'Se ha cancelado tu reserva de "{full.servicio.nombre if full.servicio else "servicio"}". Motivo: {reason}',
                referencia_id=str(full.id),
                email_data={
                    "template_key": "reserva_cancelada",
                    "context": {
                        "nombre": full.usuario.nombre if full.usuario else "usuario",
                        "recurso": full.servicio.nombre if full.servicio else "servicio",
                        "inicio": format_for_humans(full.fecha_inicio),
                        "motivo": reason,
                    },
                },
            )
            await admin_ws_manager.broadcast_admin({"event": "reserva_servicio_cancelada_backoffice"})
            return _to_backoffice_booking_from_service(full)

        raise HTTPException(status_code=400, detail="tipo_reserva debe ser ESPACIO o SERVICIO")
    except ReservivesException as exc:
        logger.warning(
            "backoffice_cancel_booking_failed",
            extra={
                "extra_data": {
                    "booking_id": str(booking_id),
                    "tipo_reserva": body.tipo_reserva,
                    "detail": exc.message,
                }
            },
        )
        raise HTTPException(status_code=exc.status_code, detail=exc.message)

@router.websocket("/ws")
async def websocket_admin_endpoint(websocket: WebSocket, token: str = None):
    if not token:
        await websocket.close(code=1008)
        return
        
    try:
        payload = verificar_token_jwt(token)
        user_id = payload.get("sub")
        if not user_id:
            await websocket.close(code=1008)
            return
             
        async with async_session() as session:
            result = await session.execute(select(Usuario).where(Usuario.id == uuid.UUID(user_id)))
            usuario = result.scalar_one_or_none()
            if not usuario or not has_any_backoffice_access(usuario.rol) or not usuario.activo:
                await websocket.close(code=1008)
                return
    except Exception:
        await websocket.close(code=1008)
        return
        
    await admin_ws_manager.connect_admin(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        admin_ws_manager.disconnect_admin(websocket)
