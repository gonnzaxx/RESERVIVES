import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models.usuario import RolUsuario


# --- Schemas de respuesta (output) ---

class UsuarioResponse(BaseModel):
    """Schema de respuesta para un usuario."""
    id: uuid.UUID
    nombre: str
    apellidos: str
    email: str
    avatar_url: str | None = None
    rol: RolUsuario
    tokens: int
    activo: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UsuarioResumen(BaseModel):
    """Schema reducido de usuario (para listas y relaciones)."""
    id: uuid.UUID
    nombre: str
    apellidos: str
    email: str
    rol: RolUsuario
    activo: bool

    class Config:
        from_attributes = True


# --- Schemas de entrada (input) ---

class UsuarioCreate(BaseModel):
    """Schema para crear un usuario (usado internamente tras login con EntraID)."""
    nombre: str = Field(..., min_length=1, max_length=100)
    apellidos: str = Field(..., min_length=1, max_length=150)
    email: EmailStr
    microsoft_id: str | None = None
    avatar_url: str | None = None
    rol: RolUsuario = RolUsuario.ALUMNO


class UsuarioUpdate(BaseModel):
    """Schema para actualizar un usuario."""
    nombre: str | None = Field(None, min_length=1, max_length=100)
    apellidos: str | None = Field(None, min_length=1, max_length=150)
    avatar_url: str | None = None
    rol: RolUsuario | None = None
    tokens: int | None = None
    activo: bool | None = None


# --- Schemas de autenticación ---

class TokenResponse(BaseModel):
    """Respuesta con el token JWT tras autenticación."""
    access_token: str
    token_type: str = "bearer"
    user: UsuarioResponse


class LoginRequest(BaseModel):
    """Petición de login con token de Microsoft EntraID."""
    microsoft_token: str

class DevLoginRequest(BaseModel):
    """Peticion de login de desarrollo sin OAuth (controlado por configuracion)."""
    email: EmailStr | None = None
