from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.middleware.auth_middleware import get_current_user
from app.models.usuario import Usuario, RolUsuario
from app.models.espacio import TipoEspacio
from app.repositories.analytics_repo import AnalyticsRepository

router = APIRouter(prefix="/admin/dashboard", tags=["Admin Dashboard"])

@router.get("/")
async def get_admin_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.rol != RolUsuario.ADMIN:
        return {"error": "No autorizado"}
        
    repo = AnalyticsRepository(db)
    
    aulas = await repo.get_espacios_kpis(TipoEspacio.AULA)
    pistas = await repo.get_espacios_kpis(TipoEspacio.PISTA)
    servicios = await repo.get_servicios_kpis()
    anuncios = await repo.get_anuncios_kpis()
    
    return {
        "espacios": {
            "aulas": aulas,
            "pistas": pistas
        },
        "servicios": servicios,
        "anuncios": anuncios
    }
