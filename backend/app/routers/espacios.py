import uuid
from datetime import date as date_type, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    get_optional_current_user,
    require_backoffice_section,
)
from app.models.espacio import Espacio, TipoEspacio
from app.models.notificacion import TipoNotificacion
from app.models.usuario import Usuario
from app.repositories.espacio_repo import EspacioRepository
from app.schemas.espacio import EspacioCreate, EspacioResponse, EspacioUpdate
from app.schemas.reserva import CalendarioDiaResponse
from app.services.notification_service import NotificationService
from app.services.tramo_service import TramoService
from app.services.websocket_manager import admin_ws_manager
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/espacios", tags=["Espacios"])


# Convierte un modelo Espacio a su schema de respuesta aplanando la lista de roles.
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


# Lista los espacios. Admite filtros por tipo (PISTA/AULA) y por reservabilidad.
# Para ver espacios inactivos se necesitan permisos de backoffice.
@router.get("/", response_model=list[EspacioResponse], summary="Listar espacios")
async def listar_espacios(
    tipo: TipoEspacio | None = None,
    solo_reservables: bool = False,
    incluir_inactivos: bool = False,
    current_user: Usuario | None = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    repo = EspacioRepository(db)
    solo_activos = True

    if incluir_inactivos:
        if not current_user or not can_access_backoffice_section(
            current_user.rol, BackofficeSection.SPACES
        ):
            raise HTTPException(status_code=403, detail="No tienes permisos para incluir espacios inactivos")
        solo_activos = False

    if tipo:
        espacios = await repo.get_by_tipo(tipo, solo_activos=solo_activos)
    elif solo_reservables:
        espacios = await repo.get_reservables(solo_activos=solo_activos)
    else:
        espacios = await repo.get_all(solo_activos=solo_activos)

    return [map_espacio_to_response(e) for e in espacios]


# Devuelve los datos completos de un espacio, incluidos los roles con acceso.
@router.get("/{espacio_id}", response_model=EspacioResponse, summary="Obtener un espacio")
async def obtener_espacio(
    espacio_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    repo = EspacioRepository(db)
    espacio = await repo.get_by_id_with_roles(espacio_id)
    if not espacio:
        raise HTTPException(status_code=404, detail="Espacio no encontrado")

    return map_espacio_to_response(espacio)


# Crea un nuevo espacio y asigna los roles permitidos.
# Notifica a todos los usuarios del nuevo espacio disponible. Solo admin.
@router.post("/", response_model=EspacioResponse, status_code=201, summary="Crear un espacio")
async def crear_espacio(
    data: EspacioCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
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


# Actualiza los datos de un espacio. Si se pasan roles_permitidos, los reemplaza por completo. Solo admin.
@router.put("/{espacio_id}", response_model=EspacioResponse, summary="Actualizar un espacio")
async def actualizar_espacio(
    espacio_id: uuid.UUID,
    data: EspacioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
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


# Devuelve la disponibilidad de tramos día a día para un espacio entre dos fechas.
# Máximo 14 días por petición.
@router.get("/{espacio_id}/calendario", summary="Disponibilidad semanal de un espacio")
async def calendario_disponibilidad(
    espacio_id: uuid.UUID,
    fecha_inicio: str,
    fecha_fin: str,
    current_user: Usuario | None = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        inicio = date_type.fromisoformat(fecha_inicio)
        fin = date_type.fromisoformat(fecha_fin)
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de fecha inválido (YYYY-MM-DD)")

    if fin < inicio:
        raise HTTPException(status_code=400, detail="fecha_fin debe ser posterior a fecha_inicio")
    if (fin - inicio).days > 13:
        raise HTTPException(status_code=400, detail="El rango máximo es de 14 días")

    tramo_svc = TramoService(db)
    dias: list[CalendarioDiaResponse] = []
    nombres_dia = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

    cursor = inicio
    while cursor <= fin:
        tramos = await tramo_svc.get_disponibilidad_espacio(espacio_id, cursor)
        dias.append(
            CalendarioDiaResponse(
                fecha=cursor,
                dia_semana=nombres_dia[cursor.weekday()],
                tramos=tramos,
            )
        )
        cursor += timedelta(days=1)

    return dias


# Elimina un espacio del sistema. Solo admin.
@router.delete("/{espacio_id}", summary="Eliminar un espacio")
async def eliminar_espacio(
    espacio_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.SPACES)),
    db: AsyncSession = Depends(get_db),
):
    repo = EspacioRepository(db)
    espacio = await repo.get_by_id(espacio_id)
    if not espacio:
        raise HTTPException(status_code=404, detail="Espacio no encontrado")
    nombre = espacio.nombre
    await repo.delete(espacio)
    await admin_ws_manager.broadcast_admin({"event": "espacio_deleted"})
    return {"message": f"Espacio '{nombre}' eliminado correctamente"}
