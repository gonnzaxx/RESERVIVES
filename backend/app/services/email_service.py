"""
Servicio de envio de email con templates HTML externos.
"""

from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
import smtplib

from app.config import get_settings
from app.utils.datetime_utils import format_for_humans
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.configuracion import Configuracion


class _SafeDict(dict):
    def __missing__(self, key):
        return "-"


class EmailService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.settings = get_settings()
        self.template_dir = Path(__file__).resolve().parents[2] / "templates" / "email"

    def _load_html_template(self, template_file: str, context: dict) -> str:
        template_path = self.template_dir / template_file
        if not template_path.exists():
            raise FileNotFoundError(f"Template no encontrado: {template_path}")
        html = template_path.read_text(encoding="utf-8")
        return html.format_map(_SafeDict(context))

    def _format_datetime_value(self, raw: str) -> str:
        try:
            parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                return raw
            return format_for_humans(parsed)
        except Exception:
            return raw

    def _prepare_context(self, context: dict) -> dict:
        prepared = dict(context)
        for field in ("inicio", "fin"):
            value = prepared.get(field)
            if isinstance(value, str) and value:
                prepared[field] = self._format_datetime_value(value)
        prepared.setdefault("motivo", "Consulta con administracion si necesitas mas informacion.")
        prepared.setdefault("estado", "PENDIENTE")
        return prepared

    def _render_template(self, template_key: str, context: dict) -> tuple[str, str, str]:
        safe_context = self._prepare_context(context)

        if template_key == "reserva_creada":
            subject = "RESERVIVES | Reserva registrada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva ha sido registrada correctamente:

- Recurso: {safe_context.get("recurso", "-")}
- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}
- Estado inicial: {safe_context.get("estado", "PENDIENTE")}

Equipo RESERVIVES.

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_creada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_aprobada":
            subject = "RESERVIVES | Reserva aprobada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva de "{safe_context.get("recurso", "-")}" ha sido APROBADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_aprobada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_servicio_aprobada":
            subject = "RESERVIVES | Reserva de servicio aprobada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva del servicio "{safe_context.get("recurso", "-")}" ha sido APROBADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_servicio_aprobada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_servicio_rechazada":
            subject = "RESERVIVES | Reserva de servicio rechazada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva del servicio "{safe_context.get("recurso", "-")}" ha sido RECHAZADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}
- Motivo: {safe_context.get("motivo", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_servicio_rechazada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_aula_profesor_aprobada":
            subject = "RESERVIVES | Reserva de aula aprobada"
            text = f"""
Hola {safe_context.get("nombre", "profesor/a")},

Tu reserva de aula "{safe_context.get("recurso", "-")}" ha sido APROBADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_aula_profesor_aprobada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_aula_profesor_rechazada":
            subject = "RESERVIVES | Reserva de aula rechazada"
            text = f"""
Hola {safe_context.get("nombre", "profesor/a")},

Tu reserva de aula "{safe_context.get("recurso", "-")}" ha sido RECHAZADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}
- Motivo: {safe_context.get("motivo", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_aula_profesor_rechazada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_rechazada":
            subject = "RESERVIVES | Reserva rechazada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva de "{safe_context.get("recurso", "-")}" ha sido RECHAZADA.

- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}
- Motivo: {safe_context.get("motivo", "-")}

Equipo RESERVIVES

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_rechazada.html", safe_context)
            return subject, text, html

        if template_key == "reserva_cancelada":
            subject = "RESERVIVES | Reserva cancelada"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tu reserva de "{safe_context.get("recurso", "-")}" ha sido CANCELADA correctamente.

- Inicio: {safe_context.get("inicio", "-")}

Los tokens asociados (si los hubiera) han sido devueltos a tu cuenta.

Equipo RESERVIVES.

Por favor, no responder a este correo.
""".strip()
            html = self._load_html_template("reserva_cancelada.html", safe_context)
            return subject, text, html

        if template_key == "admin_nueva_reserva_pendiente":
            subject = "RESERVIVES Admin | Nueva reserva pendiente"
            text = f"""
Atencion Administrador,

Hay una nueva solicitud de reserva que requiere tu aprobacion:

- Usuario: {safe_context.get("usuario", "-")}
- Recurso: {safe_context.get("recurso", "-")}
- Inicio: {safe_context.get("inicio", "-")}
- Fin: {safe_context.get("fin", "-")}

Accede al panel de administracion para gestionarla.

Equipo RESERVIVES.
""".strip()
            html = self._load_html_template("admin_nueva_reserva_pendiente.html", safe_context)
            return subject, text, html

        if template_key == "recarga_tokens":
            subject = "RESERVIVES | Tus tokens han sido recargados"
            text = f"""
Hola {safe_context.get("nombre", "usuario")},

Tus tokens han sido recargados.
Saldo actual: {safe_context.get("cantidad", "0")} tokens.

Ya puedes realizar nuevas reservas para este mes.

Equipo RESERVIVES
""".strip()
            html = self._load_html_template("recarga_tokens.html", safe_context)
            return subject, text, html

        if template_key == "incidencia_reportada":
            subject = "RESERVIVES Admin | Nueva Incidencia Reportada"
            text = f"Hola {safe_context.get('admin_name')}, hay una nueva incidencia de {safe_context.get('user_name')}."
            html = self._load_html_template("incidencia_reportada.html", safe_context)
            return subject, text, html

        if template_key == "incidencia_resuelta":
            subject = "RESERVIVES | Incidencia Resuelta"
            text = f"Hola {safe_context.get('user_name')}, tu incidencia ha sido resuelta."
            html = self._load_html_template("incidencia_resuelta.html", safe_context)
            return subject, text, html

        subject = "RESERVIVES | Notificacion"
        text = "Tienes una nueva notificacion de RESERVIVES."
        html = self._load_html_template("default_notificacion.html", safe_context)
        return subject, text, html

    async def send_email(self, to_email: str, template_key: str, context: dict) -> None:
        # Recuperar configuracion de BD para SMTP_ENABLED y SMTP_FROM_EMAIL
        result_enabled = await self.db.execute(select(Configuracion).where(Configuracion.clave == 'smtp_enabled'))
        conf_enabled = result_enabled.scalar_one_or_none()
        smtp_enabled_str = conf_enabled.valor.lower() if conf_enabled else str(self.settings.SMTP_ENABLED).lower()
        smtp_enabled = smtp_enabled_str in ('1', 'true', 'yes', 'si', 'on')

        if not smtp_enabled:
            return

        result_from = await self.db.execute(select(Configuracion).where(Configuracion.clave == 'smtp_from_email'))
        conf_from = result_from.scalar_one_or_none()
        smtp_from_email = conf_from.valor if conf_from and conf_from.valor.strip() else self.settings.SMTP_FROM_EMAIL

        try:
            subject, text, html = self._render_template(template_key, context)
            msg = MIMEMultipart("alternative")
            msg["From"] = smtp_from_email
            msg["To"] = to_email
            audit_email = getattr(self.settings, 'SMTP_AUDIT_EMAIL', None)
            if audit_email:
                msg["Cc"] = audit_email
            msg["Subject"] = subject
            msg.attach(MIMEText(text, "plain", "utf-8"))
            msg.attach(MIMEText(html, "html", "utf-8"))

            recipients = [to_email]
            if audit_email:
                recipients.append(audit_email)

            with smtplib.SMTP(self.settings.SMTP_HOST, self.settings.SMTP_PORT) as server:
                server.starttls()
                server.login(self.settings.SMTP_USERNAME, self.settings.SMTP_PASSWORD)
                server.sendmail(smtp_from_email, recipients, msg.as_string())
        except Exception as exc:
            print(f"[EMAIL] Error enviando correo: {exc}")

    async def send_incidence_report(self, to_email: str, admin_name: str, user_name: str, description: str, created_at: datetime) -> None:
        context = {
            "admin_name": admin_name,
            "user_name": user_name,
            "description": description,
            "created_at": format_for_humans(created_at)
        }
        await self.send_email(to_email, "incidencia_reportada", context)

    async def send_incidence_resolution(self, to_email: str, user_name: str, description: str, resolution: str) -> None:
        context = {
            "user_name": user_name,
            "description": description,
            "resolution": resolution
        }
        await self.send_email(to_email, "incidencia_resuelta", context)
