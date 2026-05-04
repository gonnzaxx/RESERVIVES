import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.database import async_session
from app.models.usuario import Usuario
from app.services.auth_service import verificar_token_jwt
from app.services.websocket_manager import admin_ws_manager

router = APIRouter(prefix="/ws", tags=["WebSocket"])


@router.websocket("/reservations")
async def websocket_reservations_endpoint(websocket: WebSocket, token: str | None = None):
    if not token:
        await websocket.close(code=1008)
        return

    try:
        payload = verificar_token_jwt(token)
        user_id_raw = payload.get("sub")
        if not user_id_raw:
            await websocket.close(code=1008)
            return
        user_id = uuid.UUID(user_id_raw)

        async with async_session() as session:
            result = await session.execute(select(Usuario).where(Usuario.id == user_id))
            user = result.scalar_one_or_none()
            if not user or not user.activo:
                await websocket.close(code=1008)
                return
    except Exception:
        await websocket.close(code=1008)
        return

    await admin_ws_manager.connect_reservations(websocket, user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        admin_ws_manager.disconnect_reservations(websocket, user_id)
