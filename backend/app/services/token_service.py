"""
RESERVIVES - Servicio de Tokens.

Lógica de negocio para la gestión del sistema de tokens:
recarga mensual, consulta de saldo, ajustes manuales del admin.
Los tokens se resetean (no se acumulan) el día 1 de cada mes.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.configuracion import Configuracion
from app.models.historial_tokens import HistorialTokens, TipoMovimientoToken
from app.models.notificacion import TipoNotificacion
from app.repositories.usuario_repo import UsuarioRepository
from app.services.notification_service import NotificationService
from app.utils.role_access import MAX_USER_TOKENS, monthly_tokens_for_role

settings = get_settings()


class TokenService:

    def __init__(self, session: AsyncSession):
        self.session = session
        self.usuario_repo = UsuarioRepository(session)
        self.notification_service = NotificationService(session)

    # Lee un entero de la tabla configuracion; devuelve default si no existe o no es numérico
    async def _get_config_int(self, clave: str, default: int) -> int:
        result = await self.session.execute(
            select(Configuracion.valor).where(Configuracion.clave == clave)
        )
        raw = result.scalar_one_or_none()
        if raw is None:
            return default
        parsed = str(raw).strip()
        if parsed.isdigit():
            return int(parsed)
        return default

    # Recarga mensual de tokens para todos los usuarios activos con tokens.
    # Los tokens se resetean (no se acumulan) al valor configurado por rol.
    # Devuelve el número de usuarios recargados.
    async def recarga_mensual(self) -> int:
        usuarios = await self.usuario_repo.get_active_users_for_monthly_tokens()

        cantidad_tokens_alumno_legacy = await self._get_config_int(
            "tokens_por_recarga_alumno",
            settings.DEFAULT_MONTHLY_TOKENS,
        )
        cantidad_tokens_alumno = await self._get_config_int(
            "tokens_recarga_mensual_alumno",
            cantidad_tokens_alumno_legacy,
        )
        cantidad_tokens_profesor = await self._get_config_int(
            "tokens_recarga_mensual_profesor",
            60,
        )

        recargados = 0

        for usuario in usuarios:
            # Busca config específica por rol (p. ej. tokens_recarga_mensual_control)
            per_role_key = f"tokens_recarga_mensual_{usuario.rol.value.lower()}"
            per_role_value = await self._get_config_int(per_role_key, -1)
            if per_role_value >= 0:
                usuario.tokens = min(per_role_value, MAX_USER_TOKENS)
            else:
                usuario.tokens = monthly_tokens_for_role(
                    usuario.rol,
                    cantidad_tokens_alumno,
                    cantidad_tokens_profesor,
                )

            historial = HistorialTokens(
                usuario_id=usuario.id,
                cantidad=usuario.tokens,
                tipo=TipoMovimientoToken.RECARGA_MENSUAL,
                motivo="Recarga mensual automática de tokens",
            )
            self.session.add(historial)

            # Notifica al usuario por push, in-app y email
            await self.notification_service.create_for_user(
                usuario_id=usuario.id,
                tipo=TipoNotificacion.RECARGA_TOKENS,
                titulo="Tokens recargados",
                mensaje=f"Tus tokens se han recargado. Tienes {usuario.tokens} tokens disponibles para este mes.",
                email_data={
                    "template_key": "recarga_tokens",
                    "context": {
                        "nombre": usuario.nombre,
                        "cantidad": usuario.tokens
                    }
                }
            )

            recargados += 1

        await self.session.flush()
        return recargados

    # Ajuste manual de tokens por admin; cantidad puede ser positiva o negativa.
    # Devuelve el nuevo saldo del usuario.
    async def ajuste_admin(
        self, usuario_id, cantidad: int, motivo: str
    ) -> int:
        usuario = await self.usuario_repo.get_by_id(usuario_id)
        if not usuario:
            raise ValueError(f"Usuario {usuario_id} no encontrado")

        usuario.tokens = min(MAX_USER_TOKENS, max(0, usuario.tokens + cantidad))

        historial = HistorialTokens(
            usuario_id=usuario.id,
            cantidad=cantidad,
            tipo=TipoMovimientoToken.AJUSTE_ADMIN,
            motivo=motivo,
        )
        self.session.add(historial)
        await self.session.flush()

        return usuario.tokens
