from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db, async_session
from app.models.usuario import Usuario, RolUsuario
from app.models.reserva_espacio import ReservaEspacio
from app.models.espacio import Espacio
from app.models.anuncio import Anuncio
from app.middleware.auth_middleware import require_admin
from app.services.auth_service import verificar_token_jwt
from app.services.websocket_manager import admin_ws_manager
from pydantic import BaseModel
import uuid

router = APIRouter(prefix="/admin", tags=["Admin"])

class AdminSummary(BaseModel):
    total_usuarios: int
    reservas_activas: int
    espacios_disponibles: int
    anuncios_activos: int

@router.get("/summary", response_model=AdminSummary, summary="Obtener KPIs de Admin")
async def get_admin_summary(
    admin: Usuario = Depends(require_admin),
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
            if not usuario or usuario.rol != RolUsuario.ADMIN or not usuario.activo:
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
