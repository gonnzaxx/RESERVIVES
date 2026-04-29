"""
RESERVIVES - Servicio de Tokens.

Lógica de negocio para la gestión del sistema de tokens:
recarga mensual, consulta de saldo, ajustes manuales del admin.
Los tokens se resetean (no se acumulan) el día 1 de cada mes.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.historial_tokens import HistorialTokens, TipoMovimientoToken
from app.repositories.usuario_repo import UsuarioRepository
from sqlalchemy import select
from app.models.configuracion import Configuracion
from app.models.notificacion import TipoNotificacion
from app.services.notification_service import NotificationService
from app.utils.role_access import MAX_USER_TOKENS, monthly_tokens_for_role

settings = get_settings()


class TokenService:
    """Servicio para gestión del sistema de tokens."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.usuario_repo = UsuarioRepository(session)
        self.notification_service = NotificationService(session)

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

    async def recarga_mensual(self) -> int:
        """
        Recarga mensual de tokens para todos los alumnos activos.
        Se ejecuta el día 1 de cada mes. Los tokens NO se acumulan,
        se resetean al valor configurado.

        Returns:
            Número de alumnos recargados.
        """
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
            # Resetear tokens al valor mensual segun rol (no acumulativo)
            usuario.tokens = monthly_tokens_for_role(
                usuario.rol,
                cantidad_tokens_alumno,
                cantidad_tokens_profesor,
            )

            # Registrar en historial
            historial = HistorialTokens(
                usuario_id=usuario.id,
                cantidad=usuario.tokens,
                tipo=TipoMovimientoToken.RECARGA_MENSUAL,
                motivo="Recarga mensual automática de tokens",
            )
            self.session.add(historial)

            # Notificar al usuario (Push + In-app + Email)
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

    async def ajuste_admin(
        self, usuario_id, cantidad: int, motivo: str
    ) -> int:
        """
        Ajuste manual de tokens por parte del admin.
        Puede ser positivo (añadir) o negativo (quitar).

        Returns:
            Nuevo saldo de tokens del usuario.
        """
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
