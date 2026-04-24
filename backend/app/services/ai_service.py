import httpx

from app.config import get_settings
from app.utils.exceptions import ReservivesException

settings = get_settings()


class AiService:
    async def chat(self, message: str) -> str:
        if not settings.GEMINI_API_KEY:
            raise ReservivesException(
                "La clave GEMINI_API_KEY no está configurada",
                status_code=503,
            )

        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL}:generateContent?key={settings.GEMINI_API_KEY}"
        )
        payload = {
            "contents": [{"parts": [{"text": message}]}],
        }

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.post(url, json=payload)
        except httpx.HTTPError as exc:
            raise ReservivesException(
                f"No se pudo conectar con Gemini: {exc}",
                status_code=503,
            )

        if response.status_code >= 400:
            raise ReservivesException(
                "Gemini no pudo procesar la solicitud",
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
