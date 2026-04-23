import pytest
from app.services.email_service import EmailService
from app.config import Settings

class DummySettings(Settings):
    SMTP_ENABLED: bool = False
    SMTP_AUDIT_EMAIL: str = ""

def test_render_template_reserva_creada(monkeypatch):
    monkeypatch.setattr("app.services.email_service.get_settings", DummySettings)
    service = EmailService(None)

    subject, text, html = service._render_template(
        template_key="reserva_creada",
        context={
            "nombre": "Test User",
            "recurso": "Pista de Padel",
            "inicio": "10:00",
            "fin": "11:00",
            "estado": "PENDIENTE",
        }
    )

    assert subject == "RESERVIVES | Reserva registrada"

    assert "Hola Test User," in text
    assert "Pista de Padel" in text

    
    assert "<!DOCTYPE html>" in html
    assert "Hola Test User" in html
    assert "Pista de Padel" in html
    assert "PENDIENTE" in html

def test_default_template_fallback(monkeypatch):
    monkeypatch.setattr("app.services.email_service.get_settings", DummySettings)
    service = EmailService(None)

    subject, text, html = service._render_template(
        template_key="clave_inexistente",
        context={}
    )

    assert subject == "RESERVIVES | Notificacion"
    assert "Nueva notif" in html
