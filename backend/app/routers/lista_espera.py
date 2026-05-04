"""
RESERVIVES - Router de Lista de Espera.

Permite a los usuarios apuntarse a un tramo ocupado
y recibir notificaciones cuando se libere.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.repositories.lista_espera_repo import ListaEsperaRepository
from app.schemas.reserva import ListaEsperaCreate, ListaEsperaResponse
from app.services.lista_espera_service import ListaEsperaService
from app.utils.exceptions import ReservivesException

router = APIRouter(prefix="/lista-espera", tags=["Lista de Espera"])


def _to_response(entrada) -> ListaEsperaResponse:
    resp = ListaEsperaResponse.model_validate(entrada)
    if entrada.usuario:
        resp.nombre_usuario = f"{entrada.usuario.nombre} {entrada.usuario.apellidos}"
    if entrada.espacio:
        resp.nombre_espacio = entrada.espacio.nombre
    if entrada.tramo:
        resp.nombre_tramo = entrada.tramo.nombre
    return resp


@router.get("/", response_model=list[ListaEsperaResponse], summary="Mi lista de espera")
async def mi_lista_espera(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Devuelve las entradas activas del usuario en listas de espera."""
    repo = ListaEsperaRepository(db)
    entradas = await repo.get_by_usuario(current_user.id)
    return [_to_response(e) for e in entradas]


@router.post("/", response_model=ListaEsperaResponse, status_code=201,
             summary="Unirse a lista de espera")
async def unirse_lista_espera(
    data: ListaEsperaCreate,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Se une a la lista de espera para un tramo ocupado.
    Recibirá notificación cuando el slot se libere.
    """
    try:
        service = ListaEsperaService(db)
        entrada = await service.unirse(current_user, data)
        repo = ListaEsperaRepository(db)
        entrada = await repo.get_by_id(entrada.id)
        return _to_response(entrada)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.delete("/{entrada_id}", response_model=ListaEsperaResponse,
               summary="Abandonar lista de espera")
async def abandonar_lista_espera(
    entrada_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cancela la entrada del usuario en la lista de espera."""
    try:
        service = ListaEsperaService(db)
        entrada = await service.abandonar(entrada_id, current_user)
        repo = ListaEsperaRepository(db)
        entrada = await repo.get_by_id(entrada.id)
        return _to_response(entrada)
    except ReservivesException as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.get("/espacio/{espacio_id}/count", summary="Personas en espera para un slot")
async def count_lista_espera(
    espacio_id: uuid.UUID,
    tramo_id: uuid.UUID,
    fecha: str,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Devuelve cuántas personas esperan un slot concreto."""
    from datetime import date as date_type
    try:
        fecha_obj = date_type.fromisoformat(fecha)
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de fecha inválido (YYYY-MM-DD)")

    repo = ListaEsperaRepository(db)
    count = await repo.count_activos(espacio_id, tramo_id, fecha_obj)
    return {"count": count}
