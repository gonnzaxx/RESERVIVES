from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.schemas.usuario import (
    DevLoginRequest,
    LoginRequest,
    TokenResponse,
    UsuarioResponse,
)
from app.services.auth_service import login_con_microsoft, login_desarrollo
from app.services.websocket_manager import admin_ws_manager

router = APIRouter(prefix="/auth", tags=["Autenticación"])

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login con Microsoft EntraID"
)
async def login_microsoft(
    data: LoginRequest, db: AsyncSession = Depends(get_db)
):
    """
    Autenticación mediante token de Microsoft EntraID.
    El usuario se crea automáticamente en la BD si es su primer login.
    El rol se determina por el dominio del email.
    """
    repo = UsuarioRepository(db)
    token, usuario, is_new_user = await login_con_microsoft(data.microsoft_token, repo)
    if is_new_user:
        await admin_ws_manager.broadcast_admin({"event": "usuario_created"})
    return TokenResponse(
        access_token=token,
        user=UsuarioResponse.model_validate(usuario),
    )


@router.post(
    "/login-dev",
    response_model=TokenResponse,
    summary="Login de desarrollo sin OAuth",
)
async def login_dev(
    data: DevLoginRequest, db: AsyncSession = Depends(get_db)
):
    repo = UsuarioRepository(db)
    token, usuario, is_new_user = await login_desarrollo(repo, data.email)
    if is_new_user:
        await admin_ws_manager.broadcast_admin({"event": "usuario_created"})
    return TokenResponse(
        access_token=token,
        user=UsuarioResponse.model_validate(usuario),
    )


@router.get("/me", response_model=UsuarioResponse, summary="Obtener usuario actual")
async def get_me(usuario: Usuario = Depends(get_current_user)):
    """Devuelve los datos del usuario autenticado."""
    return UsuarioResponse.model_validate(usuario)
