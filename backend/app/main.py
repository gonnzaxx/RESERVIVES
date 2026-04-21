"""
RESERVIVES - Punto de entrada de la aplicacion FastAPI.
"""

from contextlib import asynccontextmanager

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select


from app.config import get_settings
from app.database import async_session
from app.middleware.request_context_middleware import RequestContextMiddleware
from app.routers import (
    admin,
    anuncios,
    auth,
    cafeteria,
    espacios,
    favoritos,
    notificaciones,
    reservas_espacios,
    servicios,
    reservas_servicios,
    tramos,
    uploads,
    usuarios,
    configuracion,
    incidencias,
    encuestas,
    dashboard,
)
from app.services.push_notification_service import get_push_notification_service
from app.services.token_service import TokenService
from app.utils.exceptions import ReservivesException
from app.utils.logging import configure_logging, get_logger

settings = get_settings()
configure_logging(settings.APP_DEBUG)
logger = get_logger("app.main")

scheduler = AsyncIOScheduler()


async def recarga_mensual_tokens():
    """Tarea programada: recarga tokens de alumnos el dia 1 de cada mes."""
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


async def limpiar_anuncios_expirados():
    """Tarea programada: inactiva anuncios cuya fecha de expiración ha pasado o por configuración global."""
    from sqlalchemy import update, or_, and_
    from datetime import datetime, timedelta
    from app.models.anuncio import Anuncio
    from app.models.configuracion import Configuracion

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


async def _init_db_defaults(session):
    from app.models.configuracion import Configuracion

    defaults = {
        'tokens_por_recarga_alumno': '20',
        'tokens_iniciales_nuevo_usuario': '20',
        'auth_dev_bypass_enabled': 'false',
        'smtp_enabled': str(settings.SMTP_ENABLED).lower(),
        'smtp_from_email': settings.SMTP_FROM_EMAIL,
    }

    result = await session.execute(select(Configuracion))
    existing_configs = {c.clave: c for c in result.scalars().all()}

    for clave, valor_defecto in defaults.items():
        if clave not in existing_configs:
            from app.models.configuracion import Configuracion as Conf
            new_config = Conf(clave=clave, valor=valor_defecto)
            session.add(new_config)

    await session.commit()



@asynccontextmanager
async def lifespan(app: FastAPI):
    async with async_session() as session:
        await _init_db_defaults(session)

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
    title="RESERVIVES API",
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


@app.exception_handler(ReservivesException)
async def reservives_exception_handler(request: Request, exc: ReservivesException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message},
    )


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
app.include_router(usuarios.router, prefix="/api")
app.include_router(espacios.router, prefix="/api")
app.include_router(reservas_espacios.router, prefix="/api")
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

app.mount("/api/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/", tags=["Sistema"])
async def root():
    return {
        "app": "RESERVIVES",
        "version": "1.0.0",
        "description": "API del IES Luis Vives para gestión de reservas",
        "docs": "/api/docs",
    }


@app.get("/api/health", tags=["Sistema"])
async def health_check():
    """Endpoint público de estado."""
    return {"status": "ok", "service": "RESERVIVES Backend"}
