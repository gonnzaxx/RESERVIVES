"""
IES LUIS VIVES APP - Servicio de IA (Vivi).

Integración con Google Gemini para el asistente conversacional del instituto.
Incluye reintentos con backoff exponencial para errores 429/503.
"""

import asyncio
import logging
from pathlib import Path

import httpx

from app.config import get_settings
from app.utils.exceptions import ReservivesException

settings = get_settings()
logger = logging.getLogger("app.services.ai")


class AiService:

    # Caché del system prompt en memoria; se carga una sola vez desde disco
    _system_prompt: str | None = None

    # Carga el prompt de Vivi desde el archivo de texto; lo cachea en clase
    @classmethod
    def _get_system_prompt(cls) -> str:
        if cls._system_prompt is None:
            prompt_path = Path(__file__).parent.parent / "prompts" / "vivi.txt"
            cls._system_prompt = prompt_path.read_text(encoding="utf-8").strip()
        return cls._system_prompt

    # Envía un mensaje a Gemini con el historial de conversación.
    # Reintenta hasta 4 veces con backoff exponencial si recibe 429 o 503.
    # Devuelve el texto de respuesta o cadena vacía si no hay candidatos.
    async def chat(self, message: str, history: list[dict] | None = None) -> str:
        if not settings.GEMINI_API_KEY:
            raise ReservivesException(
                "La clave GEMINI_API_KEY no está configurada",
                status_code=503,
            )

        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL}:generateContent"
        )

        # Construye el historial en el formato que espera Gemini
        contents: list[dict] = []
        for item in (history or []):
            gemini_role = "user" if item.get("role") == "user" else "model"
            contents.append({"role": gemini_role, "parts": [{"text": item["content"]}]})
        contents.append({"role": "user", "parts": [{"text": message}]})

        payload = {
            "system_instruction": {
                "parts": [{"text": self._get_system_prompt()}]
            },
            "contents": contents,
        }
        headers = {
            "x-goog-api-key": settings.GEMINI_API_KEY,
            "Content-Type": "application/json",
        }

        max_attempts = 4
        base_delay = 0.5
        response: httpx.Response | None = None

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                for attempt in range(max_attempts):
                    if attempt > 0:
                        # Backoff exponencial: 0.5s, 1s, 2s...
                        delay = base_delay * (2 ** (attempt - 1))
                        await asyncio.sleep(delay)

                    response = await client.post(url, json=payload, headers=headers)
                    if response.status_code not in (429, 503):
                        break
                    logger.warning(
                        "vivi_request_retry",
                        extra={
                            "extra_data": {
                                "attempt": attempt + 1,
                                "status_code": response.status_code,
                            }
                        },
                    )
        except httpx.HTTPError as exc:
            raise ReservivesException(
                f"No se pudo conectar con Vivi: {exc}",
                status_code=503,
            )

        if response is None:
            raise ReservivesException(
                "No se obtuvo respuesta del servicio de IA",
                status_code=503,
            )

        if response.status_code >= 400:
            error_message = "Vivi no pudo procesar la solicitud"
            try:
                data = response.json()
                api_message = data.get("error", {}).get("message")
                if isinstance(api_message, str) and api_message.strip():
                    error_message = api_message.strip()
            except Exception:
                pass

            if response.status_code == 429:
                error_message = (
                    "Vivi está recibiendo demasiadas solicitudes. "
                    "Espera unos segundos e inténtalo de nuevo."
                )

            raise ReservivesException(
                error_message,
                status_code=response.status_code,
            )

        data = response.json()
        candidates = data.get("candidates", [])
        if not candidates:
            return ""

        content = candidates[0].get("content", {})
        parts = content.get("parts", [])
        if not parts:
            return ""

        return (parts[0].get("text") or "").strip()
