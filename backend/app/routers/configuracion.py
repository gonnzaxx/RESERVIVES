from typing import Dict, List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.configuracion import Configuracion
from app.models.usuario import Usuario
from app.utils.role_access import BackofficeSection
from app.models.tramo_horario import TramoHorario
from app.schemas.tramo import TramoHorarioResponse, TramoHorarioCreate, TramoHorarioUpdate
from app.services.tramo_service import TramoService

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

tramos_router = APIRouter(prefix="/admin/configuracion/tramos", tags=["Configuracion - Tramos"])


@tramos_router.get("", response_model=list[TramoHorarioResponse], summary="Listar todos los tramos (admin)")
async def listar_tramos_admin(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    """Devuelve todos los tramos (activos e inactivos) para gestión en backoffice."""
    service = TramoService(db)
    tramos = await service.get_todos_los_tramos_admin()
    return [TramoHorarioResponse.model_validate(t) for t in tramos]


@tramos_router.post("", response_model=TramoHorarioResponse, status_code=201, summary="Crear tramo")
async def crear_tramo(
    body: TramoHorarioCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo tramo horario en el catálogo global."""
    service = TramoService(db)
    try:
        tramo = await service.crear_tramo(body.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return TramoHorarioResponse.model_validate(tramo)


@tramos_router.patch("/{tramo_id}", response_model=TramoHorarioResponse, summary="Editar tramo")
async def editar_tramo(
    tramo_id: UUID,
    body: TramoHorarioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    """Edita campos de un tramo existente. Puede usarse para activar/desactivar."""
    service = TramoService(db)
    datos = body.model_dump(exclude_none=True)
    if not datos:
        raise HTTPException(status_code=422, detail="No se han enviado campos a actualizar")
    try:
        tramo = await service.actualizar_tramo(tramo_id, datos)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return TramoHorarioResponse.model_validate(tramo)


@tramos_router.delete("/{tramo_id}", status_code=204, summary="Eliminar tramo")
async def eliminar_tramo(
    tramo_id: UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CONFIGURATION)),
    db: AsyncSession = Depends(get_db),
):
    """Elimina permanentemente el tramo horario de la base de datos."""
    service = TramoService(db)
    try:
        await service.eliminar_tramo(tramo_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))