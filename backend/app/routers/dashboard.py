from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_backoffice_section
from app.models.espacio import TipoEspacio
from app.models.usuario import Usuario
from app.repositories.analytics_repo import AnalyticsRepository
from app.utils.role_access import BackofficeSection

router = APIRouter(prefix="/admin/dashboard", tags=["Admin Dashboard"])


# Devuelve los KPIs de aulas, pistas, servicios y anuncios para el dashboard admin
@router.get("/")
async def get_admin_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: Usuario = Depends(require_backoffice_section(BackofficeSection.METRICS))
):
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
