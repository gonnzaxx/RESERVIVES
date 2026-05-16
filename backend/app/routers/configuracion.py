import json
import shutil
import uuid as uuid_mod
from pathlib import Path
from typing import Dict, List
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy import select, update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.configuracion import Configuracion
from app.models.espacio import Espacio
from app.models.servicio import Servicio
from app.models.tramo_horario import TramoHorario
from app.models.usuario import RolUsuario, Usuario
from app.schemas.tramo import TramoHorarioCreate, TramoHorarioResponse, TramoHorarioUpdate
from app.services.tramo_service import TramoService
from app.utils.role_access import BackofficeSection

# Lista de modelos Gemini usada como fallback cuando la API no responde
_FALLBACK_MODELS = [
    "gemini-2.5-pro",
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.0-flash",
    "gemini-2.0-flash-lite",
    "gemini-1.5-flash",
    "gemini-1.5-pro",
]

router = APIRouter(prefix="/admin/configuracion", tags=["Configuracion"])


class ConfigItemUpdate(BaseModel):
    clave: str
    valor: str


class ConfigUpdateRequest(BaseModel):
    configs: List[ConfigItemUpdate]


# Claves que deben ser enteros positivos
_POSITIVE_INT_KEYS = {
    "tokens_iniciales_alumno",
    "tokens_iniciales_profesor",
    "tokens_recarga_mensual_alumno",
    "tokens_recarga_mensual_profesor",
    "tokens_por_recarga_alumno",
    "tokens_iniciales_nuevo_usuario",
    "dias_caducidad_anuncio_defecto",
    "antelacion_dias_defecto",
}

# Claves que deben ser booleanas
_BOOL_KEYS = {
    "se_permiten_reservas",
    "auth_dev_bypass_enabled",
    "ia_habilitada",
    "graph_email_enabled",
    "firebase_habilitado",
}

# Claves que deben contener JSON válido
_JSON_KEYS = {
    "dias_no_laborables",
}

# Claves que no se pueden actualizar desde la API (solo via .env o BD directa)
_BLOCKED_KEYS = {
    "gemini_api_key",
    "azure_client_id",
    "azure_tenant_id",
    "azure_client_secret",
    "azure_authority",
}

# Claves de configuración Azure/Microsoft Graph
_AZURE_CONFIG_KEYS = {
    "azure_client_id",
    "azure_tenant_id",
    "azure_client_secret",
    "azure_authority",
    "graph_email_enabled",
    "graph_from_email",
}

_MASKED_SECRET_VALUE = "********"

# Claves cuyo valor se enmascara al devolver al cliente
_SECRET_CONFIG_KEYS = {
    "azure_client_secret",
}


# Valida que el valor sea interpretable como booleano
def _is_valid_bool(value: str) -> bool:
    return value.strip().lower() in {
        "true",
        "false",
        "1",
        "0",
        "yes",
        "no",
        "on",
        "off",
        "si",
    }


# Enmascara el valor si la clave es un secreto
def _mask_config_value(clave: str, valor: str) -> str:
    if clave in _SECRET_CONFIG_KEYS and valor.strip():
        return _MASKED_SECRET_VALUE
    return valor


# Detecta si el cliente está intentando actualizar un secreto con el valor enmascarado (no-op)
def _is_masked_secret_update(clave: str, valor: str) -> bool:
    return clave in _SECRET_CONFIG_KEYS and valor.strip() in {"", _MASKED_SECRET_VALUE}


# Devuelve un mapa clave→valor de la BD, enmascarando secretos
async def _get_config_map(db: AsyncSession, keys: set[str] | None = None) -> Dict[str, str]:
    query = select(Configuracion)
    if keys is not None:
        query = query.where(Configuracion.clave.in_(keys))
    result = await db.execute(query)
    configs = result.scalars().all()
    return {c.clave: _mask_config_value(c.clave, c.valor) for c in configs}


# Devuelve todas las configuraciones del sistema
@router.get("", summary="Obtener todas las configuraciones")
async def get_configuracion(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, str]:
    return await _get_config_map(db)


# Actualiza múltiples configuraciones en una sola petición
@router.put("", summary="Actualizar configuraciones en lote")
async def update_configuracion(
    request: ConfigUpdateRequest,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    # Comprueba si la clave es de tokens por rol
    def _is_token_key(clave: str) -> bool:
        return clave.startswith("tokens_iniciales_") or clave.startswith("tokens_recarga_mensual_")

    # Validar todos los valores antes de persistir ninguno
    for item in request.configs:
        if item.clave in _BLOCKED_KEYS:
            continue
        if _is_masked_secret_update(item.clave, item.valor):
            continue
        raw = item.valor.strip()

        if item.clave in _POSITIVE_INT_KEYS or _is_token_key(item.clave):
            if not raw.isdigit() or int(raw) <= 0:
                raise HTTPException(
                    status_code=422,
                    detail=f"Valor invalido para '{item.clave}': debe ser entero positivo",
                )

        if item.clave in _BOOL_KEYS and not _is_valid_bool(raw):
            raise HTTPException(
                status_code=422,
                detail=f"Valor invalido para '{item.clave}': debe ser booleano",
            )

        if item.clave in _JSON_KEYS:
            try:
                json.loads(raw)
            except (ValueError, TypeError):
                raise HTTPException(
                    status_code=422,
                    detail=f"Valor invalido para '{item.clave}': debe ser JSON valido",
                )

    # Persistir los cambios
    for item in request.configs:
        if item.clave in _BLOCKED_KEYS:
            continue
        if _is_masked_secret_update(item.clave, item.valor):
            continue
        result = await db.execute(
            select(Configuracion).where(Configuracion.clave == item.clave)
        )
        config = result.scalar_one_or_none()
        if config:
            config.valor = item.valor.strip()
        else:
            db.add(Configuracion(clave=item.clave, valor=item.valor.strip()))

    # Si se cambia la antelación por defecto, propagarla a todos los espacios y servicios
    antelacion_item = next((i for i in request.configs if i.clave == "antelacion_dias_defecto"), None)
    if antelacion_item:
        dias = int(antelacion_item.valor.strip())
        await db.execute(sa_update(Espacio).values(antelacion_dias=dias))
        await db.execute(sa_update(Servicio).values(antelacion_dias=dias))

    await db.commit()
    return {"message": "Configuracion actualizada correctamente"}


# Devuelve la configuración de Azure/Microsoft Graph
@router.get("/azure", summary="Obtener configuracion Azure/Microsoft Graph")
async def get_azure_configuracion(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, str]:
    return await _get_config_map(db, _AZURE_CONFIG_KEYS)


# Actualiza la configuración de Azure/Microsoft Graph
@router.put("/azure", summary="Actualizar configuracion Azure/Microsoft Graph")
async def update_azure_configuracion(
    request: ConfigUpdateRequest,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
):
    invalid = [item.clave for item in request.configs if item.clave not in _AZURE_CONFIG_KEYS]
    if invalid:
        raise HTTPException(
            status_code=422,
            detail=f"Claves no permitidas en configuracion Azure: {', '.join(invalid)}",
        )

    for item in request.configs:
        if _is_masked_secret_update(item.clave, item.valor):
            continue
        raw = item.valor.strip()
        if item.clave in _BOOL_KEYS and not _is_valid_bool(raw):
            raise HTTPException(
                status_code=422,
                detail=f"Valor invalido para '{item.clave}': debe ser booleano",
            )

    for item in request.configs:
        if _is_masked_secret_update(item.clave, item.valor):
            continue
        result = await db.execute(
            select(Configuracion).where(Configuracion.clave == item.clave)
        )
        config = result.scalar_one_or_none()
        if config:
            config.valor = item.valor.strip()
        else:
            db.add(Configuracion(clave=item.clave, valor=item.valor.strip()))

    await db.commit()
    return {"message": "Configuracion Azure actualizada correctamente"}


# Consulta la API de Gemini para obtener los modelos disponibles con la API key configurada
# Si la llamada falla, devuelve la lista de fallback
@router.get("/gemini-models", summary="Obtener modelos Gemini disponibles para la API key configurada")
async def get_gemini_models(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    settings = get_settings()
    api_key = settings.GEMINI_API_KEY

    if api_key:
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                resp = await client.get(
                    "https://generativelanguage.googleapis.com/v1beta/models",
                    params={"key": api_key, "pageSize": 100},
                )
            if resp.status_code == 200:
                data = resp.json()
                models = [
                    m["name"].removeprefix("models/")
                    for m in data.get("models", [])
                    if "generateContent" in m.get("supportedGenerationMethods", [])
                ]
                if models:
                    return {"models": sorted(models), "source": "api"}
        except Exception:
            pass

    return {"models": _FALLBACK_MODELS, "source": "fallback"}


_LOGO_KEYS = {"logo_light_url", "logo_dark_url"}

# Claves de configuración expuestas públicamente (sin autenticación)
_PUBLIC_CONFIG_KEYS = {
    "logo_light_url",
    "logo_dark_url",
    "app_name",
    "app_primary_color",
    "app_default_theme",
    "app_contact_email",
    "app_contact_phone",
    "app_address",
    "ia_habilitada",
}


# Devuelve configuración pública de branding sin requerir autenticación
@router.get("/public", summary="Obtener configuracion publica (branding)")
async def get_public_config(
    db: AsyncSession = Depends(get_db),
) -> Dict[str, str]:
    result = await db.execute(
        select(Configuracion).where(Configuracion.clave.in_(_PUBLIC_CONFIG_KEYS))
    )
    configs = result.scalars().all()
    return {c.clave: c.valor for c in configs}


# Sube el logo de la app (variante light/dark) y guarda la URL en configuración
@router.post("/logo", summary="Subir logo de la aplicacion")
async def upload_logo(
    file: UploadFile = File(...),
    variant: str = "light",
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    if variant not in ("light", "dark"):
        raise HTTPException(status_code=422, detail="variant debe ser 'light' o 'dark'")

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="El archivo debe ser una imagen")

    upload_dir = Path("uploads/branding")
    upload_dir.mkdir(parents=True, exist_ok=True)

    extension = file.filename.split(".")[-1] if file.filename and "." in file.filename else "png"
    filename = f"logo_{variant}_{uuid_mod.uuid4().hex[:8]}.{extension}"
    file_path = upload_dir / filename

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    url = f"/api/uploads/branding/{filename}"
    clave = f"logo_{variant}_url"

    result = await db.execute(
        select(Configuracion).where(Configuracion.clave == clave)
    )
    config = result.scalar_one_or_none()
    if config:
        config.valor = url
    else:
        db.add(Configuracion(clave=clave, valor=url))

    await db.commit()
    return {"url": url, "clave": clave}


_AZURE_GROUP_PREFIX = "azure_group_"
_BACKOFFICE_SECTIONS_PREFIX = "backoffice_sections_"


class RolMappingResponse(BaseModel):
    role_name: str
    group_ids: list[str]
    backoffice_sections: list[str] = []


class RolMappingCreate(BaseModel):
    role_name: str
    group_ids: list[str]
    backoffice_sections: list[str] = []


class RolMappingUpdate(BaseModel):
    group_ids: list[str]
    backoffice_sections: list[str] = []


roles_router = APIRouter(prefix="/admin/configuracion/roles", tags=["Configuracion - Roles"])

# Secciones de backoffice por defecto para cada rol del sistema
_DEFAULT_SECTIONS: dict[str, list[str]] = {
    "ADMINISTRADOR": [s.value for s in BackofficeSection],
    "JEFATURA":      [
        s.value for s in BackofficeSection
        if s not in {BackofficeSection.CONFIGURATION, BackofficeSection.AZURE}
    ],
    "SECRETARIA":    ["metrics", "polls", "announcements", "incidents"],
    "GESTOR_SERVICIO": ["history", "bookings", "services", "metrics"],
    "CONTROL":       ["bookings", "history"],
    "CAFETERIA":     ["cafeteria"],
    "ALUMNO":        [],
    "PROFESOR":      [],
}


# Lista todos los mappings de roles Azure con sus grupos y secciones de backoffice
@roles_router.get("", response_model=list[RolMappingResponse], summary="Listar mappings de roles Azure")
async def listar_roles(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
):
    # Cargar grupos Azure por rol
    groups_result = await db.execute(
        select(Configuracion).where(Configuracion.clave.like(f"{_AZURE_GROUP_PREFIX}%"))
    )
    groups_map: dict[str, list[str]] = {
        c.clave.removeprefix(_AZURE_GROUP_PREFIX): [gid.strip() for gid in c.valor.split(",") if gid.strip()]
        for c in groups_result.scalars().all()
    }

    # Cargar secciones de backoffice por rol
    sections_result = await db.execute(
        select(Configuracion).where(Configuracion.clave.like(f"{_BACKOFFICE_SECTIONS_PREFIX}%"))
    )
    sections_map: dict[str, list[str]] = {
        c.clave.removeprefix(_BACKOFFICE_SECTIONS_PREFIX): [s.strip() for s in c.valor.split(",") if s.strip()]
        for c in sections_result.scalars().all()
    }

    seen: set[str] = set()
    roles: list[RolMappingResponse] = []

    # Primero los roles del sistema (en orden definido en _DEFAULT_SECTIONS)
    for role_name, default_sections in _DEFAULT_SECTIONS.items():
        seen.add(role_name)
        roles.append(RolMappingResponse(
            role_name=role_name,
            group_ids=groups_map.get(role_name, []),
            backoffice_sections=sections_map.get(role_name, default_sections),
        ))

    # Después los roles custom que solo existen en la BD
    for role_name, group_ids in groups_map.items():
        if role_name not in seen:
            roles.append(RolMappingResponse(
                role_name=role_name,
                group_ids=group_ids,
                backoffice_sections=sections_map.get(role_name, []),
            ))

    return roles


# Crea un nuevo mapping de grupo Azure para un rol
@roles_router.post("", response_model=RolMappingResponse, status_code=201, summary="Crear mapping de rol Azure")
async def crear_rol(
    body: RolMappingCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
):
    role_name = body.role_name.strip().upper()
    clave = f"{_AZURE_GROUP_PREFIX}{role_name}"
    existing = await db.execute(select(Configuracion).where(Configuracion.clave == clave))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail=f"Ya existe un mapping para el rol '{role_name}'")
    valor = ",".join(gid.strip() for gid in body.group_ids if gid.strip())
    db.add(Configuracion(clave=clave, valor=valor))

    # Guardar secciones de backoffice asignadas al rol
    sections_clave = f"{_BACKOFFICE_SECTIONS_PREFIX}{role_name}"
    sections_valor = ",".join(s.strip() for s in body.backoffice_sections if s.strip())
    db.add(Configuracion(clave=sections_clave, valor=sections_valor))

    await db.commit()
    clean_ids = [gid.strip() for gid in body.group_ids if gid.strip()]
    clean_sections = [s.strip() for s in body.backoffice_sections if s.strip()]
    return RolMappingResponse(role_name=role_name, group_ids=clean_ids, backoffice_sections=clean_sections)


# Actualiza los grupos Azure y secciones de backoffice de un rol existente
@roles_router.put("/{role_name}", response_model=RolMappingResponse, summary="Actualizar mapping de rol Azure")
async def actualizar_rol(
    role_name: str,
    body: RolMappingUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
):
    role_name = role_name.strip().upper()
    clave = f"{_AZURE_GROUP_PREFIX}{role_name}"
    result = await db.execute(select(Configuracion).where(Configuracion.clave == clave))
    config = result.scalar_one_or_none()
    if not config:
        raise HTTPException(status_code=404, detail=f"No existe mapping para el rol '{role_name}'")
    config.valor = ",".join(gid.strip() for gid in body.group_ids if gid.strip())

    # Actualizar secciones de backoffice del rol
    sections_clave = f"{_BACKOFFICE_SECTIONS_PREFIX}{role_name}"
    sections_result = await db.execute(select(Configuracion).where(Configuracion.clave == sections_clave))
    sections_config = sections_result.scalar_one_or_none()
    sections_valor = ",".join(s.strip() for s in body.backoffice_sections if s.strip())
    if sections_config:
        sections_config.valor = sections_valor
    else:
        db.add(Configuracion(clave=sections_clave, valor=sections_valor))

    await db.commit()
    clean_ids = [gid.strip() for gid in body.group_ids if gid.strip()]
    clean_sections = [s.strip() for s in body.backoffice_sections if s.strip()]
    return RolMappingResponse(role_name=role_name, group_ids=clean_ids, backoffice_sections=clean_sections)


# Elimina el mapping Azure de un rol
# Los roles del sistema no se eliminan del todo: solo se borra su grupo Azure
# Los roles custom se eliminan completamente y sus usuarios pasan a ALUMNO
@roles_router.delete("/{role_name}", status_code=204, summary="Eliminar mapping de rol Azure")
async def eliminar_rol(
    role_name: str,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.AZURE)),
    db: AsyncSession = Depends(get_db),
):
    role_name = role_name.strip().upper()

    if role_name in _DEFAULT_SECTIONS:
        # Para roles del sistema solo borramos la entrada azure_group de la BD
        clave = f"{_AZURE_GROUP_PREFIX}{role_name}"
        result = await db.execute(select(Configuracion).where(Configuracion.clave == clave))
        config = result.scalar_one_or_none()
        if config:
            await db.delete(config)
        await db.commit()
        return

    clave = f"{_AZURE_GROUP_PREFIX}{role_name}"
    result = await db.execute(select(Configuracion).where(Configuracion.clave == clave))
    config = result.scalar_one_or_none()
    if not config:
        raise HTTPException(status_code=404, detail=f"No existe mapping para el rol '{role_name}'")
    await db.delete(config)

    # Eliminar también las secciones de backoffice del rol custom
    sections_clave = f"{_BACKOFFICE_SECTIONS_PREFIX}{role_name}"
    sections_result = await db.execute(select(Configuracion).where(Configuracion.clave == sections_clave))
    sections_config = sections_result.scalar_one_or_none()
    if sections_config:
        await db.delete(sections_config)

    # Los usuarios con este rol custom pasan a ALUMNO
    await db.execute(
        sa_update(Usuario).where(Usuario.rol == role_name).values(rol=RolUsuario.ALUMNO.value)
    )

    await db.commit()


# Devuelve las secciones de backoffice configuradas por rol; sin autenticación requerida
@router.get("/role-sections", summary="Secciones de backoffice por rol (publico)")
async def get_role_sections(db: AsyncSession = Depends(get_db)) -> Dict[str, list[str]]:
    result = await db.execute(
        select(Configuracion).where(Configuracion.clave.like(f"{_BACKOFFICE_SECTIONS_PREFIX}%"))
    )
    configs = result.scalars().all()
    return {
        c.clave.removeprefix(_BACKOFFICE_SECTIONS_PREFIX): [s.strip() for s in c.valor.split(",") if s.strip()]
        for c in configs
    }


tramos_router = APIRouter(prefix="/admin/configuracion/tramos", tags=["Configuracion - Tramos"])


# Devuelve todos los tramos (activos e inactivos) para gestión en backoffice
@tramos_router.get("", response_model=list[TramoHorarioResponse], summary="Listar todos los tramos (admin)")
async def listar_tramos_admin(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    service = TramoService(db)
    tramos = await service.get_todos_los_tramos_admin()
    return [TramoHorarioResponse.model_validate(t) for t in tramos]


# Crea un nuevo tramo horario en el catálogo global
@tramos_router.post("", response_model=TramoHorarioResponse, status_code=201, summary="Crear tramo")
async def crear_tramo(
    body: TramoHorarioCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    service = TramoService(db)
    try:
        tramo = await service.crear_tramo(body.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return TramoHorarioResponse.model_validate(tramo)


# Edita campos de un tramo existente; puede usarse para activar o desactivar
@tramos_router.patch("/{tramo_id}", response_model=TramoHorarioResponse, summary="Editar tramo")
async def editar_tramo(
    tramo_id: UUID,
    body: TramoHorarioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    service = TramoService(db)
    datos = body.model_dump(exclude_none=True)
    if not datos:
        raise HTTPException(status_code=422, detail="No se han enviado campos a actualizar")
    try:
        tramo = await service.actualizar_tramo(tramo_id, datos)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return TramoHorarioResponse.model_validate(tramo)


# Elimina permanentemente el tramo horario de la base de datos
@tramos_router.delete("/{tramo_id}", status_code=204, summary="Eliminar tramo")
async def eliminar_tramo(
    tramo_id: UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    service = TramoService(db)
    try:
        await service.eliminar_tramo(tramo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
