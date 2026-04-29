"""
RESERVIVES - Servicio de Autenticación.

Gestiona la autenticación mediante Microsoft EntraID (OAuth2/OIDC).
En modo desarrollo, permite login con email directamente.
Genera tokens JWT internos para la sesión de la app.
"""

import uuid
from datetime import datetime, timedelta, timezone

import httpx
from jose import JWTError, jwt
from sqlalchemy import select

from app.config import get_settings
from app.models.configuracion import Configuracion
from app.models.usuario import RolUsuario, Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.utils.role_access import initial_tokens_for_role
from app.utils.exceptions import ForbiddenException, ReservivesException

settings = get_settings()


async def _get_config_int(repo: UsuarioRepository, clave: str, default: int) -> int:
    result = await repo.session.execute(
        select(Configuracion.valor).where(Configuracion.clave == clave)
    )
    raw = result.scalar_one_or_none()
    if raw is None:
        return default
    parsed = str(raw).strip()
    if parsed.isdigit():
        return int(parsed)
    return default


async def _get_tokens_iniciales_por_rol(repo: UsuarioRepository, rol: RolUsuario) -> int:
    alumno_default = await _get_config_int(
        repo,
        "tokens_iniciales_nuevo_usuario",
        settings.DEFAULT_MONTHLY_TOKENS,
    )
    alumno_tokens = await _get_config_int(
        repo,
        "tokens_iniciales_alumno",
        alumno_default,
    )
    profesor_tokens = await _get_config_int(
        repo,
        "tokens_iniciales_profesor",
        60,
    )
    return initial_tokens_for_role(rol, alumno_tokens, profesor_tokens)


async def _get_config_bool(repo: UsuarioRepository, clave: str, default: bool = False) -> bool:
    result = await repo.session.execute(
        select(Configuracion.valor).where(Configuracion.clave == clave)
    )
    raw = result.scalar_one_or_none()
    if raw is None:
        return default
    return str(raw).strip().lower() in {"1", "true", "yes", "on", "si"}


def determinar_rol_por_email(email: str) -> RolUsuario:
    """
    Determina el rol del usuario basándose en el dominio del email.
    - @alumno.iesluisvives.org → ALUMNO
    - @profesor.iesluisvives.org → PROFESOR
    - @iesluisvives.org → ADMIN
    """
    domain = email.split("@")[-1].lower()
    if domain == "alumno.iesluisvives.org":
        return RolUsuario.ALUMNO
    elif domain == "profesor.iesluisvives.org":
        return RolUsuario.PROFESOR
    elif domain == "iesluisvives.org":
        return RolUsuario.ADMIN
    else:
        raise ForbiddenException(f"El dominio '{domain}' no está autorizado")


def crear_token_jwt(usuario_id: uuid.UUID, rol: str) -> str:
    """Genera un token JWT interno para la sesión del usuario."""
    payload = {
        "sub": str(usuario_id),
        "rol": rol,
        "exp": datetime.now(timezone.utc) + timedelta(
            minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
        ),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def verificar_token_jwt(token: str) -> dict:
    """Verifica y decodifica un token JWT interno."""
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError:
        raise ReservivesException("Token inválido o expirado", status_code=401)


async def validar_token_microsoft(microsoft_token: str) -> dict:
    """
    Valida un token de Microsoft EntraID contra el servicio de Microsoft.
    Devuelve los datos del usuario desde el Graph API.

    En producción: valida el token con Microsoft y obtiene datos del usuario.
    """
    try:
        # Llamar al Microsoft Graph API para obtener datos del usuario
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {microsoft_token}"},
            )
            if response.status_code != 200:
                raise ReservivesException(
                    "Token de Microsoft inválido", status_code=401
                )
            return response.json()
    except httpx.ConnectError:
        raise ReservivesException(
            "No se pudo conectar con Microsoft EntraID", status_code=503
        )


async def login_con_microsoft(
    microsoft_token: str, repo: UsuarioRepository
) -> tuple[str, Usuario, bool]:
    """
    Proceso completo de login con Microsoft EntraID.
    1. Valida el token con Microsoft
    2. Busca o crea el usuario en la BD
    3. Genera un JWT interno
    """
    # Obtener datos de Microsoft
    ms_data = await validar_token_microsoft(microsoft_token)

    email = ms_data.get("mail", ms_data.get("userPrincipalName", ""))
    microsoft_id = ms_data.get("id", "")

    # Verificar dominio permitido
    domain = email.split("@")[-1].lower()
    if domain not in settings.allowed_domains_list:
        raise ForbiddenException(f"El dominio '{domain}' no está autorizado")

    # Buscar usuario existente
    usuario = await repo.get_by_microsoft_id(microsoft_id)

    is_new_user = False
    if not usuario:
        # Crear nuevo usuario
        rol = determinar_rol_por_email(email)
        tokens_iniciales = await _get_tokens_iniciales_por_rol(repo, rol)

        usuario = Usuario(
            nombre=ms_data.get("givenName", ""),
            apellidos=ms_data.get("surname", ""),
            email=email,
            microsoft_id=microsoft_id,
            rol=rol,
            tokens=tokens_iniciales,
        )
        usuario = await repo.create(usuario)
        is_new_user = True

    if not usuario.activo:
        raise ForbiddenException("Tu cuenta ha sido desactivada")

    # Generar JWT interno
    token = crear_token_jwt(usuario.id, usuario.rol.value)
    return token, usuario, is_new_user


def _split_nombre_apellidos(email: str) -> tuple[str, str]:
    local = email.split("@")[0].strip() or "usuario"
    chunks = [c for c in local.replace(".", " ").replace("_", " ").split() if c]
    if not chunks:
        return "Usuario", "Temporal"
    nombre = chunks[0].capitalize()
    apellidos = " ".join(ch.capitalize() for ch in chunks[1:]) or "Temporal"
    return nombre, apellidos


async def login_desarrollo(
    repo: UsuarioRepository, email: str | None = None
) -> tuple[str, Usuario, bool]:
    """
    Login sin OAuth para desarrollo.
    Se habilita/deshabilita desde la tabla configuracion:
    - clave: auth_dev_bypass_enabled
    - valor: true/false
    """
    enabled = await _get_config_bool(repo, "auth_dev_bypass_enabled", default=False)
    if not enabled:
        raise ForbiddenException("El login sin autenticar esta deshabilitado")

    login_email = (email or "dev@iesluisvives.org").strip().lower()

    domain = login_email.split("@")[-1]
    if domain not in settings.allowed_domains_list:
        raise ForbiddenException(f"El dominio '{domain}' no esta autorizado")

    usuario = await repo.get_by_email(login_email)
    is_new_user = False

    if not usuario:
        nombre, apellidos = _split_nombre_apellidos(login_email)
        rol = determinar_rol_por_email(login_email)
        tokens_iniciales = await _get_tokens_iniciales_por_rol(repo, rol)

        usuario = Usuario(
            nombre=nombre,
            apellidos=apellidos,
            email=login_email,
            microsoft_id=None,
            rol=rol,
            tokens=tokens_iniciales,
        )
        usuario = await repo.create(usuario)
        is_new_user = True

    if not usuario.activo:
        raise ForbiddenException("Tu cuenta ha sido desactivada")

    token = crear_token_jwt(usuario.id, usuario.rol.value)
    return token, usuario, is_new_user
