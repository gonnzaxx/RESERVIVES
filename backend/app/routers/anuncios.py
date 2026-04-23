import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_admin
from app.models.anuncio import Anuncio
from app.models.notificacion import TipoNotificacion
from app.models.usuario import Usuario
from app.repositories.anuncio_repo import AnuncioRepository
from app.repositories.analytics_repo import AnalyticsRepository
from app.schemas.anuncio import AnuncioCreate, AnuncioResponse, AnuncioUpdate
from app.services.notification_service import NotificationService
from app.services.websocket_manager import admin_ws_manager

router = APIRouter(prefix="/anuncios", tags=["Anuncios"])


@router.get("/", response_model=list[AnuncioResponse], summary="Listar anuncios activos")
async def listar_anuncios(
    skip: int = 0,
    limit: int = 50,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista los anuncios activos y no expirados. Destacados primero."""
    repo = AnuncioRepository(db)
    anuncios = await repo.get_activos(skip, limit)
    result = []
    for a in anuncios:
        resp = AnuncioResponse.model_validate(a)
        if a.autor:
            resp.nombre_autor = f"{a.autor.nombre} {a.autor.apellidos}"
        result.append(resp)
    return result


@router.get("/todos", response_model=list[AnuncioResponse], summary="Listar todos los anuncios")
async def listar_todos_anuncios(
    skip: int = 0,
    limit: int = 50,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los anuncios (incluidos inactivos). Solo admin."""
    repo = AnuncioRepository(db)
    anuncios = await repo.get_all_with_autor(skip, limit)
    result = []
    for a in anuncios:
        resp = AnuncioResponse.model_validate(a)
        if a.autor:
            resp.nombre_autor = f"{a.autor.nombre} {a.autor.apellidos}"
        result.append(resp)
    return result


@router.get("/{anuncio_id}", response_model=AnuncioResponse, summary="Obtener un anuncio")
async def obtener_anuncio(
    anuncio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtiene un anuncio especÃ­fico."""
    repo = AnuncioRepository(db)
    anuncio = await repo.get_by_id(anuncio_id)
    if not anuncio:
        raise HTTPException(status_code=404, detail="Anuncio no encontrado")
    return AnuncioResponse.model_validate(anuncio)


@router.post("/", response_model=AnuncioResponse, status_code=201, summary="Crear un anuncio")
async def crear_anuncio(
    data: AnuncioCreate,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo anuncio. Solo admin."""
    repo = AnuncioRepository(db)
    anuncio = Anuncio(
        autor_id=admin.id,
        titulo=data.titulo,
        contenido=data.contenido,
        imagen_url=data.imagen_url,
        destacado=data.destacado,
        fecha_expiracion=data.fecha_expiracion,
    )
    anuncio = await repo.create(anuncio)
    notification_service = NotificationService(db)
    await notification_service.broadcast_to_all(
        tipo=TipoNotificacion.NUEVO_ANUNCIO,
        titulo="Nuevo anuncio publicado",
        mensaje=f"Se ha publicado: {anuncio.titulo}",
        referencia_id=str(anuncio.id),
    )
    await admin_ws_manager.broadcast_admin({"event": "anuncio_created"})
    return AnuncioResponse.model_validate(anuncio)


@router.put("/{anuncio_id}", response_model=AnuncioResponse, summary="Actualizar un anuncio")
async def actualizar_anuncio(
    anuncio_id: uuid.UUID,
    data: AnuncioUpdate,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza un anuncio existente. Solo admin."""
    repo = AnuncioRepository(db)
    anuncio = await repo.get_by_id(anuncio_id)
    if not anuncio:
        raise HTTPException(status_code=404, detail="Anuncio no encontrado")

    update_data = data.model_dump(exclude_unset=True)
    anuncio = await repo.update(anuncio, update_data)
    await admin_ws_manager.broadcast_admin({"event": "anuncio_updated"})
    return AnuncioResponse.model_validate(anuncio)


@router.delete("/{anuncio_id}", summary="Eliminar un anuncio")
async def eliminar_anuncio(
    anuncio_id: uuid.UUID,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un anuncio. Solo admin."""
    repo = AnuncioRepository(db)
    anuncio = await repo.get_by_id(anuncio_id)
    if not anuncio:
        raise HTTPException(status_code=404, detail="Anuncio no encontrado")
    await repo.delete(anuncio)
    await admin_ws_manager.broadcast_admin({"event": "anuncio_deleted"})
    return {"message": f"Anuncio '{anuncio.titulo}' eliminado correctamente"}


@router.post("/{anuncio_id}/view", status_code=204, summary="Registrar visualización")
async def registrar_vista(
    anuncio_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """Registra que un usuario ha visto un anuncio."""
    repo = AnalyticsRepository(db)
    await repo.register_view(anuncio_id, current_user.id)
    await db.commit()
