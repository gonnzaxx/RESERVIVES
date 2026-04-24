"""
Repositorio de Usuarios.

Aquuí se encuentran las operaciones de acceso a datos para la entidad Usuario.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.usuario import Usuario, RolUsuario
from app.repositories.base import BaseRepository


class UsuarioRepository(BaseRepository[Usuario]):

    def __init__(self, session: AsyncSession):
        super().__init__(Usuario, session)

    async def get_by_email(self, email: str) -> Usuario | None:
        """Busca un usuario por su email."""
        result = await self.session.execute(
            select(Usuario).where(Usuario.email == email)
        )
        return result.scalar_one_or_none()

    async def get_by_microsoft_id(self, microsoft_id: str) -> Usuario | None:
        """Busca un usuario por su ID de Microsoft EntraID."""
        result = await self.session.execute(
            select(Usuario).where(Usuario.microsoft_id == microsoft_id)
        )
        return result.scalar_one_or_none()

    async def get_by_rol(
        self, rol: RolUsuario, skip: int = 0, limit: int = 100
    ) -> list[Usuario]:
        """Obtiene todos los usuarios con el rol deseado."""
        result = await self.session.execute(
            select(Usuario)
            .where(Usuario.rol == rol)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_active_students(self) -> list[Usuario]:
        """Obtiene todos los alumnos activos. Esto nos sirve para la recarga mensual de tokens."""
        result = await self.session.execute(
            select(Usuario)
            .where(Usuario.rol == RolUsuario.ALUMNO)
            .where(Usuario.activo == True)
        )
        return list(result.scalars().all())

    async def get_active_users_for_monthly_tokens(self) -> list[Usuario]:
        """Obtiene usuarios activos con roles que usan tokens."""
        result = await self.session.execute(
            select(Usuario)
            .where(
                Usuario.rol.in_(
                    [
                        RolUsuario.ALUMNO,
                        RolUsuario.PROFESOR,
                        RolUsuario.SECRETARIA,
                        RolUsuario.PROFESOR_SERVICIO,
                    ]
                )
            )
            .where(Usuario.activo == True)
        )
        return list(result.scalars().all())

    async def update_tokens(self, usuario_id, nuevos_tokens: int) -> Usuario | None:
        """Actualiza los tokens de un usuario."""
        usuario = await self.get_by_id(usuario_id)
        if usuario:
            usuario.tokens = nuevos_tokens
            await self.session.flush()
            await self.session.refresh(usuario)
        return usuario
