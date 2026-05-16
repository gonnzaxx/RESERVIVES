"""
IES LUIS VIVES APP - Middleware de autenticación.

Proporciona la dependencia de FastAPI para proteger endpoints.
Extrae el token JWT del header Authorization y devuelve el usuario actual.
"""

import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.configuracion import Configuracion
from app.models.usuario import RolUsuario, Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.services.auth_service import verificar_token_jwt
from app.utils.role_access import (
    BackofficeSection,
    can_access_backoffice_section,
    has_any_backoffice_access,
)

# Esquema de seguridad Bearer para Swagger UI
security = HTTPBearer(auto_error=False)


# Extrae y valida el JWT del header Authorization; devuelve el usuario autenticado o lanza 401
async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Usuario:
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticación requerido",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Verificar el JWT y comprobar que no es sesión de invitado
    payload = verificar_token_jwt(credentials.credentials)
    if payload.get("is_guest"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Funcionalidad no disponible sin autenticar",
        )

    user_id = payload.get("sub")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido",
        )

    # Buscar el usuario en BD y comprobar que está activo
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


# Requiere rol de administrador; lanza 403 si el usuario tiene otro rol
async def require_admin(
    usuario: Usuario = Depends(get_current_user),
) -> Usuario:
    if usuario.rol != RolUsuario.ADMINISTRADOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol de administrador",
        )
    return usuario


# Igual que get_current_user pero devuelve None si no hay token o este es inválido
async def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Usuario | None:
    if not credentials:
        return None
    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None


_BACKOFFICE_SECTIONS_PREFIX = "backoffice_sections_"


# Obtiene las secciones de backoffice configuradas en BD para un rol; None si no hay config custom
async def _get_custom_sections(rol: str, db: AsyncSession) -> list[str] | None:
    rol_str = rol.value if hasattr(rol, "value") else rol
    result = await db.execute(
        select(Configuracion.valor).where(
            Configuracion.clave == f"{_BACKOFFICE_SECTIONS_PREFIX}{rol_str}"
        )
    )
    val = result.scalar_one_or_none()
    if val is None:
        return None
    return [s.strip() for s in val.split(",") if s.strip()]


# Dependencia de fábrica: requiere que el usuario tenga acceso a la sección indicada del backoffice
# Primero comprueba la config personalizada en BD; si no existe, usa las reglas estáticas por rol
def require_backoffice_section(section: BackofficeSection):
    async def _dependency(
        usuario: Usuario = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ) -> Usuario:
        if usuario.rol == RolUsuario.ADMINISTRADOR:
            return usuario

        custom = await _get_custom_sections(usuario.rol, db)
        if custom is not None:
            if section.value not in custom:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="No tienes permisos para acceder a esta seccion",
                )
        elif not can_access_backoffice_section(usuario.rol, section):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para acceder a esta seccion",
            )
        return usuario

    return _dependency


# Requiere que el usuario tenga acceso a al menos una sección del backoffice
async def require_any_backoffice_access(
    usuario: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Usuario:
    if usuario.rol == RolUsuario.ADMINISTRADOR:
        return usuario

    custom = await _get_custom_sections(usuario.rol, db)
    if custom is not None:
        has_access = len(custom) > 0
    else:
        has_access = has_any_backoffice_access(usuario.rol)

    if not has_access:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos de BackOffice",
        )
    return usuario


# Requiere rol de profesor o administrador
async def require_profesor_or_admin(
    usuario: Usuario = Depends(get_current_user),
) -> Usuario:
    if usuario.rol not in [RolUsuario.PROFESOR, RolUsuario.ADMINISTRADOR]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol de profesor o administrador",
        )
    return usuario


# Verifica si la creación de reservas está habilitada globalmente; el admin siempre puede reservar
async def check_reservas_habilitadas(
    db: AsyncSession = Depends(get_db),
    user: Usuario = Depends(get_current_user)
):
    if user.rol == RolUsuario.ADMINISTRADOR:
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
