import uuid
import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.encuesta import Encuesta, EncuestaCreate, EncuestaUpdate, EncuestaResultados, VotoEncuestaCreate
from app.repositories.encuesta_repo import EncuestaRepository
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.services.notification_service import NotificationService
from app.models.notificacion import TipoNotificacion
from app.models.encuesta import Encuesta as EncuestaModel, EncuestaOpcion
from app.utils.role_access import BackofficeSection, can_access_backoffice_section

router = APIRouter(prefix="/encuestas", tags=["Encuestas"])


def _require_polls_access(current_user: Usuario) -> None:
    if not can_access_backoffice_section(current_user.rol, BackofficeSection.POLLS):
        raise HTTPException(status_code=403, detail="No tienes permisos")


@router.get("/", response_model=List[Encuesta])
async def list_active_polls(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    repo = EncuestaRepository(db)
    all_active = await repo.list_active()
    
    # Filtrar encuestas en las que el usuario ya ha votado
    filtered_polls = []
    for poll in all_active:
        has_voted = await repo.user_has_voted(current_user.id, poll.id)
        if not has_voted:
            filtered_polls.append(poll)
            
    return filtered_polls


@router.post("/", response_model=Encuesta, status_code=status.HTTP_201_CREATED)
async def create_poll(
    poll_in: EncuestaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    _require_polls_access(current_user)

    new_poll = EncuestaModel(
        titulo=poll_in.titulo,
        descripcion=poll_in.descripcion,
        fecha_fin=poll_in.fecha_fin,
        activa=poll_in.activa
    )
    db.add(new_poll)
    await db.flush()

    for opt in poll_in.opciones:
        db.add(EncuestaOpcion(encuesta_id=new_poll.id, texto=opt.texto, orden=opt.orden))

    await db.commit()
    await db.refresh(new_poll)

    notif_service = NotificationService(db)
    await notif_service.broadcast_to_all(
        tipo=TipoNotificacion.NUEVA_ENCUESTA,
        titulo="Nueva Encuesta Disponible",
        mensaje=f"Participa en: {new_poll.titulo}"
    )

    repo = EncuestaRepository(db)
    return await repo.get_with_options(new_poll.id)


@router.get("/{poll_id}/resultados", response_model=EncuestaResultados)
async def get_poll_results(
    poll_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    repo = EncuestaRepository(db)
    results = await repo.get_results(poll_id)
    if not results:
        raise HTTPException(status_code=404, detail="Encuesta no encontrada")

    poll = results["encuesta"]
    counts = results["counts"]

    opciones_res = [
        {
            "id": opt.id,
            "encuesta_id": opt.encuesta_id,
            "texto": opt.texto,
            "orden": opt.orden,
            "votos_count": counts.get(opt.id, 0)
        }
        for opt in poll.opciones
    ]

    voto_usuario = await repo.user_has_voted(current_user.id, poll_id)

    return {
        "id": poll.id,
        "titulo": poll.titulo,
        "descripcion": poll.descripcion,
        "fecha_fin": poll.fecha_fin,
        "activa": poll.activa,
        "created_at": poll.created_at,
        "updated_at": poll.updated_at,
        "opciones": opciones_res,
        "total_votos": results["total_votos"],
        "voto_usuario_opcion_id": voto_usuario
    }


@router.post("/{poll_id}/votar", status_code=status.HTTP_204_NO_CONTENT)
async def vote_in_poll(
    poll_id: uuid.UUID,
    vote_in: VotoEncuestaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    repo = EncuestaRepository(db)
    encuesta = await repo.get_with_options(poll_id)
    if not encuesta or not encuesta.activa:
        raise HTTPException(status_code=404, detail="Encuesta no disponible")

    if encuesta.fecha_fin < datetime.datetime.now(datetime.timezone.utc):
        raise HTTPException(status_code=400, detail="La encuesta ha finalizado")

    if await repo.user_has_voted(current_user.id, poll_id):
        raise HTTPException(status_code=400, detail="Ya has votado en esta encuesta")

    if vote_in.opcion_id not in [o.id for o in encuesta.opciones]:
        raise HTTPException(status_code=400, detail="Opción inválida para esta encuesta")

    await repo.cast_vote(current_user.id, poll_id, vote_in.opcion_id)
    await db.commit()


@router.get("/admin/list", response_model=List[EncuestaResultados])
async def list_all_polls_admin(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    _require_polls_access(current_user)
    
    repo = EncuestaRepository(db)
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(EncuestaModel)
        .options(selectinload(EncuestaModel.opciones))
        .order_by(EncuestaModel.created_at.desc())
    )
    polls = result.scalars().all()
    
    response = []
    for poll in polls:
        results = await repo.get_results(poll.id)
        counts = results["counts"]
        
        opciones_res = [
            {
                "id": opt.id,
                "encuesta_id": opt.encuesta_id,
                "texto": opt.texto,
                "orden": opt.orden,
                "votos_count": counts.get(opt.id, 0)
            }
            for opt in poll.opciones
        ]
        
        response.append({
            "id": poll.id,
            "titulo": poll.titulo,
            "descripcion": poll.descripcion,
            "fecha_fin": poll.fecha_fin,
            "activa": poll.activa,
            "created_at": poll.created_at,
            "updated_at": poll.updated_at,
            "opciones": opciones_res,
            "total_votos": results["total_votos"],
            "voto_usuario_opcion_id": None # No importa para el admin
        })
        
    return response


@router.patch("/{poll_id}", response_model=Encuesta)
async def update_poll(
    poll_id: uuid.UUID,
    poll_in: EncuestaUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    _require_polls_access(current_user)
    
    repo = EncuestaRepository(db)
    poll = await repo.get_with_options(poll_id)
    if not poll:
        raise HTTPException(status_code=404, detail="Encuesta no encontrada")
    
    update_data = poll_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(poll, field, value)
    
    await db.commit()
    await db.refresh(poll)
    return poll


@router.delete("/{poll_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_poll(
    poll_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    _require_polls_access(current_user)
    
    repo = EncuestaRepository(db)
    poll = await repo.get_by_id(poll_id)
    if not poll:
        raise HTTPException(status_code=404, detail="Encuesta no encontrada")
    
    await db.delete(poll)
    await db.commit()
