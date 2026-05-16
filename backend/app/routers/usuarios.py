import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select as sql_select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_backoffice_section
from app.models.usuario import Usuario
from app.repositories.usuario_repo import UsuarioRepository
from app.schemas.usuario import UsuarioResponse, UsuarioUpdate
from app.services.token_service import TokenService
from app.services.websocket_manager import admin_ws_manager
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])


# Devuelve todos los usuarios registrados con paginación. Solo admin.
@router.get("/", response_model=list[UsuarioResponse], summary="Listar todos los usuarios")
async def listar_usuarios(
    skip: int = 0,
    limit: int = 100,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    settings = get_settings()

    repo = UsuarioRepository(db)
    usuarios = await repo.get_all(skip=skip, limit=limit)
    return [UsuarioResponse.model_validate(u) for u in usuarios]


# Devuelve los datos de un usuario concreto.
# Los usuarios sin permisos de backoffice solo pueden consultar su propio perfil.
@router.get("/{usuario_id}", response_model=UsuarioResponse, summary="Obtener un usuario")
async def obtener_usuario(
    usuario_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Los no-admin solo pueden verse a sí mismos
    can_view_users = can_access_backoffice_section(current_user.rol, BackofficeSection.USERS)
    if not can_view_users and current_user.id != usuario_id:
        raise HTTPException(status_code=403, detail="Solo puedes ver tu propio perfil")

    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return UsuarioResponse.model_validate(usuario)


# Actualiza los datos de un usuario. Solo admin.
# Si se cambia el rol manualmente, se marca rol_override para que
# futuros logins con Entra ID no lo sobreescriban.
@router.put("/{usuario_id}", response_model=UsuarioResponse, summary="Actualizar un usuario")
async def actualizar_usuario(
    usuario_id: uuid.UUID,
    data: UsuarioUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    update_data = data.model_dump(exclude_unset=True)
    if "rol" in update_data:
        update_data["rol_override"] = True
    usuario = await repo.update(usuario, update_data)
    await admin_ws_manager.broadcast_admin({"event": "usuario_updated"})
    return UsuarioResponse.model_validate(usuario)


# Elimina un usuario del sistema. Solo admin.
@router.delete("/{usuario_id}", summary="Eliminar un usuario")
async def eliminar_usuario(
    usuario_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    repo = UsuarioRepository(db)
    usuario = await repo.get_by_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    await repo.delete(usuario)
    await admin_ws_manager.broadcast_admin({"event": "usuario_deleted"})
    return {"message": f"Usuario {usuario.nombre} eliminado correctamente"}


# Ajuste puntual de tokens para un usuario. Cantidad puede ser positiva o negativa. Solo admin.
@router.post("/{usuario_id}/tokens", summary="Ajustar tokens de un usuario")
async def ajustar_tokens(
    usuario_id: uuid.UUID,
    cantidad: int,
    motivo: str = "Ajuste manual",
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    service = TokenService(db)
    nuevo_saldo = await service.ajuste_admin(usuario_id, cantidad, motivo)
    await admin_ws_manager.broadcast_admin({"event": "usuario_tokens_updated"})
    return {"message": f"Tokens ajustados. Nuevo saldo: {nuevo_saldo}", "tokens": nuevo_saldo}


# Recarga mensual de tokens para todos los alumnos. Normalmente se lanza desde el cron,
# pero este endpoint permite dispararla manualmente. Solo admin.
@router.post("/tokens/recarga-mensual", summary="Ejecutar recarga mensual de tokens")
async def recarga_mensual(
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    service = TokenService(db)
    recargados = await service.recarga_mensual()
    await admin_ws_manager.broadcast_admin({"event": "usuarios_tokens_recharged"})
    return {"message": f"Tokens recargados para {recargados} alumnos"}


# Ajuste masivo de tokens. Se puede filtrar por rol o aplicar a todos los usuarios. Solo admin.
@router.post("/tokens/bulk", summary="Ajustar tokens masivamente")
async def ajustar_tokens_bulk(
    cantidad: int,
    rol: str | None = None,
    motivo: str = "Ajuste masivo de tokens",
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.USERS)),
    db: AsyncSession = Depends(get_db),
):
    stmt = sql_select(Usuario)
    if rol and rol.upper() not in ("TODOS", "ALL", ""):
        stmt = stmt.where(Usuario.rol == rol.upper())

    result = await db.execute(stmt)
    usuarios = result.scalars().all()

    service = TokenService(db)
    count = 0
    for u in usuarios:
        try:
            await service.ajuste_admin(u.id, cantidad, motivo)
            count += 1
        except Exception:
            continue

    await admin_ws_manager.broadcast_admin({"event": "usuarios_tokens_updated"})
    return {"message": f"Tokens ajustados para {count} usuarios", "count": count}
