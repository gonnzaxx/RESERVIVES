from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.schemas.notificacion import (
    NotificacionEntregaResponse,
    NotificacionResponse,
    NotificacionesCountResponse,
    PreferenciasNotificacionResponse,
    PreferenciasNotificacionUpdate,
    PushTokenCreate,
)
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notificaciones", tags=["Notificaciones"])


@router.get("/", response_model=list[NotificacionResponse], summary="Listar no leidas")
async def listar_no_leidas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    items = await service.list_unread(current_user.id)
    return [NotificacionResponse.model_validate(i) for i in items]


@router.get("/count", response_model=NotificacionesCountResponse, summary="Contador no leidas")
async def contador_no_leidas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    count = await service.get_unread_count(current_user.id)
    return NotificacionesCountResponse(no_leidas=count)


@router.post(
    "/consumir",
    response_model=list[NotificacionResponse],
    summary="Lee una vez y borra no leidas",
)
async def consumir_no_leidas(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    items = await service.consume_unread(current_user.id)
    return [NotificacionResponse.model_validate(i) for i in items]


@router.delete("/{notificacion_id}", summary="Borrar una notificación")
async def borrar_notificacion(
    notificacion_id: str,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    success = await service.delete_notification(current_user.id, notificacion_id)
    if not success:
        return {"message": "No se pudo borrar o no existe"}
    return {"message": "Notificación borrada"}


@router.post("/push-token", summary="Registrar token push")
async def registrar_push_token(
    payload: PushTokenCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    await service.register_push_token(
        usuario_id=current_user.id,
        token=payload.token,
        plataforma=payload.plataforma,
    )
    return {"message": "Token push registrado"}


@router.get(
    "/preferencias",
    response_model=PreferenciasNotificacionResponse,
    summary="Obtener preferencias de notificacion",
)
async def obtener_preferencias(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    preferences = await service.get_or_create_preferences(current_user.id)
    return PreferenciasNotificacionResponse.model_validate(preferences)


@router.put(
    "/preferencias",
    response_model=PreferenciasNotificacionResponse,
    summary="Actualizar preferencias de notificacion",
)
async def actualizar_preferencias(
    payload: PreferenciasNotificacionUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    preferences = await service.update_preferences(
        usuario_id=current_user.id,
        payload=payload.model_dump(),
    )
    return PreferenciasNotificacionResponse.model_validate(preferences)


@router.get(
    "/historial",
    response_model=list[NotificacionEntregaResponse],
    summary="Historial de entregas de notificaciones",
)
async def historial_notificaciones(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    history = await service.list_delivery_history(current_user.id)
    return [NotificacionEntregaResponse.model_validate(item) for item in history]
