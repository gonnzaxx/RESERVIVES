import enum

from app.models.usuario import RolUsuario

MAX_USER_TOKENS = 100


class BackofficeSection(str, enum.Enum):
    SUMMARY = "summary"
    USERS = "users"
    BOOKINGS = "bookings"
    POLLS = "polls"
    INCIDENTS = "incidents"
    METRICS = "metrics"
    SPACES = "spaces"
    SERVICES = "services"
    ANNOUNCEMENTS = "announcements"
    CAFETERIA = "cafeteria"
    CONFIGURATION = "configuration"


TOKEN_ROLES = {
    RolUsuario.ALUMNO,
    RolUsuario.PROFESOR,
    RolUsuario.SECRETARIA,
    RolUsuario.PROFESOR_SERVICIO,
}


def uses_tokens(rol: RolUsuario) -> bool:
    return rol in TOKEN_ROLES


def initial_tokens_for_role(rol: RolUsuario, alumno_tokens: int) -> int:
    if rol in {RolUsuario.PROFESOR, RolUsuario.SECRETARIA, RolUsuario.PROFESOR_SERVICIO}:
        return min(60, MAX_USER_TOKENS)
    if rol == RolUsuario.ALUMNO:
        return min(max(alumno_tokens, 0), MAX_USER_TOKENS)
    return 0


def monthly_tokens_for_role(rol: RolUsuario, alumno_tokens: int) -> int:
    if rol in {RolUsuario.PROFESOR, RolUsuario.SECRETARIA, RolUsuario.PROFESOR_SERVICIO}:
        return min(60, MAX_USER_TOKENS)
    if rol == RolUsuario.ALUMNO:
        return min(max(alumno_tokens, 0), MAX_USER_TOKENS)
    return 0


def can_access_main_app(rol: RolUsuario) -> bool:
    return rol != RolUsuario.CAFETERIA


def can_access_backoffice_section(rol: RolUsuario, section: BackofficeSection) -> bool:
    if rol == RolUsuario.ADMIN:
        return True

    if rol == RolUsuario.CAFETERIA:
        return section == BackofficeSection.CAFETERIA

    if rol == RolUsuario.JEFE_ESTUDIOS:
        return section not in {
            BackofficeSection.SUMMARY,
            BackofficeSection.INCIDENTS,
            BackofficeSection.CONFIGURATION,
        }

    if rol == RolUsuario.SECRETARIA:
        return section in {BackofficeSection.POLLS, BackofficeSection.ANNOUNCEMENTS}

    if rol == RolUsuario.PROFESOR_SERVICIO:
        return section == BackofficeSection.SERVICES

    return False


def has_any_backoffice_access(rol: RolUsuario) -> bool:
    return any(can_access_backoffice_section(rol, section) for section in BackofficeSection)
