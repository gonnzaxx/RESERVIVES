"""
Servicio de notificaciones in-app, preferencias y registro de entregas.
"""

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notificacion import (
    CanalNotificacion,
    DispositivoPush,
    EstadoEntregaNotificacion,
    Notificacion,
    NotificacionEntrega,
    PreferenciasNotificacion,
    TipoNotificacion,
)
from app.models.usuario import Usuario
from app.services.email_service import EmailService
from app.services.push_notification_service import get_push_notification_service


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_for_user(
        self,
        usuario_id,
        tipo: TipoNotificacion,
        titulo: str,
        mensaje: str,
        referencia_id: str | None = None,
        email_data: dict | None = None,
    ) -> Notificacion | None:
        try:
            preferences = await self.get_or_create_preferences(usuario_id)
            if not self._should_create_in_app(tipo=tipo, preferences=preferences):
                return None

            notificacion = Notificacion(
                usuario_id=usuario_id,
                tipo=tipo,
                titulo=titulo,
                mensaje=mensaje,
                referencia_id=referencia_id,
                leida=False,
            )
            self.db.add(notificacion)
            await self.db.flush()
            await self._record_delivery(
                notificacion_id=notificacion.id,
                canal=CanalNotificacion.IN_APP,
                estado=EstadoEntregaNotificacion.ENVIADA,
                detalle="Notificacion in-app creada",
            )
            await self._send_push_to_user(
                usuario_id=usuario_id,
                notificacion_id=notificacion.id,
                title=titulo,
                body=mensaje,
                data={
                    "tipo": tipo.value,
                    "scope": "user",
                },
            )

            if self._should_send_email(tipo=tipo, preferences=preferences) and email_data:
                try:
                    user_email = await self._get_user_email(usuario_id)
                    if user_email:
                        email_service = EmailService(self.db)
                        await email_service.send_email(
                            to_email=user_email,
                            template_key=email_data.get("template_key"),
                            context=email_data.get("context", {})
                        )
                        await self._record_delivery(
                            notificacion_id=notificacion.id,
                            canal=CanalNotificacion.EMAIL,
                            estado=EstadoEntregaNotificacion.ENVIADA,
                            detalle="Email despachado correctamente",
                        )
                except Exception as e:
                    print(f"[NOTIF] Error interno enviando email: {e}")
                    await self._record_delivery(
                        notificacion_id=notificacion.id,
                        canal=CanalNotificacion.EMAIL,
                        estado=EstadoEntregaNotificacion.FALLIDA,
                        detalle=str(e),
                    )

            await self.db.refresh(notificacion)
            return notificacion
        except Exception as exc:
            print(f"[NOTIF] create_for_user error: {exc}")
            return None

    async def dispatch_email_only(
        self,
        usuario_id,
        template_key: str,
        context: dict,
    ) -> None:
        try:
            preferences = await self.get_or_create_preferences(usuario_id)
            if not self._should_send_email(
                tipo=TipoNotificacion.RESERVA_APROBADA, # Generic proxy to check email_reservas
                preferences=preferences,
            ):
                return

            user_email = await self._get_user_email(usuario_id)
            if user_email:
                email_service = EmailService(self.db)
                await email_service.send_email(
                    to_email=user_email,
                    template_key=template_key,
                    context=context,
                )
        except Exception as exc:
            print(f"[NOTIF] dispatch_email_only error: {exc}")

    async def broadcast_to_all(
        self,
        tipo: TipoNotificacion,
        titulo: str,
        mensaje: str,
        referencia_id: str | None = None,
    ) -> None:
        try:
            result = await self.db.execute(select(Usuario.id).where(Usuario.activo == True))
            ids = [row[0] for row in result.all()]
            for user_id in ids:
                preferences = await self.get_or_create_preferences(user_id)
                if not self._should_create_in_app(tipo=tipo, preferences=preferences):
                    continue
                self.db.add(
                    Notificacion(
                        usuario_id=user_id,
                        tipo=tipo,
                        titulo=titulo,
                        mensaje=mensaje,
                        referencia_id=referencia_id,
                        leida=False,
                    )
                )
            await self.db.flush()
            await self._send_push_to_all(
                title=titulo,
                body=mensaje,
                data={
                    "tipo": tipo.value,
                    "scope": "broadcast",
                },
            )
        except Exception as exc:
            print(f"[NOTIF] broadcast_to_all error: {exc}")

    async def notify_admins(
        self,
        tipo: TipoNotificacion,
        titulo: str,
        mensaje: str,
        referencia_id: str | None = None,
        email_data: dict | None = None,
    ) -> None:
        """Envía una notificación a todos los usuarios con rol ADMIN o JEFE_ESTUDIOS."""
        try:
            from app.models.usuario import RolUsuario
            result = await self.db.execute(
                select(Usuario.id, Usuario.email, Usuario.nombre)
                .where(
                    Usuario.rol.in_([RolUsuario.ADMIN, RolUsuario.JEFE_ESTUDIOS]),
                    Usuario.activo == True,
                )
            )
            admins = result.all()
            
            for admin_id, admin_email, admin_name in admins:
                # In-app notification
                self.db.add(
                    Notificacion(
                        usuario_id=admin_id,
                        tipo=tipo,
                        titulo=titulo,
                        mensaje=mensaje,
                        referencia_id=referencia_id,
                        leida=False,
                    )
                )
                
                # Push notification
                await self._send_push_to_user(
                    usuario_id=admin_id,
                    notificacion_id=None, # Broadcast-like push doesn't strictly need a record
                    title=titulo,
                    body=mensaje,
                    data={
                        "tipo": tipo.value,
                        "scope": "admin_alert",
                    },
                )

                # Email notification
                if email_data and admin_email:
                    try:
                        email_service = EmailService(self.db)
                        context = email_data.get("context", {}).copy()
                        if "admin_name" not in context or context["admin_name"] is None:
                            context["admin_name"] = admin_name
                            
                        await email_service.send_email(
                            to_email=admin_email,
                            template_key=email_data.get("template_key"),
                            context=context
                        )
                    except Exception as e:
                        print(f"[NOTIF] Error enviando email a admin {admin_email}: {e}")

            await self.db.flush()
        except Exception as exc:
            print(f"[NOTIF] notify_admins error: {exc}")

    async def get_unread_count(self, usuario_id) -> int:
        try:
            result = await self.db.execute(
                select(func.count())
                .select_from(Notificacion)
                .where(Notificacion.usuario_id == usuario_id, Notificacion.leida == False)
            )
            return int(result.scalar_one() or 0)
        except Exception as exc:
            print(f"[NOTIF] get_unread_count error: {exc}")
            return 0

    async def list_unread(self, usuario_id, limit: int = 50) -> list[Notificacion]:
        try:
            result = await self.db.execute(
                select(Notificacion)
                .where(Notificacion.usuario_id == usuario_id, Notificacion.leida == False)
                .order_by(Notificacion.created_at.desc())
                .limit(limit)
            )
            return list(result.scalars().all())
        except Exception as exc:
            print(f"[NOTIF] list_unread error: {exc}")
            return []

    async def consume_unread(self, usuario_id, limit: int = 50) -> list[Notificacion]:
        try:
            unread = await self.list_unread(usuario_id=usuario_id, limit=limit)
            if unread:
                ids = [n.id for n in unread]
                await self.db.execute(
                    delete(NotificacionEntrega).where(
                        NotificacionEntrega.notificacion_id.in_(ids),
                        NotificacionEntrega.canal == CanalNotificacion.IN_APP,
                    )
                )
                for notification_id in ids:
                    self.db.add(
                        NotificacionEntrega(
                            notificacion_id=notification_id,
                            canal=CanalNotificacion.IN_APP,
                            estado=EstadoEntregaNotificacion.LEIDA,
                            detalle="Leida por el usuario",
                        )
                    )
                await self.db.execute(
                    delete(Notificacion)
                    .where(Notificacion.usuario_id == usuario_id, Notificacion.id.in_(ids))
                )
                await self.db.flush()
            return unread
        except Exception as exc:
            print(f"[NOTIF] consume_unread error: {exc}")
            return []

    async def delete_notification(self, usuario_id, notificacion_id: str) -> bool:
        try:
            result = await self.db.execute(
                delete(Notificacion).where(
                    Notificacion.usuario_id == usuario_id,
                    Notificacion.id == notificacion_id,
                )
            )
            await self.db.flush()
            return result.rowcount > 0
        except Exception as exc:
            print(f"[NOTIF] delete_notification error: {exc}")
            return False

    async def register_push_token(self, usuario_id, token: str, plataforma: str) -> None:
        try:
            result = await self.db.execute(
                select(DispositivoPush).where(
                    DispositivoPush.usuario_id == usuario_id,
                    DispositivoPush.token == token,
                )
            )
            existing = result.scalar_one_or_none()
            if existing:
                existing.activo = True
                existing.plataforma = plataforma
                await self.db.flush()
                return

            self.db.add(
                DispositivoPush(
                    usuario_id=usuario_id,
                    token=token,
                    plataforma=plataforma,
                    activo=True,
                )
            )
            await self.db.flush()
        except Exception as exc:
            print(f"[NOTIF] register_push_token error: {exc}")

    async def get_or_create_preferences(self, usuario_id) -> PreferenciasNotificacion:
        result = await self.db.execute(
            select(PreferenciasNotificacion).where(
                PreferenciasNotificacion.usuario_id == usuario_id
            )
        )
        preferences = result.scalar_one_or_none()
        if preferences is not None:
            return preferences

        preferences = PreferenciasNotificacion(usuario_id=usuario_id)
        try:
            async with self.db.begin_nested():
                self.db.add(preferences)
                await self.db.flush()
            return preferences
        except IntegrityError:
            # Another concurrent flow may create the same row first.
            result = await self.db.execute(
                select(PreferenciasNotificacion).where(
                    PreferenciasNotificacion.usuario_id == usuario_id
                )
            )
            existing = result.scalar_one_or_none()
            if existing is not None:
                return existing
            raise

    async def update_preferences(self, usuario_id, payload: dict) -> PreferenciasNotificacion:
        preferences = await self.get_or_create_preferences(usuario_id)
        for key, value in payload.items():
            if hasattr(preferences, key):
                setattr(preferences, key, value)
        await self.db.flush()
        await self.db.refresh(preferences)
        return preferences

    async def list_delivery_history(self, usuario_id, limit: int = 50) -> list[NotificacionEntrega]:
        result = await self.db.execute(
            select(NotificacionEntrega)
            .join(Notificacion, Notificacion.id == NotificacionEntrega.notificacion_id)
            .where(Notificacion.usuario_id == usuario_id)
            .order_by(NotificacionEntrega.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def _send_push_to_user(
        self,
        *,
        usuario_id,
        notificacion_id,
        title: str,
        body: str,
        data: dict[str, str],
    ) -> None:
        tokens = await self._get_active_tokens_for_user(usuario_id)
        await self._dispatch_push(
            notificacion_id=notificacion_id,
            tokens=tokens,
            title=title,
            body=body,
            data=data,
        )

    async def _send_push_to_all(
        self,
        *,
        title: str,
        body: str,
        data: dict[str, str],
    ) -> None:
        tokens = await self._get_all_active_tokens()
        await self._dispatch_push(
            notificacion_id=None,
            tokens=tokens,
            title=title,
            body=body,
            data=data,
        )

    async def _get_active_tokens_for_user(self, usuario_id) -> list[str]:
        result = await self.db.execute(
            select(DispositivoPush.token).where(
                DispositivoPush.usuario_id == usuario_id,
                DispositivoPush.activo == True,
            )
        )
        return list(result.scalars().all())

    async def _get_all_active_tokens(self) -> list[str]:
        result = await self.db.execute(
            select(DispositivoPush.token).where(DispositivoPush.activo == True)
        )
        return list(result.scalars().all())

    async def _dispatch_push(
        self,
        *,
        notificacion_id,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, str],
    ) -> None:
        try:
            push_service = get_push_notification_service()
            result = await push_service.send_to_tokens(
                tokens=tokens,
                title=title,
                body=body,
                data=data,
            )
            if notificacion_id is not None:
                if result.success_count > 0:
                    await self._record_delivery(
                        notificacion_id=notificacion_id,
                        canal=CanalNotificacion.PUSH,
                        estado=EstadoEntregaNotificacion.ENVIADA,
                        detalle=f"Push enviado a {result.success_count} dispositivo(s)",
                    )
                if result.failure_count > 0:
                    await self._record_delivery(
                        notificacion_id=notificacion_id,
                        canal=CanalNotificacion.PUSH,
                        estado=EstadoEntregaNotificacion.FALLIDA,
                        detalle=f"Push fallido en {result.failure_count} dispositivo(s)",
                    )
            if result.invalid_tokens:
                await self.db.execute(
                    delete(DispositivoPush).where(
                        DispositivoPush.token.in_(result.invalid_tokens)
                    )
                )
                await self.db.flush()
        except Exception as exc:
            print(f"[NOTIF] dispatch_push error: {exc}")
            if notificacion_id is not None:
                await self._record_delivery(
                    notificacion_id=notificacion_id,
                    canal=CanalNotificacion.PUSH,
                    estado=EstadoEntregaNotificacion.FALLIDA,
                    detalle=str(exc),
                )

    def _should_create_in_app(
        self,
        *,
        tipo: TipoNotificacion,
        preferences: PreferenciasNotificacion,
    ) -> bool:
        mapping = {
            TipoNotificacion.RESERVA_APROBADA: preferences.reserva_aprobada,
            TipoNotificacion.RESERVA_RECHAZADA: preferences.reserva_rechazada,
            TipoNotificacion.NUEVO_ESPACIO: preferences.nuevo_espacio,
            TipoNotificacion.NUEVO_SERVICIO: preferences.nuevo_servicio,
            TipoNotificacion.NUEVO_ANUNCIO: preferences.nuevo_anuncio,
            TipoNotificacion.NUEVA_ENCUESTA: preferences.nueva_encuesta,
            TipoNotificacion.RESERVA_CANCELADA: True,
            TipoNotificacion.NUEVA_RESERVA_PENDIENTE: True,
            TipoNotificacion.RESERVA_RECURRENTE_APROBADA: preferences.reserva_aprobada,
            TipoNotificacion.RESERVA_RECURRENTE_RECHAZADA: preferences.reserva_rechazada,
            TipoNotificacion.NUEVA_RESERVA_RECURRENTE_PENDIENTE: True,
            TipoNotificacion.LISTA_ESPERA_DISPONIBLE: preferences.lista_espera,
            TipoNotificacion.INCIDENCIA_RESUELTA: True,
            TipoNotificacion.RECARGA_TOKENS: True,
        }
        return mapping.get(tipo, True)

    def _should_send_email(
        self,
        *,
        tipo: TipoNotificacion,
        preferences: PreferenciasNotificacion,
    ) -> bool:
        if tipo == TipoNotificacion.NUEVO_ANUNCIO:
            return preferences.email_anuncios
        if tipo == TipoNotificacion.INCIDENCIA_RESUELTA:
            return preferences.email_incidencias
        if tipo == TipoNotificacion.RECARGA_TOKENS:
            return preferences.email_tokens
        return preferences.email_reservas

    async def _get_user_email(self, usuario_id) -> str | None:
        result = await self.db.execute(select(Usuario.email).where(Usuario.id == usuario_id))
        return result.scalar_one_or_none()

    async def _record_delivery(
        self,
        *,
        notificacion_id,
        canal: CanalNotificacion,
        estado: EstadoEntregaNotificacion,
        detalle: str | None = None,
    ) -> None:
        self.db.add(
            NotificacionEntrega(
                notificacion_id=notificacion_id,
                canal=canal,
                estado=estado,
                detalle=detalle,
            )
        )
        await self.db.flush()
