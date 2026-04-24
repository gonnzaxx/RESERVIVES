import os
import uuid
import shutil
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_backoffice_section
from app.models.usuario import Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.schemas.usuario import UsuarioResponse, UsuarioUpdate
from app.services.token_service import TokenService
from app.services.websocket_manager import admin_ws_manager
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])


@router.get("/", response_model=list[UsuarioResponse], summary="Listar todos los usuarios")
async def listar_usuarios(
    skip: int = 0,
    limit: int = 100,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los usuarios registrados. Solo admin."""
    from app.config import get_settings
    settings = get_settings()

    repo = UsuarioRepository(db)
    usuarios = await repo.get_all(skip=skip, limit=limit)
    return [UsuarioResponse.model_validate(u) for u in usuarios]


@router.get("/{usuario_id}", response_model=UsuarioResponse, summary="Obtener un usuario")
async def obtener_usuario(
    usuario_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Obtiene los datos de un usuario. 
    Los alumnos y profesores solo pueden ver su propio perfil.
    El admin puede ver cualquier usuario.
    """
    # Los no-admin solo pueden verse a sÃ­ mismos
    can_view_users = can_access_backoffice_section(current_user.rol, BackofficeSection.USERS)
    if not can_view_users and current_user.id != usuario_id:
        raise HTTPException(status_code=403, detail="Solo puedes ver tu propio perfil")

    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return UsuarioResponse.model_validate(usuario)


@router.post("/me/avatar", response_model=UsuarioResponse, summary="Subir avatar de usuario")
async def subir_avatar(
    file: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Sube un avatar para el usuario logueado."""
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="El archivo debe ser una imagen")

    # Crear el directorio si no existe
    upload_dir = Path("uploads/avatars")
    upload_dir.mkdir(parents=True, exist_ok=True)

    # Generar un nombre seguro
    extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{current_user.id}_{uuid.uuid4().hex[:8]}.{extension}"
    file_path = upload_dir / filename

    # Guardar archivo
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Actualizar DB
    from app.config import get_settings
    settings = get_settings()
    repo = UsuarioRepository(db)
    avatar_url = f"{settings.APP_HOST}:{settings.APP_PORT}/api/uploads/avatars/{filename}" if settings.APP_DEBUG else f"/api/uploads/avatars/{filename}"
    # Formato path relativo, Flutter puede reconstruirlo usando base_url pero mejor mandar la url completa o el path local. 
    # Almacenaremos el path relativo /api/uploads/avatars/...
    update_data = {"avatar_url": f"/api/uploads/avatars/{filename}"}
    usuario = await repo.update(current_user, update_data)
    
    return UsuarioResponse.model_validate(usuario)

@router.put("/{usuario_id}", response_model=UsuarioResponse, summary="Actualizar un usuario")
async def actualizar_usuario(
    usuario_id: uuid.UUID,
    data: UsuarioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza los datos de un usuario. Solo admin."""
    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    update_data = data.model_dump(exclude_unset=True)
    usuario = await repo.update(usuario, update_data)
    await admin_ws_manager.broadcast_admin({"event": "usuario_updated"})
    return UsuarioResponse.model_validate(usuario)


@router.delete("/{usuario_id}", summary="Eliminar un usuario")
async def eliminar_usuario(
    usuario_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un usuario del sistema. Solo admin."""
    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    await repo.delete(usuario)
    await admin_ws_manager.broadcast_admin({"event": "usuario_deleted"})
    return {"message": f"Usuario {usuario.nombre} eliminado correctamente"}


@router.post("/{usuario_id}/tokens", summary="Ajustar tokens de un usuario")
async def ajustar_tokens(
    usuario_id: uuid.UUID,
    cantidad: int,
    motivo: str = "Ajuste manual",
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    """Ajuste manual de tokens. Solo admin. Cantidad puede ser positiva o negativa."""
    service = TokenService(db)
    nuevo_saldo = await service.ajuste_admin(usuario_id, cantidad, motivo)
    await admin_ws_manager.broadcast_admin({"event": "usuario_tokens_updated"})
    return {"message": f"Tokens ajustados. Nuevo saldo: {nuevo_saldo}", "tokens": nuevo_saldo}


@router.post("/tokens/recarga-mensual", summary="Ejecutar recarga mensual de tokens")
async def recarga_mensual(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    """Recarga manual de tokens mensuales para todos los alumnos. Solo admin."""
    service = TokenService(db)
    recargados = await service.recarga_mensual()
    await admin_ws_manager.broadcast_admin({"event": "usuarios_tokens_recharged"})
    return {"message": f"Tokens recargados para {recargados} alumnos"}
