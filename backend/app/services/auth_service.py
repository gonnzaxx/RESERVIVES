"""
IES LUIS VIVES APP - Servicio de Autenticacion.

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
from app.utils.role_access import MAX_USER_TOKENS, initial_tokens_for_role

settings = get_settings()
logger = get_logger("app.services.auth")

_ROLE_PRIORITY: list[RolUsuario] = [
    RolUsuario.ADMINISTRADOR,
    RolUsuario.JEFATURA,
    RolUsuario.CONTROL,
    RolUsuario.SECRETARIA,
    RolUsuario.GESTOR_SERVICIO,
    RolUsuario.PROFESOR,
    RolUsuario.CAFETERIA,
    RolUsuario.ALUMNO,
]


# Lee un valor entero de la tabla configuracion; devuelve default si no existe o no es numérico
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


# Resuelve los tokens iniciales para un rol nuevo.
# Primero busca config específica por rol (tokens_iniciales_control),
# si no existe cae en el agrupado alumno/profesor.
async def _get_tokens_iniciales_por_rol(repo: UsuarioRepository, rol: str | RolUsuario) -> int:
    rol_str = rol.value.lower() if hasattr(rol, "value") else str(rol).lower()
    per_role_key = f"tokens_iniciales_{rol_str}"
    per_role_value = await _get_config_int(repo, per_role_key, -1)
    if per_role_value >= 0:
        return min(per_role_value, MAX_USER_TOKENS)

    # Fallback al config agrupado (alumno / estilo-profesor)
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


# Lee un booleano de configuracion; acepta "1", "true", "yes", "on", "si"
async def _get_config_bool(repo: UsuarioRepository, clave: str, default: bool = False) -> bool:
    result = await repo.session.execute(
        select(Configuracion.valor).where(Configuracion.clave == clave)
    )
    raw = result.scalar_one_or_none()
    if raw is None:
        return default
    return str(raw).strip().lower() in {"1", "true", "yes", "on", "si"}


# Normaliza un nombre de rol a mayúsculas; sirve tanto para roles del sistema como custom
def _parse_rol(raw_role: str) -> str:
    return raw_role.strip().upper()


# Construye el mapa grupo_azure_id → rol combinando settings.py y la tabla configuracion.
# Los valores de la BD tienen prioridad sobre los del settings.
async def _build_group_role_map(repo: UsuarioRepository) -> dict[str, str]:
    result = await repo.session.execute(
        select(Configuracion).where(Configuracion.clave.like("azure_group_%"))
    )
    configs = result.scalars().all()

    db_map: dict[str, str] = {}
    for c in configs:
        role_name = c.clave.removeprefix("azure_group_")
        for gid in c.valor.split(","):
            gid_clean = gid.strip().lower()
            if gid_clean:
                db_map[gid_clean] = role_name.upper()

    return {**settings.azure_group_role_map, **db_map}


# Resuelve todos los roles del usuario a partir de sus grupos de Azure AD.
# Un usuario puede pertenecer a varios grupos, cada uno mapeado a un rol distinto.
def resolve_roles_from_group_ids(group_ids: list[str], mapping: dict[str, str]) -> list[str]:
    roles: list[str] = []
    seen: set[str] = set()
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


# Selecciona el rol principal según la jerarquía definida en _ROLE_PRIORITY.
# Si no coincide ningún rol del sistema, devuelve el primero (rol custom).
def pick_primary_role(roles: list[str]) -> str:
    if not roles:
        raise ForbiddenException(
            "Tu cuenta no pertenece a ningun grupo autorizado de Microsoft Entra ID"
        )
    priority_values = [r.value for r in _ROLE_PRIORITY]
    for role_value in priority_values:
        if role_value in roles:
            return role_value
    # Rol custom: devolver el primero encontrado
    return roles[0]


# Genera un JWT interno firmado con la clave del servidor
def crear_token_jwt(
    *,
    usuario_id: uuid.UUID | None,
    rol: str,
    is_guest: bool = False,
) -> str:
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


# Verifica y decodifica un JWT interno; lanza 401 si está caducado o es inválido
def verificar_token_jwt(token: str) -> dict:
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError as exc:
        raise ReservivesException("Token invalido o expirado", status_code=401) from exc


# Obtiene todos los group IDs del usuario desde Microsoft Graph, paginando si hace falta
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


# Descarga la foto de perfil desde Microsoft Graph y la guarda en uploads/avatars.
# Devuelve la URL relativa o None si no hay foto o falla la descarga.
async def _sync_microsoft_profile_photo(
    *,
    microsoft_token: str,
    microsoft_id: str,
) -> str | None:
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


# Valida un access token de Microsoft contra Graph y devuelve (perfil, group_ids)
async def validar_token_microsoft(microsoft_token: str) -> tuple[dict, list[str]]:
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


# Flujo completo de login con Microsoft:
# valida token → resuelve rol → busca/crea usuario → devuelve JWT + datos de sesión
async def login_con_microsoft(
    microsoft_token: str, repo: UsuarioRepository
) -> tuple[str, Usuario, bool, list[str]]:
    ms_data, group_ids = await validar_token_microsoft(microsoft_token)
    group_role_map = await _build_group_role_map(repo)
    detected_roles = resolve_roles_from_group_ids(group_ids, group_role_map)
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
            email=(email or f"ms-{microsoft_id}@iesluisvives.org").lower(),
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

    token = crear_token_jwt(usuario_id=usuario.id, rol=usuario.rol)
    logger.info(
        "microsoft_login_success",
        extra={
            "extra_data": {
                "usuario_id": str(usuario.id),
                "microsoft_id": microsoft_id,
                "detected_roles": detected_roles,
                "primary_role": primary_role,
            }
        },
    )
    return token, usuario, is_new_user, detected_roles


# Extrae nombre y apellidos del local-part del email (p. ej. "juan.garcia" → "Juan", "Garcia")
def _split_nombre_apellidos(email: str) -> tuple[str, str]:
    local = email.split("@")[0].strip() or "usuario"
    chunks = [c for c in local.replace(".", " ").replace("_", " ").split() if c]
    if not chunks:
        return "Usuario", "Temporal"
    nombre = chunks[0].capitalize()
    apellidos = " ".join(ch.capitalize() for ch in chunks[1:]) or "Temporal"
    return nombre, apellidos


# Login de desarrollo sin OAuth; solo funciona si auth_dev_bypass_enabled está activo en BD
async def login_desarrollo(
    repo: UsuarioRepository,
    email: str | None = None,
    rol: RolUsuario = RolUsuario.ALUMNO,
) -> tuple[str, Usuario, bool]:
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

    token = crear_token_jwt(usuario_id=usuario.id, rol=usuario.rol)
    return token, usuario, is_new_user


# Genera un JWT de sesión invitada sin usuario ni credenciales
async def login_guest() -> str:
    return crear_token_jwt(
        usuario_id=None,
        rol=RolUsuario.ALUMNO.value,
        is_guest=True,
    )
