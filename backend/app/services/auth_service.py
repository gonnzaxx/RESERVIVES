"""
RESERVIVES - Servicio de Autenticacion.

Gestiona la autenticacion mediante Microsoft Entra ID (OAuth2/OIDC),
la asignacion de rol por grupos Azure y el acceso invitado.
"""

import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
from jose import JWTError, jwt
from sqlalchemy import select

from app.config import get_settings
from app.models.configuracion import Configuracion
from app.models.usuario import RolUsuario, Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.utils.exceptions import ForbiddenException, ReservivesException
from app.utils.logging import get_logger
from app.utils.role_access import initial_tokens_for_role

settings = get_settings()
logger = get_logger("app.services.auth")

_ROLE_PRIORITY: list[RolUsuario] = [
    RolUsuario.ADMIN,
    RolUsuario.JEFE_ESTUDIOS,
    RolUsuario.SECRETARIA,
    RolUsuario.PROFESOR_SERVICIO,
    RolUsuario.PROFESOR,
    RolUsuario.CAFETERIA,
    RolUsuario.ALUMNO,
]


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


def _parse_rol(raw_role: str) -> RolUsuario:
    normalized = raw_role.strip().upper()
    try:
        return RolUsuario(normalized)
    except ValueError as exc:
        raise ReservivesException(
            f"Rol '{raw_role}' no valido en AZURE_GROUP_ROLE_MAP",
            status_code=500,
        ) from exc


def resolve_roles_from_group_ids(group_ids: list[str]) -> list[RolUsuario]:
    """
    Resuelve todos los roles detectados a partir de los grupos de Azure AD.
    Soporta multiples grupos por usuario.
    """
    mapping = settings.azure_group_role_map
    roles: list[RolUsuario] = []
    seen: set[RolUsuario] = set()
    for group_id in group_ids:
        raw_role = mapping.get(group_id.strip().lower())
        if not raw_role:
            continue
        rol = _parse_rol(raw_role)
        if rol in seen:
            continue
        seen.add(rol)
        roles.append(rol)
    return roles


def pick_primary_role(roles: list[RolUsuario]) -> RolUsuario:
    if not roles:
        raise ForbiddenException(
            "Tu cuenta no pertenece a ningun grupo autorizado de Microsoft Entra ID"
        )
    for role in _ROLE_PRIORITY:
        if role in roles:
            return role
    return roles[0]


def crear_token_jwt(
    *,
    usuario_id: uuid.UUID | None,
    rol: str,
    is_guest: bool = False,
) -> str:
    """Genera un token JWT interno para la sesion del usuario."""
    payload: dict = {
        "rol": rol,
        "is_guest": is_guest,
        "exp": datetime.now(timezone.utc) + timedelta(
            minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
        ),
        "iat": datetime.now(timezone.utc),
    }
    if usuario_id is not None:
        payload["sub"] = str(usuario_id)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def verificar_token_jwt(token: str) -> dict:
    """Verifica y decodifica un token JWT interno."""
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError as exc:
        raise ReservivesException("Token invalido o expirado", status_code=401) from exc


async def _fetch_all_group_ids(
    client: httpx.AsyncClient,
    microsoft_token: str,
) -> list[str]:
    headers = {"Authorization": f"Bearer {microsoft_token}"}
    url = "https://graph.microsoft.com/v1.0/me/memberOf?$select=id"
    group_ids: list[str] = []
    while url:
        response = await client.get(url, headers=headers)
        if response.status_code != 200:
            raise ReservivesException(
                "No se pudieron obtener los grupos de Microsoft Entra ID",
                status_code=401,
            )
        body = response.json()
        for entry in body.get("value", []):
            group_id = entry.get("id")
            if isinstance(group_id, str) and group_id:
                group_ids.append(group_id)
        next_link = body.get("@odata.nextLink")
        url = next_link if isinstance(next_link, str) else ""
    return group_ids


async def _sync_microsoft_profile_photo(
    *,
    microsoft_token: str,
    microsoft_id: str,
) -> str | None:
    """
    Descarga la foto de perfil desde Microsoft Graph y la persiste en uploads.
    Devuelve la URL publica relativa de avatar o None si no hay foto.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://graph.microsoft.com/v1.0/me/photo/$value",
                headers={"Authorization": f"Bearer {microsoft_token}"},
            )
        if response.status_code != 200:
            return None
        content_type = response.headers.get("content-type", "").lower()
        extension = "jpg"
        if "png" in content_type:
            extension = "png"
        avatars_dir = (Path(__file__).resolve().parents[2] / "uploads" / "avatars").resolve()
        avatars_dir.mkdir(parents=True, exist_ok=True)
        filename = f"ms_{microsoft_id}.{extension}"
        output = avatars_dir / filename
        output.write_bytes(response.content)
        return f"/api/uploads/avatars/{filename}"
    except Exception:
        logger.exception("failed_to_sync_graph_profile_photo")
        return None


async def validar_token_microsoft(microsoft_token: str) -> tuple[dict, list[str]]:
    """
    Valida un token de Microsoft Entra ID contra Microsoft Graph.
    Devuelve (perfil_usuario, group_ids).
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            profile_response = await client.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {microsoft_token}"},
            )
            if profile_response.status_code != 200:
                raise ReservivesException(
                    "Token de Microsoft invalido", status_code=401
                )
            profile = profile_response.json()
            group_ids = await _fetch_all_group_ids(client, microsoft_token)
            return profile, group_ids
    except httpx.ConnectError as exc:
        raise ReservivesException(
            "No se pudo conectar con Microsoft Entra ID", status_code=503
        ) from exc


async def login_con_microsoft(
    microsoft_token: str, repo: UsuarioRepository
) -> tuple[str, Usuario, bool, list[RolUsuario]]:
    """
    Proceso completo de login con Microsoft Entra ID.
    1. Valida token y carga perfil + grupos
    2. Resuelve rol por grupos
    3. Busca/crea usuario y sincroniza rol
    4. Genera JWT interno
    """
    ms_data, group_ids = await validar_token_microsoft(microsoft_token)
    detected_roles = resolve_roles_from_group_ids(group_ids)
    if not detected_roles:
        logger.warning(
            "microsoft_login_no_authorized_groups",
            extra={
                "extra_data": {
                    "group_ids_count": len(group_ids),
                    "group_ids_sample": group_ids[:10],
                    "mapped_group_ids": list(settings.azure_group_role_map.keys()),
                }
            },
        )
    primary_role = pick_primary_role(detected_roles)

    email = ms_data.get("mail", ms_data.get("userPrincipalName", ""))
    microsoft_id = ms_data.get("id", "")
    if not microsoft_id:
        raise ReservivesException("No se pudo resolver el identificador de Microsoft", 401)

    usuario = await repo.get_by_microsoft_id(microsoft_id)
    is_new_user = False

    if not usuario and email:
        usuario = await repo.get_by_email(email.lower())

    avatar_url = await _sync_microsoft_profile_photo(
        microsoft_token=microsoft_token,
        microsoft_id=microsoft_id,
    )

    if not usuario:
        tokens_iniciales = await _get_tokens_iniciales_por_rol(repo, primary_role)
        usuario = Usuario(
            nombre=ms_data.get("givenName", "") or "Usuario",
            apellidos=ms_data.get("surname", "") or "Reservives",
            email=(email or f"user-{microsoft_id}@microsoft.local").lower(),
            microsoft_id=microsoft_id,
            rol=primary_role,
            tokens=tokens_iniciales,
            avatar_url=avatar_url,
        )
        usuario = await repo.create(usuario)
        is_new_user = True
    else:
        update_payload: dict = {}
        # Solo actualizar el rol desde Azure si NO fue asignado manualmente por un admin
        if not getattr(usuario, 'rol_override', False) and usuario.rol != primary_role:
            update_payload["rol"] = primary_role
        if email and usuario.email.lower() != email.lower():
            update_payload["email"] = email.lower()
        if not usuario.microsoft_id and microsoft_id:
            update_payload["microsoft_id"] = microsoft_id
        if avatar_url:
            update_payload["avatar_url"] = avatar_url
        if update_payload:
            usuario = await repo.update(usuario, update_payload)

    if not usuario.activo:
        raise ForbiddenException("Tu cuenta ha sido desactivada")

    token = crear_token_jwt(usuario_id=usuario.id, rol=usuario.rol.value)
    logger.info(
        "microsoft_login_success",
        extra={
            "extra_data": {
                "usuario_id": str(usuario.id),
                "microsoft_id": microsoft_id,
                "detected_roles": [r.value for r in detected_roles],
                "primary_role": primary_role.value,
            }
        },
    )
    return token, usuario, is_new_user, detected_roles


def _split_nombre_apellidos(email: str) -> tuple[str, str]:
    local = email.split("@")[0].strip() or "usuario"
    chunks = [c for c in local.replace(".", " ").replace("_", " ").split() if c]
    if not chunks:
        return "Usuario", "Temporal"
    nombre = chunks[0].capitalize()
    apellidos = " ".join(ch.capitalize() for ch in chunks[1:]) or "Temporal"
    return nombre, apellidos


async def login_desarrollo(
    repo: UsuarioRepository,
    email: str | None = None,
    rol: RolUsuario = RolUsuario.ALUMNO,
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

    login_email = (email or "dev@reservives.local").strip().lower()
    usuario = await repo.get_by_email(login_email)
    is_new_user = False

    if not usuario:
        nombre, apellidos = _split_nombre_apellidos(login_email)
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

    token = crear_token_jwt(usuario_id=usuario.id, rol=usuario.rol.value)
    return token, usuario, is_new_user


async def login_guest() -> str:
    """
    Genera una sesion invitada sin OAuth ni credenciales.
    """
    return crear_token_jwt(
        usuario_id=None,
        rol=RolUsuario.ALUMNO.value,
        is_guest=True,
    )
