"""
Servicio de envio de email via Microsoft Graph.
"""

from datetime import datetime
from pathlib import Path

import httpx

from app.config import get_settings
from app.utils.datetime_utils import format_normalize


# dict que devuelve "-" para claves ausentes, evita KeyError al renderizar templates
class _SafeDict(dict):
    def __missing__(self, key):
        return "-"


class EmailService:
    def __init__(self, db=None):
        self.db = db
        self.settings = get_settings()
        self.template_dir = Path(__file__).resolve().parents[2] / "templates" / "email"

    # Carga un template HTML y sustituye las variables del contexto
    def _load_html_template(self, template_file: str, context: dict) -> str:
        template_path = self.template_dir / template_file
        if not template_path.exists():
            raise FileNotFoundError(f"Template no encontrado: {template_path}")
        html = template_path.read_text(encoding="utf-8")
        return html.format_map(_SafeDict(context))

    # Formatea un datetime ISO string al formato local del instituto
    def _format_datetime_value(self, raw: str) -> str:
        try:
            parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                return raw
            return format_normalize(parsed)
        except Exception:
            return raw

    # Prepara el contexto del template: normaliza fechas y rellena campos opcionales
    def _prepare_context(self, context: dict) -> dict:
        prepared = dict(context)
        for field in ("inicio", "fin"):
            value = prepared.get(field)
            if isinstance(value, str) and value:
                prepared[field] = self._format_datetime_value(value)
        prepared.setdefault("motivo", "Consulta con administracion si necesitas mas informacion.")
        prepared.setdefault("estado", "PENDIENTE")
        return prepared

    # Resuelve asunto y HTML según la clave de template; usa default si no coincide ninguna
    def _render_template(self, template_key: str, context: dict) -> tuple[str, str]:
        safe_context = self._prepare_context(context)

        if template_key == "reserva_creada":
            subject = "IES LUIS VIVES | Reserva registrada"
            html = self._load_html_template("reserva_creada.html", safe_context)
            return subject, html

        if template_key == "reserva_aprobada":
            subject = "IES LUIS VIVES | Reserva aprobada"
            html = self._load_html_template("reserva_aprobada.html", safe_context)
            return subject, html

        if template_key == "reserva_servicio_aprobada":
            subject = "IES LUIS VIVES | Reserva de servicio aprobada"
            html = self._load_html_template("reserva_servicio_aprobada.html", safe_context)
            return subject, html

        if template_key == "reserva_servicio_rechazada":
            subject = "IES LUIS VIVES | Reserva de servicio rechazada"
            html = self._load_html_template("reserva_servicio_rechazada.html", safe_context)
            return subject, html

        if template_key == "reserva_aula_profesor_aprobada":
            subject = "IES LUIS VIVES | Reserva de aula aprobada"
            html = self._load_html_template("reserva_aula_profesor_aprobada.html", safe_context)
            return subject, html

        if template_key == "reserva_aula_profesor_rechazada":
            subject = "IES LUIS VIVES | Reserva de aula rechazada"
            html = self._load_html_template("reserva_aula_profesor_rechazada.html", safe_context)
            return subject, html

        if template_key == "reserva_rechazada":
            subject = "IES LUIS VIVES | Reserva rechazada"
            html = self._load_html_template("reserva_rechazada.html", safe_context)
            return subject, html

        if template_key == "reserva_cancelada":
            subject = "IES LUIS VIVES | Reserva cancelada"
            html = self._load_html_template("reserva_cancelada.html", safe_context)
            return subject, html

        if template_key == "admin_nueva_reserva_pendiente":
            subject = "IES LUIS VIVES | Nueva reserva pendiente"
            html = self._load_html_template("admin_nueva_reserva_pendiente.html", safe_context)
            return subject, html

        if template_key == "recarga_tokens":
            subject = "IES LUIS VIVES | Tus tokens han sido recargados"
            html = self._load_html_template("recarga_tokens.html", safe_context)
            return subject, html

        if template_key == "incidencia_reportada":
            subject = "IES LUIS VIVES | Nueva Incidencia Reportada"
            html = self._load_html_template("incidencia_reportada.html", safe_context)
            return subject, html

        if template_key == "incidencia_resuelta":
            subject = "IES LUIS VIVES | Incidencia Resuelta"
            html = self._load_html_template("incidencia_resuelta.html", safe_context)
            return subject, html

        subject = "IES LUIS VIVES | Notificación"
        html = self._load_html_template("default_notificacion.html", safe_context)
        return subject, html

    # Obtiene un access token de Microsoft Graph usando client_credentials
    async def _get_access_token(self, client: httpx.AsyncClient) -> str:
        token_url = (
            f"https://login.microsoftonline.com/{self.settings.AZURE_TENANT_ID}"
            "/oauth2/v2.0/token"
        )
        resp = await client.post(token_url, data={
            "grant_type": "client_credentials",
            "client_id": self.settings.AZURE_CLIENT_ID,
            "client_secret": self.settings.AZURE_CLIENT_SECRET,
            "scope": "https://graph.microsoft.com/.default",
        })
        resp.raise_for_status()
        return resp.json()["access_token"]

    # Envía un email via Microsoft Graph; aborta si no hay remitente configurado
    async def send_email(self, to_email: str, template_key: str, context: dict) -> None:
        from_email = self.settings.GRAPH_FROM_EMAIL
        if not from_email:
            return

        try:
            subject, html = self._render_template(template_key, context)
            async with httpx.AsyncClient(timeout=15) as client:
                access_token = await self._get_access_token(client)
                payload = {
                    "message": {
                        "subject": subject,
                        "body": {"contentType": "HTML", "content": html},
                        "toRecipients": [{"emailAddress": {"address": to_email}}],
                    },
                    "saveToSentItems": False,
                }
                resp = await client.post(
                    f"https://graph.microsoft.com/v1.0/users/{from_email}/sendMail",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                resp.raise_for_status()
        except Exception as exc:
            print(f"[EMAIL] Error enviando correo a {to_email}: {exc}")

    # Notifica a un admin que se ha reportado una nueva incidencia
    async def send_incidence_report(self, to_email: str, admin_name: str, user_name: str, description: str, created_at: datetime) -> None:
        context = {
            "admin_name": admin_name,
            "user_name": user_name,
            "description": description,
            "created_at": format_normalize(created_at)
        }
        await self.send_email(to_email, "incidencia_reportada", context)

    # Notifica al usuario que su incidencia ha sido resuelta
    async def send_incidence_resolution(self, to_email: str, user_name: str, description: str, resolution: str) -> None:
        context = {
            "user_name": user_name,
            "description": description,
            "resolution": resolution
        }
        await self.send_email(to_email, "incidencia_resuelta", context)
