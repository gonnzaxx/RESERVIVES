"""
IES LUIS VIVES APP - Punto de entrada de la aplicacion FastAPI.
"""

from contextlib import asynccontextmanager
from datetime import datetime, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select, update, or_, and_

from app.config import get_settings
from app.database import async_session
from app.middleware.request_context_middleware import RequestContextMiddleware
from app.models.anuncio import Anuncio
from app.models.configuracion import Configuracion
from app.routers import (
    ai,
    admin,
    anuncios,
    auth,
    cafeteria,
    espacios,
    favoritos,
    notificaciones,
    reservas_espacios,
    reservas_recurrentes,
    lista_espera,
    servicios,
    reservas_servicios,
    tramos,
    uploads,
    usuarios,
    configuracion,
    incidencias,
    encuestas,
    dashboard,
    ws,
)
from app.routers.configuracion import tramos_router, roles_router
from app.services.ai_rate_limit_service import ensure_ai_rate_limit_table
from app.services.push_notification_service import get_push_notification_service
from app.services.token_service import TokenService
from app.utils.exceptions import ReservivesException
from app.utils.logging import configure_logging, get_logger

settings = get_settings()
configure_logging(settings.APP_DEBUG)
logger = get_logger("app.main")

scheduler = AsyncIOScheduler()


# Tarea programada: recarga tokens el día 1 de cada mes
async def recarga_mensual_tokens():
    async with async_session() as session:
        try:
            service = TokenService(session)
            recargados = await service.recarga_mensual()
            await session.commit()
            logger.info(
                "monthly_token_reload_completed",
                extra={"extra_data": {"reloaded_students": recargados}},
            )
        except Exception:
            await session.rollback()
            logger.exception("monthly_token_reload_failed")


# Tarea programada: genera instancias de reservas recurrentes aprobadas
async def generar_instancias_recurrentes():
    async with async_session() as session:
        try:
            from app.services.reserva_recurrente_service import ReservaRecurrenteService
            service = ReservaRecurrenteService(session)
            creadas = await service.generar_instancias_pendientes()
            await session.commit()
            logger.info(
                "recurring_instances_generated",
                extra={"extra_data": {"instances_created": creadas}},
            )
        except Exception:
            await session.rollback()
            logger.exception("recurring_instances_generation_failed")


# Tarea programada: inactiva anuncios expirados por fecha o por el límite de días por defecto
async def limpiar_anuncios_expirados():
    async with async_session() as session:
        try:
            res = await session.execute(
                select(Configuracion.valor).where(Configuracion.clave == "dias_caducidad_anuncio_defecto")
            )
            dias_defecto = int(res.scalar_one_or_none() or 10)
            limite_defecto = datetime.now() - timedelta(days=dias_defecto)

            await session.execute(
                update(Anuncio)
                .where(
                    Anuncio.activo == True,
                    or_(
                        Anuncio.fecha_expiracion < datetime.now(),
                        and_(
                            Anuncio.fecha_expiracion == None,
                            Anuncio.created_at < limite_defecto
                        )
                    )
                )
                .values(activo=False)
            )
            await session.commit()
            logger.info("expired_ads_cleanup_completed")
        except Exception:
            await session.rollback()
            logger.exception("expired_ads_cleanup_failed")


# Inserta las configuraciones por defecto en BD si aún no existen
async def _init_db_defaults(session):
    defaults = {
        'tokens_por_recarga_alumno': '20',
        'tokens_iniciales_nuevo_usuario': '20',
        'tokens_iniciales_alumno': '20',
        'tokens_iniciales_profesor': '60',
        'tokens_recarga_mensual_alumno': '20',
        'tokens_recarga_mensual_profesor': '60',
        'auth_dev_bypass_enabled': 'false',
        'ia_habilitada': 'true',
        'dias_no_laborables': '{"dates":[],"months":[]}',
        'graph_email_enabled': 'true',
        'graph_from_email': settings.GRAPH_FROM_EMAIL,
        'firebase_habilitado': str(settings.FIREBASE_ENABLED).lower(),
        'gemini_api_key': settings.GEMINI_API_KEY,
        'gemini_model': settings.GEMINI_MODEL,
        'azure_client_id': settings.AZURE_CLIENT_ID,
        'azure_tenant_id': settings.AZURE_TENANT_ID,
        'azure_client_secret': settings.AZURE_CLIENT_SECRET,
        'azure_authority': settings.AZURE_AUTHORITY,
    }

    result = await session.execute(select(Configuracion))
    existing_configs = {c.clave: c for c in result.scalars().all()}

    for clave, valor_defecto in defaults.items():
        if clave not in existing_configs:
            session.add(Configuracion(clave=clave, valor=valor_defecto))

    # Sincronizar mappings de grupos Azure desde la configuración del entorno
    role_groups: dict[str, list[str]] = {}
    for group_id, role_name in settings.azure_group_role_map.items():
        role_upper = role_name.upper()
        if role_upper not in role_groups:
            role_groups[role_upper] = []
        role_groups[role_upper].append(group_id)

    for role_upper, group_ids in role_groups.items():
        clave = f"azure_group_{role_upper}"
        if clave not in existing_configs:
            session.add(Configuracion(clave=clave, valor=",".join(group_ids)))

    await session.commit()


# Ciclo de vida de la aplicación: inicializa BD, arranca scheduler y servicios push
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with async_session() as session:
        await _init_db_defaults(session)
        await ensure_ai_rate_limit_table(session)
        await session.commit()

    scheduler.add_job(
        recarga_mensual_tokens,
        trigger=CronTrigger(day=1, hour=0, minute=0),
        id="recarga_mensual",
        name="Recarga mensual de tokens",
        replace_existing=True,
    )
    scheduler.add_job(
        limpiar_anuncios_expirados,
        trigger=CronTrigger(hour=3, minute=0),
        id="limpiar_anuncios",
        name="Limpieza de anuncios expirados",
        replace_existing=True,
    )
    scheduler.add_job(
        generar_instancias_recurrentes,
        trigger=CronTrigger(hour=2, minute=0),
        id="generar_instancias_recurrentes",
        name="Generación de instancias de reservas recurrentes",
        replace_existing=True,
    )
    scheduler.start()
    get_push_notification_service().initialize()
    logger.info("backend_started")
    logger.info(
        "monthly_token_reload_scheduled",
        extra={"extra_data": {"day": 1, "hour": 0, "minute": 0}},
    )
    yield
    scheduler.shutdown()
    logger.info("backend_stopped")


app = FastAPI(
    title="IES LUIS VIVES APP API",
    description=(
        "API REST para la gestion de reservas de espacios, servicios, "
        "cafeteria y tablon de anuncios del IES Luis Vives."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=(
        r"^https?://("
        r"localhost|"
        r"127\.0\.0\.1|"
        r"vms\.iesluisvives\.org|"
        r"10(?:\.\d{1,3}){3}|"
        r"172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2}|"
        r"192\.168(?:\.\d{1,3}){2}"
        r")(:\d+)?$"
    ),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestContextMiddleware)


# Convierte las excepciones de negocio en respuestas JSON con el código HTTP correcto
@app.exception_handler(ReservivesException)
async def reservives_exception_handler(request: Request, exc: ReservivesException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message},
    )


# Captura cualquier excepción no controlada y devuelve 500
@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.exception(
        "unhandled_exception",
        extra={"extra_data": {"path": request.url.path, "method": request.method}},
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor"},
    )


app.include_router(auth.router, prefix="/api")
app.include_router(ai.router, prefix="/api")
app.include_router(usuarios.router, prefix="/api")
app.include_router(espacios.router, prefix="/api")
app.include_router(reservas_espacios.router, prefix="/api")
app.include_router(reservas_recurrentes.router, prefix="/api")
app.include_router(lista_espera.router, prefix="/api")
app.include_router(anuncios.router, prefix="/api")
app.include_router(cafeteria.router, prefix="/api")
app.include_router(servicios.router, prefix="/api")
app.include_router(reservas_servicios.router, prefix="/api")
app.include_router(tramos.router, prefix="/api")
app.include_router(favoritos.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(uploads.router, prefix="/api")
app.include_router(notificaciones.router, prefix="/api")
app.include_router(configuracion.router, prefix="/api")
app.include_router(incidencias.router, prefix="/api")
app.include_router(encuestas.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(ws.router, prefix="/api")
app.include_router(tramos_router, prefix="/api")
app.include_router(roles_router, prefix="/api")

app.mount("/api/uploads", StaticFiles(directory="uploads"), name="uploads")


# Información básica de la API
@app.get("/", tags=["Sistema"])
async def root():
    return {
        "app": "IES LUIS VIVES APP",
        "version": "1.0.0",
        "description": "API del IES Luis Vives para gestión de reservas",
        "docs": "/api/docs",
    }


# Endpoint público de estado para health checks
@app.get("/api/health", tags=["Sistema"])
async def health_check():
    return {"status": "ok", "service": "IES LUIS VIVES APP Backend"}
