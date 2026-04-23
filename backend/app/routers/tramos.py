"""
RESERVIVES - Router de Tramos Horarios.

Endpoints para consulta de tramos, disponibilidad y configuración
de qué tramos tiene permitidos cada espacio/servicio.
"""

from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_admin
from app.models.usuario import Usuario
from app.schemas.tramo import TramoHorarioResponse, TramoDisponibilidadResponse
from app.services.tramo_service import TramoService

router = APIRouter(prefix="/tramos", tags=["Tramos Horarios"])


# Endpoints públicos (cualquier usuario autenticado) 

@router.get("/", response_model=list[TramoHorarioResponse], summary="Listar todos los tramos")
async def listar_tramos(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Devuelve el catálogo completo de tramos horarios activos del instituto."""
    service = TramoService(db)
    tramos = await service.get_todos_los_tramos()
    return [TramoHorarioResponse.model_validate(t) for t in tramos]


@router.get(
    "/disponibilidad/espacio/{espacio_id}",
    response_model=list[TramoDisponibilidadResponse],
    summary="Disponibilidad de tramos para un espacio",
)
async def disponibilidad_espacio(
    espacio_id: UUID,
    fecha: date,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Devuelve todos los tramos del día con estado (disponible/reservado/no permitido)
    para un espacio concreto. Usado por el BookingScreen de Flutter.
    """
    service = TramoService(db)
    return await service.get_disponibilidad_espacio(espacio_id, fecha)


@router.get(
    "/disponibilidad/servicio/{servicio_id}",
    response_model=list[TramoDisponibilidadResponse],
    summary="Disponibilidad de tramos para un servicio",
)
async def disponibilidad_servicio(
    servicio_id: UUID,
    fecha: date,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Disponibilidad de tramos para un servicio en una fecha concreta."""
    service = TramoService(db)
    return await service.get_disponibilidad_servicio(servicio_id, fecha)


# Endpoints de consulta de configuración (admin)

@router.get(
    "/espacio/{espacio_id}/tramos-permitidos",
    response_model=list[UUID],
    summary="Obtener tramos configurados para un espacio",
)
async def get_tramos_espacio(
    espacio_id: UUID,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Devuelve los IDs de tramos habilitados para un espacio.
    Lista vacía = todos los tramos están permitidos.
    """
    service = TramoService(db)
    return await service.get_tramos_permitidos_espacio(espacio_id)


@router.get(
    "/servicio/{servicio_id}/tramos-permitidos",
    response_model=list[UUID],
    summary="Obtener tramos configurados para un servicio",
)
async def get_tramos_servicio(
    servicio_id: UUID,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Devuelve los IDs de tramos habilitados para un servicio.
    Lista vacía = todos los tramos están permitidos.
    """
    service = TramoService(db)
    return await service.get_tramos_permitidos_servicio(servicio_id)


# Endpoints de configuración (solo admin) 

@router.put(
    "/espacio/{espacio_id}/tramos-permitidos",
    summary="Configurar tramos permitidos para un espacio",
)
async def configurar_tramos_espacio(
    espacio_id: UUID,
    tramo_ids: list[UUID],
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Admin: configura qué tramos puede reservar un espacio.
    - Lista vacía → todos los tramos permitidos (sin restricción)
    - Lista con IDs → solo esos tramos disponibles
    """
    service = TramoService(db)
    await service.configurar_tramos_espacio(espacio_id, tramo_ids)
    return {"message": f"Configurados {len(tramo_ids)} tramos para el espacio"}


@router.put(
    "/servicio/{servicio_id}/tramos-permitidos",
    summary="Configurar tramos permitidos para un servicio",
)
async def configurar_tramos_servicio(
    servicio_id: UUID,
    tramo_ids: list[UUID],
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Admin: configura qué tramos puede reservar un servicio.
    - Lista vacía → todos los tramos permitidos
    - Lista con IDs → solo esos tramos disponibles
    """
    service = TramoService(db)
    await service.configurar_tramos_servicio(servicio_id, tramo_ids)
    return {"message": f"Configurados {len(tramo_ids)} tramos para el servicio"}
