from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Dict, List

from app.database import get_db
from app.models.usuario import Usuario
from app.models.configuracion import Configuracion
from app.middleware.auth_middleware import require_admin

router = APIRouter(prefix="/admin/configuracion", tags=["Configuracion"])

class ConfigItemUpdate(BaseModel):
    clave: str
    valor: str

class ConfigUpdateRequest(BaseModel):
    configs: List[ConfigItemUpdate]

@router.get("", summary="Obtener todas las configuraciones")
async def get_configuracion(
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, str]:
    """Obtiene el listado clave-valor de configuración actual."""
    result = await db.execute(select(Configuracion))
    configs = result.scalars().all()
    return {c.clave: c.valor for c in configs}

@router.put("", summary="Actualizar configuraciones en lote")
async def update_configuracion(
    request: ConfigUpdateRequest,
    admin: Usuario = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Actualiza múltiples configuraciones a la vez o las crea si no existen."""
    # Obtenemos todas las claves para evitar select repetido (optimizacion opcional, de momento iteramos por simplicidad ya que no son muchas)
    for item in request.configs:
        result = await db.execute(select(Configuracion).where(Configuracion.clave == item.clave))
        config = result.scalar_one_or_none()
        
        if config:
            config.valor = item.valor
        else:
            new_config = Configuracion(clave=item.clave, valor=item.valor)
            db.add(new_config)
            
    await db.commit()
    return {"message": "Configuración actualizada correctamente"}
