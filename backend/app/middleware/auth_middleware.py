"""
RESERVIVES - Middleware de autenticación.

Proporciona la dependencia de FastAPI para proteger endpoints.
Extrae el token JWT del header Authorization y devuelve el usuario actual.
"""

import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.usuario import RolUsuario, Usuario
from app.models.configuracion import Configuracion
from app.repositories.usuario_repo import UsuarioRepository
from app.services.auth_service import verificar_token_jwt

# Esquema de seguridad Bearer para Swagger UI
security = HTTPBearer(auto_error=False)


from sqlalchemy import select

async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Usuario:
    """
    Dependencia de FastAPI: extrae y valida el JWT del header Authorization.
    Devuelve el usuario autenticado o lanza 401.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticación requerido",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Verificar el JWT
    payload = verificar_token_jwt(credentials.credentials)
    user_id = payload.get("sub")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido",
        )

    # Buscar el usuario en la BD
    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(uuid.UUID(user_id))

    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado",
        )

    if not usuario.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta ha sido desactivada",
        )

    return usuario


async def require_admin(
    usuario: Usuario = Depends(get_current_user),
) -> Usuario:
    """Dependencia que requiere rol de administrador."""
    if usuario.rol != RolUsuario.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol de administrador",
        )
    return usuario


async def require_profesor_or_admin(
    usuario: Usuario = Depends(get_current_user),
) -> Usuario:
    """Dependencia que requiere rol de profesor o administrador."""
    if usuario.rol not in [RolUsuario.PROFESOR, RolUsuario.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol de profesor o administrador",
        )
    return usuario


async def check_reservas_habilitadas(
    db: AsyncSession = Depends(get_db),
    user: Usuario = Depends(get_current_user)
):
    """Verifica si la creación de reservas está habilitada globalmente."""
    if user.rol == RolUsuario.ADMIN:
        return
    
    result = await db.execute(
        select(Configuracion.valor).where(Configuracion.clave == "se_permiten_reservas")
    )
    permitido = result.scalar_one_or_none()
    
    if permitido == "false":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Las reservas están temporalmente deshabilitadas.",
        )
