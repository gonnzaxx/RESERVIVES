"""
RESERVIVES - Configuración de la aplicación.

Carga las variables de entorno y proporciona acceso tipado
a la configuración mediante Pydantic Settings.
"""

from functools import lru_cache
from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuración global de la aplicación cargada desde variables de entorno."""

    # Base de datos
    DATABASE_URL: str = "postgresql+asyncpg://reservives:reservives_password@localhost:5432/reservives_db"

    # Servidor
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 1212
    APP_DEBUG: bool = True

    # Microsoft EntraID (OAuth2)
    AZURE_CLIENT_ID: str = "placeholder-client-id"
    AZURE_TENANT_ID: str = "placeholder-tenant-id"
    AZURE_CLIENT_SECRET: str = "placeholder-client-secret"
    AZURE_AUTHORITY: str = "https://login.microsoftonline.com/placeholder-tenant-id"

    # JWT para sesiones internas
    JWT_SECRET_KEY: str = "tu-clave-secreta"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Mapeo Azure AD/Entra ID -> rol interno
    # Formato: "<group_id>:<ROL>,<group_id>:<ROL>"
    AZURE_GROUP_ROLE_MAP: str = ""

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    # Tokens
    DEFAULT_MONTHLY_TOKENS: int = 20

    # SMTP (emails notificaciones)
    SMTP_ENABLED: bool = False
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = "tu-email@gmail.com"
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "tu-email@gmail.com"

    # Firebase Cloud Messaging
    FIREBASE_ENABLED: bool = False
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.example.json"
    FIREBASE_WEB_APP_URL: str = "http://localhost:3000"

    # IA (Gemini)
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"

    @property
    def cors_origins_list(self) -> list[str]:
        """Devuelve la lista de orígenes CORS permitidos."""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    @property
    def azure_group_role_map(self) -> dict[str, str]:
        """Devuelve el mapeo normalizado de group_id -> rol."""
        mapping: dict[str, str] = {}
        for chunk in self.AZURE_GROUP_ROLE_MAP.split(","):
            parsed = chunk.strip()
            if not parsed or ":" not in parsed:
                continue
            group_id, role = parsed.split(":", 1)
            group_id = group_id.strip().lower()
            role = role.strip().upper()
            if group_id and role:
                mapping[group_id] = role
        return mapping

    @property
    def firebase_credentials_abspath(self) -> Path:
        """Devuelve la ruta absoluta al JSON de service account de Firebase."""
        path = Path(self.FIREBASE_CREDENTIALS_PATH)
        if path.is_absolute():
            return path
        return (Path(__file__).resolve().parents[1] / path).resolve()

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    """Singleton cacheado de la configuración."""
    return Settings()
