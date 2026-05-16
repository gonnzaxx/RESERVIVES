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


# Convierte un modelo Servicio a su schema de respuesta, aplanando la lista de roles.
def _map_servicio(s: Servicio) -> ServicioResponse:
    return ServicioResponse(
        id=s.id,
        nombre=s.nombre,
        descripcion=s.descripcion,
        imagen_url=s.imagen_url,
        ubicacion=s.ubicacion,
        horario=s.horario,
        precio_tokens=s.precio_tokens,
        antelacion_dias=s.antelacion_dias,
        activo=s.activo,
        orden=s.orden,
        gestor_usuario_id=s.gestor_usuario_id,
        gestor=s.gestor,
        roles_permitidos=[
            rp.rol.value if hasattr(rp.rol, "value") else str(rp.rol)
            for rp in (s.roles_permitidos or [])
        ],
        created_at=s.created_at,
        updated_at=s.updated_at,
    )


# Lista los servicios activos visibles para los usuarios.
@router.get("/", response_model=list[ServicioResponse], summary="Listar servicios")
async def listar_servicios(
        db: AsyncSession = Depends(get_db),
):
    repo = ServicioRepository(db)
    servicios = await repo.get_activos()
    return [_map_servicio(s) for s in servicios]


# Lista todos los servicios incluyendo los inactivos. Solo admin.
@router.get("/todos", response_model=list[ServicioResponse], summary="Listar todos los servicios")
async def listar_todos_servicios(
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    repo = ServicioRepository(db)
    servicios = await repo.get_all()
    return [_map_servicio(s) for s in servicios]


# Crea un nuevo servicio y asigna los roles con acceso.
# Notifica a todos los usuarios del nuevo servicio. Solo admin.
@router.post("/", response_model=ServicioResponse, status_code=201, summary="Crear servicio")
async def crear_servicio(
        data: ServicioCreate,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    repo = ServicioRepository(db)
    create_data = data.model_dump(exclude={"roles_permitidos"})
    servicio = Servicio(**create_data)
    servicio = await repo.create(servicio)
    await repo.set_roles_permitidos(servicio.id, data.roles_permitidos)
    servicio = await repo.get_by_id(servicio.id)
    notification_service = NotificationService(db)
    await notification_service.broadcast_to_all(
        tipo=TipoNotificacion.NUEVO_SERVICIO,
        titulo="Nuevo servicio disponible",
        mensaje=f"Se ha añadido el servicio: {servicio.nombre}",
        referencia_id=str(servicio.id),
    )
    return _map_servicio(servicio)


# Actualiza los datos de un servicio. Si se pasan roles_permitidos, los reemplaza por completo. Solo admin.
@router.put("/{servicio_id}", response_model=ServicioResponse, summary="Actualizar servicio")
async def actualizar_servicio(
        servicio_id: uuid.UUID,
        data: ServicioUpdate,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    update_data = data.model_dump(exclude_unset=True, exclude={"roles_permitidos"})
    servicio = await repo.update(servicio, update_data)
    if data.roles_permitidos is not None:
        await repo.set_roles_permitidos(servicio.id, data.roles_permitidos)
    servicio = await repo.get_by_id(servicio.id)
    return _map_servicio(servicio)


# Elimina un servicio del sistema. Solo admin.
@router.delete("/{servicio_id}", summary="Eliminar servicio")
async def eliminar_servicio(
        servicio_id: uuid.UUID,
        admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SERVICES)),
        db: AsyncSession = Depends(get_db),
):
    repo = ServicioRepository(db)
    servicio = await repo.get_by_id(servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    nombre = servicio.nombre
    await repo.delete(servicio)
    return {"message": f"Servicio '{nombre}' eliminado correctamente"}
