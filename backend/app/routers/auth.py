from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.schemas.usuario import (
    DevLoginRequest,
    GuestTokenResponse,
    LoginRequest,
    TokenResponse,
    UsuarioResponse,
)
from app.services.auth_service import login_con_microsoft, login_desarrollo, login_guest
from app.services.websocket_manager import admin_ws_manager

router = APIRouter(prefix="/auth", tags=["Autenticación"])


# Autentica al usuario con un token de Microsoft EntraID.
# Si es la primera vez que entra, se crea su cuenta automáticamente.
# El rol viene determinado por los grupos de Entra ID.
@router.post("/login", response_model=TokenResponse, summary="Login con Microsoft EntraID")
async def login_microsoft(
    data: LoginRequest, db: AsyncSession = Depends(get_db)
):
    repo = UsuarioRepository(db)
    token, usuario, is_new_user, detected_roles = await login_con_microsoft(
        data.microsoft_token, repo
    )
    if is_new_user:
        await admin_ws_manager.broadcast_admin({"event": "usuario_created"})
    user_payload = UsuarioResponse.model_validate(usuario)
    user_payload.roles_detectados = detected_roles
    return TokenResponse(
        access_token=token,
        user=user_payload,
    )


# Login para desarrollo local sin pasar por OAuth.
# Permite simular cualquier rol sin necesitar cuenta de Microsoft.
@router.post(
    "/login-dev",
    response_model=TokenResponse,
    summary="Login de desarrollo sin OAuth",
)
async def login_dev(
    data: DevLoginRequest, db: AsyncSession = Depends(get_db)
):
    repo = UsuarioRepository(db)
    token, usuario, is_new_user = await login_desarrollo(repo, data.email, data.rol)
    if is_new_user:
        await admin_ws_manager.broadcast_admin({"event": "usuario_created"})
    return TokenResponse(
        access_token=token,
        user=UsuarioResponse.model_validate(usuario),
    )


# Genera un token de acceso limitado para usuarios sin cuenta.
# Útil para mostrar la app en modo demo o consulta pública.
@router.post(
    "/guest",
    response_model=GuestTokenResponse,
    summary="Acceso invitado sin autenticacion",
)
async def guest_access():
    token = await login_guest()
    return GuestTokenResponse(access_token=token)


# Devuelve los datos del usuario autenticado a partir del token JWT.
@router.get("/me", response_model=UsuarioResponse, summary="Obtener usuario actual")
async def get_me(usuario: Usuario = Depends(get_current_user)):
    return UsuarioResponse.model_validate(usuario)
