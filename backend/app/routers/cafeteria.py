import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.cafeteria import CategoriaCafeteria, ProductoCafeteria
from app.models.usuario import Usuario
from app.repositories.cafeteria_repo import CategoriaRepository, ProductoRepository
from app.schemas.cafeteria import (
    CategoriaCreate, CategoriaResponse, CategoriaUpdate,
    ProductoCreate, ProductoResponse, ProductoUpdate,
)
from app.utils.role_access import BackofficeSection

router = APIRouter(prefix="/cafeteria", tags=["Cafetería"])


# --- CATEGORÍAS ---

@router.get("/categorias", response_model=list[CategoriaResponse], summary="Listar menú")
async def listar_categorias(
    db: AsyncSession = Depends(get_db),
):
    """Lista todas las categorías activas con sus productos."""
    repo = CategoriaRepository(db)
    categorias = await repo.get_activas_con_productos()
    return [CategoriaResponse.model_validate(c) for c in categorias]


@router.post("/categorias", response_model=CategoriaResponse, status_code=201, summary="Crear categorÃ­a")
async def crear_categoria(
    data: CategoriaCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Crea una nueva categoría de cafetería. Solo admin."""
    repo = CategoriaRepository(db)
    categoria = CategoriaCafeteria(**data.model_dump())
    categoria = await repo.create(categoria)
    return CategoriaResponse.model_validate(categoria)


@router.put("/categorias/{categoria_id}", response_model=CategoriaResponse, summary="Actualizar categorÃ­a")
async def actualizar_categoria(
    categoria_id: uuid.UUID,
    data: CategoriaUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza una categoría. Solo admin."""
    repo = CategoriaRepository(db)
    categoria = await repo.get_by_id(categoria_id)
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    update_data = data.model_dump(exclude_unset=True)
    categoria = await repo.update(categoria, update_data)
    return CategoriaResponse.model_validate(categoria)


@router.delete("/categorias/{categoria_id}", summary="Eliminar categoría")
async def eliminar_categoria(
    categoria_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Elimina una categoría y sus productos. Solo admin."""
    repo = CategoriaRepository(db)
    categoria = await repo.get_by_id(categoria_id)
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    await repo.delete(categoria)
    return {"message": f"Categoría '{categoria.nombre}' eliminada correctamente"}


# --- PRODUCTOS ---

@router.get("/productos", response_model=list[ProductoResponse], summary="Listar productos")
async def listar_productos(
    db: AsyncSession = Depends(get_db),
):
    """Lista todos los productos disponibles."""
    repo = ProductoRepository(db)
    productos = await repo.get_disponibles()
    return [ProductoResponse.model_validate(p) for p in productos]


@router.get("/productos/destacados", response_model=list[ProductoResponse], summary="Productos destacados")
async def listar_destacados(
    db: AsyncSession = Depends(get_db),
):
    """Lista los productos marcados como destacados."""
    repo = ProductoRepository(db)
    productos = await repo.get_destacados()
    return [ProductoResponse.model_validate(p) for p in productos]


@router.post("/productos", response_model=ProductoResponse, status_code=201, summary="Crear producto")
async def crear_producto(
    data: ProductoCreate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Crea un nuevo producto de cafeterÃ­a. Solo admin."""
    repo = ProductoRepository(db)
    producto = ProductoCafeteria(**data.model_dump())
    producto = await repo.create(producto)
    return ProductoResponse.model_validate(producto)


@router.put("/productos/{producto_id}", response_model=ProductoResponse, summary="Actualizar producto")
async def actualizar_producto(
    producto_id: uuid.UUID,
    data: ProductoUpdate,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Actualiza un producto. Solo admin."""
    repo = ProductoRepository(db)
    producto = await repo.get_by_id(producto_id)
    if not producto:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    update_data = data.model_dump(exclude_unset=True)
    producto = await repo.update(producto, update_data)
    return ProductoResponse.model_validate(producto)


@router.delete("/productos/{producto_id}", summary="Eliminar producto")
async def eliminar_producto(
    producto_id: uuid.UUID,
    admin: Usuario = Depends(require_backoffice_section(BackofficeSection.CAFETERIA)),
    db: AsyncSession = Depends(get_db),
):
    """Elimina un producto. Solo admin."""
    repo = ProductoRepository(db)
    producto = await repo.get_by_id(producto_id)
    if not producto:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    await repo.delete(producto)
    return {"message": f"Producto '{producto.nombre}' eliminado correctamente"}
