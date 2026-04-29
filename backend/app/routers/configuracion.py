from typing import Dict, List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.configuracion import Configuracion
from app.models.usuario import Usuario
from app.utils.role_access import BackofficeSection

router = APIRouter(prefix="/admin/configuracion", tags=["Configuracion"])


class ConfigItemUpdate(BaseModel):
    clave: str
    valor: str


class ConfigUpdateRequest(BaseModel):
    configs: List[ConfigItemUpdate]


_POSITIVE_INT_KEYS = {
    "tokens_iniciales_alumno",
    "tokens_iniciales_profesor",
    "tokens_recarga_mensual_alumno",
    "tokens_recarga_mensual_profesor",
    "tokens_por_recarga_alumno",
    "tokens_iniciales_nuevo_usuario",
    "dias_caducidad_anuncio_defecto",
}

_BOOL_KEYS = {
    "smtp_enabled",
    "se_permiten_reservas",
    "auth_dev_bypass_enabled",
}


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


@router.get("", summary="Obtener todas las configuraciones")
async def get_configuracion(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, str]:
    result = await db.execute(select(Configuracion))
    configs = result.scalars().all()
    return {c.clave: c.valor for c in configs}


@router.put("", summary="Actualizar configuraciones en lote")
async def update_configuracion(
    request: ConfigUpdateRequest,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    for item in request.configs:
        raw = item.valor.strip()

        if item.clave in _POSITIVE_INT_KEYS:
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

    for item in request.configs:
        result = await db.execute(
            select(Configuracion).where(Configuracion.clave == item.clave)
        )
        config = result.scalar_one_or_none()
        if config:
            config.valor = item.valor.strip()
        else:
            db.add(Configuracion(clave=item.clave, valor=item.valor.strip()))

    await db.commit()
    return {"message": "Configuracion actualizada correctamente"}
