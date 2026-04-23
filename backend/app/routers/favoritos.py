import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario
from app.repositories.favorito_repo import FavoritoRepository
from app.schemas.favorito import FavoritoEspacioResponse, FavoritoServicioResponse

router = APIRouter(prefix="/favoritos", tags=["Favoritos"])

@router.get("/espacios", response_model=list[FavoritoEspacioResponse])
async def listar_espacios_favoritos(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    return await repo.get_espacios_by_usuario(current_user.id)

@router.post("/espacios/{espacio_id}", status_code=201)
async def agregar_espacio_favorito(
    espacio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    try:
        return await repo.add_espacio(current_user.id, espacio_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Ya es favorito o el espacio no existe")

@router.delete("/espacios/{espacio_id}")
async def eliminar_espacio_favorito(
    espacio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    await repo.remove_espacio(current_user.id, espacio_id)
    return {"message": "Favorito eliminado"}

@router.get("/servicios", response_model=list[FavoritoServicioResponse])
async def listar_servicios_favoritos(
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    return await repo.get_servicios_by_usuario(current_user.id)

@router.post("/servicios/{servicio_id}", status_code=201)
async def agregar_servicio_favorito(
    servicio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    try:
        return await repo.add_servicio(current_user.id, servicio_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Ya es favorito o el servicio no existe")

@router.delete("/servicios/{servicio_id}")
async def eliminar_servicio_favorito(
    servicio_id: uuid.UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    repo = FavoritoRepository(db)
    await repo.remove_servicio(current_user.id, servicio_id)
    return {"message": "Favorito eliminado"}
