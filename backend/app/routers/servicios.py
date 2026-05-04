import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.notificacion import TipoNotificacion
from app.models.servicio import Servicio
from app.models.usuario import Usuario
from app.repositories.servicio_repo import ServicioRepository
from app.schemas.servicio import ServicioCreate, ServicioResponse, ServicioUpdate
from app.services.notification_service import NotificationService
from app.utils.role_access import BackofficeSection

router = APIRouter(prefix="/servicios", tags=["Servicios"])


# --- SERVICIOS ---
@router.get("/", response_model=list[ServicioResponse], summary="Listar servicios")
async def listar_servicios(
        db: AsyncSession = Depends(get_db),
):
    """Lista todos los servicios activos del instituto."""
    repo = ServicioRepository(db)
    servicios = await repo.get_activos()
    return [ServicioResponse.model_validate(s) for s in servicios]


@router.get("/todos", response_model=list[ServicioResponse], summary="Listar todos los servicios")
async def listar_todos_servicios(
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    """Lista todos los servicios (incluidos inactivos). Solo admin."""
    repo = ServicioRepository(db)
    servicios = await repo.get_all()
    return [ServicioResponse.model_validate(s) for s in servicios]


@router.post("/", response_model=ServicioResponse, status_code=201, summary="Crear servicio")
async def crear_servicio(
        data: ServicioCreate,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo servicio. Solo admin."""
    repo = ServicioRepository(db)
    servicio = Servicio(**data.model_dump())
    servicio = await repo.create(servicio)
    servicio = await repo.get_by_id(servicio.id)
    notification_service = NotificationService(db)
    await notification_service.broadcast_to_all(
        tipo=TipoNotificacion.NUEVO_SERVICIO,
        titulo="Nuevo servicio disponible",
        mensaje=f"Se ha añadido el servicio: {servicio.nombre}",
        referencia_id=str(servicio.id),
    )
    return ServicioResponse.model_validate(servicio)


@router.put("/{servicio_id}", response_model=ServicioResponse, summary="Actualizar servicio")
async def actualizar_servicio(
        servicio_id: uuid.UUID,
        data: ServicioUpdate,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    """Actualiza un servicio. Solo admin."""
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    update_data = data.model_dump(exclude_unset=True)
    servicio = await repo.update(servicio, update_data)
    servicio = await repo.get_by_id(servicio.id)
    return ServicioResponse.model_validate(servicio)


@router.delete("/{servicio_id}", summary="Eliminar servicio")
async def eliminar_servicio(
        servicio_id: uuid.UUID,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    """Elimina un servicio. Solo admin."""
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    nombre = servicio.nombre
    await repo.delete(servicio)
    return {"message": f"Servicio '{nombre}' eliminado correctamente"}
