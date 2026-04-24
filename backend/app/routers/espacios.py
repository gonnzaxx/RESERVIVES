import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_backoffice_section
from app.models.espacio import Espacio, TipoEspacio
from app.models.notificacion import TipoNotificacion
from app.models.usuario import Usuario
from app.repositories.espacio_repo import EspacioRepository
from app.schemas.espacio import EspacioCreate, EspacioResponse, EspacioUpdate
from app.services.notification_service import NotificationService
from app.services.websocket_manager import admin_ws_manager
from app.utils.role_access import BackofficeSection

router = APIRouter(prefix="/espacios", tags=["Espacios"])

def map_espacio_to_response(e: Espacio) -> EspacioResponse:
    return EspacioResponse(
        id=e.id,
        nombre=e.nombre,
        descripcion=e.descripcion,
        imagen_url=e.imagen_url,
        tipo=e.tipo,
        precio_tokens=e.precio_tokens,
        reservable=e.reservable,
        requiere_autorizacion=e.requiere_autorizacion,
        antelacion_dias=e.antelacion_dias,
        ubicacion=e.ubicacion,
        capacidad=e.capacidad,
        activo=e.activo,
        roles_permitidos=[
            rp.rol.value if hasattr(rp.rol, "value") else str(rp.rol)
            for rp in (e.roles_permitidos or [])
        ],
        created_at=e.created_at,
        updated_at=e.updated_at,
    )

@router.get("/", response_model=list[EspacioResponse], summary="Listar espacios")
async def listar_espacios(
    tipo: TipoEspacio | None = None,
    solo_reservables: bool = False,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista los espacios. Se puede filtrar por tipo (PISTA/AULA) y por reservabilidad."""
    repo = EspacioRepository(db)

    if tipo:
        espacios = await repo.get_by_tipo(tipo)
    elif solo_reservables:
        espacios = await repo.get_reservables()
    else:
        espacios = await repo.get_all()

    return [map_espacio_to_response(e) for e in espacios]


@router.get("/{espacio_id}", response_model=EspacioResponse, summary="Obtener un espacio")
async def obtener_espacio(
    espacio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene los datos completos de un espacio."""
    repo = EspacioRepository(db)
    espacio = await repo.get_by_id_with_roles(espacio_id)
    if not espacio:
        raise HTTPException(status_code=404, detail="Espacio no encontrado")

    return map_espacio_to_response(espacio)


@router.post("/", response_model=EspacioResponse, status_code=201, summary="Crear un espacio")
async def crear_espacio(
    data: EspacioCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo espacio. Solo admin."""
    repo = EspacioRepository(db)

    espacio = Espacio(
        nombre=data.nombre,
        descripcion=data.descripcion,
        imagen_url=data.imagen_url,
        tipo=data.tipo,
        precio_tokens=data.precio_tokens,
        reservable=data.reservable,
        requiere_autorizacion=data.requiere_autorizacion,
        antelacion_dias=data.antelacion_dias,
        ubicacion=data.ubicacion,
        capacidad=data.capacidad,
    )
    espacio = await repo.create(espacio)

    # Asignar roles permitidos
    roles = [r.value for r in data.roles_permitidos]
    await repo.set_roles_permitidos(espacio.id, roles)
    espacio = await repo.get_by_id_with_roles(espacio.id)

    notification_service = NotificationService(db)
    await notification_service.broadcast_to_all(
        tipo=TipoNotificacion.NUEVO_ESPACIO,
        titulo="Nuevo espacio disponible",
        mensaje=f"Se ha añadido el espacio: {espacio.nombre}",
        referencia_id=str(espacio.id),
    )
    await admin_ws_manager.broadcast_admin({"event": "espacio_created"})
    return map_espacio_to_response(espacio)



@router.put("/{espacio_id}", response_model=EspacioResponse, summary="Actualizar un espacio")
async def actualizar_espacio(
    espacio_id: uuid.UUID,
    data: EspacioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza un espacio existente. Solo admin."""
    repo = EspacioRepository(db)
    espacio = await repo.get_by_id_with_roles(espacio_id)
    if not espacio:
        raise HTTPException(status_code=404, detail="Espacio no encontrado")

    update_data = data.model_dump(exclude_unset=True, exclude={"roles_permitidos"})
    espacio = await repo.update(espacio, update_data)

    # Actualizar roles si se proporcionan
    if data.roles_permitidos is not None:
        roles = [r.value for r in data.roles_permitidos]
        await repo.set_roles_permitidos(espacio.id, roles)

    espacio = await repo.get_by_id_with_roles(espacio.id)
    await admin_ws_manager.broadcast_admin({"event": "espacio_updated"})
    return map_espacio_to_response(espacio)


@router.delete("/{espacio_id}", summary="Eliminar un espacio")
async def eliminar_espacio(
    espacio_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un espacio. Solo admin."""
    repo = EspacioRepository(db)
    espacio = await repo.get_by_id(espacio_id)
    if not espacio:
        raise HTTPException(status_code=404, detail="Espacio no encontrado")
    nombre = espacio.nombre
    await repo.delete(espacio)
    await admin_ws_manager.broadcast_admin({"event": "espacio_deleted"})
    return {"message": f"Espacio '{nombre}' eliminado correctamente"}
