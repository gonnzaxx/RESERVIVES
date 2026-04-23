import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.middleware.auth_middleware import get_current_user, require_admin
from app.models.incidencia import Incidencia, EstadoIncidencia
from app.models.usuario import Usuario
from app.repositories.incidencia_repo import IncidenciaRepository
from app.schemas.incidencia import IncidenciaCreate, IncidenciaResponse, IncidenciaUpdate
from app.services.notification_service import NotificationService
from app.services.email_service import EmailService
from app.models.notificacion import TipoNotificacion
from app.models.usuario import RolUsuario
from sqlalchemy import select

router = APIRouter(prefix="/incidencias", tags=["Incidencias"])

@router.get("/admin", response_model=List[IncidenciaResponse])
async def list_all_incidencias(
    db: AsyncSession = Depends(get_db),
    admin: Usuario = Depends(require_admin)
):
    """Admin: Lista todas las incidencias del sistema."""
    repo = IncidenciaRepository(db)
    return await repo.get_all_with_users()

@router.get("/mis-incidencias", response_model=List[IncidenciaResponse])
async def list_user_incidencias(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Usuario: Lista solo sus incidencias reportadas."""
    repo = IncidenciaRepository(db)
    # Asumiendo que repo tiene get_by_usuario_id o similar
    from sqlalchemy import select
    result = await db.execute(select(Incidencia).where(Incidencia.usuario_id == current_user.id).order_by(Incidencia.created_at.desc()))
    return result.scalars().all()

@router.post("/", response_model=IncidenciaResponse, status_code=status.HTTP_201_CREATED)
async def create_incidencia(
    incidencia_in: IncidenciaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    repo = IncidenciaRepository(db)
    new_incidencia = Incidencia(
        usuario_id=current_user.id,
        descripcion=incidencia_in.descripcion,
        imagen_url=incidencia_in.imagen_url,
        estado=EstadoIncidencia.PENDIENTE
    )
    incidencia = await repo.create(new_incidencia)
    
    # --- NOTIFICACIONES AL ADMIN ---
    notif_service = NotificationService(db)
    
    # Notificación centralizada (App, Push y Email)
    await notif_service.notify_admins(
        tipo=TipoNotificacion.NUEVA_INCIDENCIA,
        titulo="Nueva Incidencia Reportada",
        mensaje=f"El usuario {current_user.nombre} ha reportado un problema: {incidencia.descripcion[:50]}...",
        email_data={
            "template_key": "incidencia_reportada",
            "context": {
                "user_name": current_user.nombre,
                "description": incidencia.descripcion,
                "created_at": incidencia.created_at 
            }
        }
    )

    return incidencia

@router.patch("/admin/{incidencia_id}/estado", response_model=IncidenciaResponse)
async def update_incidencia_status_admin(
    incidencia_id: uuid.UUID,
    update_in: IncidenciaUpdate,
    db: AsyncSession = Depends(get_db),
    admin: Usuario = Depends(require_admin)
):
    repo = IncidenciaRepository(db)
    incidencia = await repo.get_by_id(incidencia_id)
    if not incidencia:
        raise HTTPException(status_code=404, detail="Incidencia no encontrada")
    
    incidencia.estado = update_in.estado
    if hasattr(update_in, 'comentario_admin') and update_in.comentario_admin:
        incidencia.comentario_admin = update_in.comentario_admin
        
    await db.commit()
    await db.refresh(incidencia)
    
    # --- NOTIFICACIÓN AL USUARIO ---
    if incidencia.estado == EstadoIncidencia.RESUELTA:
        notif_service = NotificationService(db)
        
        await notif_service.create_for_user(
            usuario_id=incidencia.usuario_id,
            tipo=TipoNotificacion.INCIDENCIA_RESUELTA,
            titulo="Incidencia Resuelta",
            mensaje=f"Tu incidencia '{incidencia.descripcion[:30]}...' ha sido marcada como resuelta.",
            email_data={
                "template_key": "incidencia_resuelta",
                "context": {
                    "user_name": incidencia.usuario.nombre,
                    "description": incidencia.descripcion,
                    "resolution": incidencia.comentario_admin or "El problema ha sido resuelto."
                }
            }
        )

    return incidencia
