import enum

from app.models.usuario import RolUsuario

MAX_USER_TOKENS = 100


class BackofficeSection(str, enum.Enum):
    SUMMARY = "summary"
    USERS = "users"
    BOOKINGS = "bookings"
    HISTORY = "history"
    POLLS = "polls"
    INCIDENTS = "incidents"
    METRICS = "metrics"
    SPACES = "spaces"
    SERVICES = "services"
    ANNOUNCEMENTS = "announcements"
    CAFETERIA = "cafeteria"
    CONFIGURATION = "configuration"
    AZURE = "azure"


# Roles que no consumen tokens (acceso ilimitado)
_UNLIMITED_TOKEN_ROLES = {RolUsuario.ADMINISTRADOR.value, RolUsuario.JEFATURA.value}


# Normaliza un rol (enum o string) a su valor en mayúsculas
def _rol_str(rol) -> str:
    return rol.value if hasattr(rol, "value") else str(rol).upper()


# Devuelve True si el rol consume tokens; los roles custom también los consumen
def uses_tokens(rol) -> bool:
    return _rol_str(rol) not in _UNLIMITED_TOKEN_ROLES


# Tokens iniciales según el rol: 0 para roles sin límite, nivel alumno/profesor para el resto
def initial_tokens_for_role(rol, alumno_tokens: int, profesor_tokens: int) -> int:
    rol_value = _rol_str(rol)
    if rol_value in _UNLIMITED_TOKEN_ROLES:
        return 0
    if rol_value == RolUsuario.ALUMNO.value:
        return min(max(alumno_tokens, 0), MAX_USER_TOKENS)
    # Roles de staff y roles custom → nivel profesor como fallback
    return min(max(profesor_tokens, 0), MAX_USER_TOKENS)


# Tokens de recarga mensual según el rol
def monthly_tokens_for_role(rol, alumno_tokens: int, profesor_tokens: int) -> int:
    rol_value = _rol_str(rol)
    if rol_value in _UNLIMITED_TOKEN_ROLES:
        return 0
    if rol_value == RolUsuario.ALUMNO.value:
        return min(max(alumno_tokens, 0), MAX_USER_TOKENS)
    # Roles de staff y roles custom → nivel profesor como fallback
    return min(max(profesor_tokens, 0), MAX_USER_TOKENS)


# Todos los roles tienen acceso a la app principal
def can_access_main_app(rol: RolUsuario) -> bool:
    return True


# Comprueba si un rol puede acceder a una sección del backoffice
def can_access_backoffice_section(rol: RolUsuario, section: BackofficeSection) -> bool:
    if rol == RolUsuario.ADMINISTRADOR:
        return True

    if rol == RolUsuario.CAFETERIA:
        return section == BackofficeSection.CAFETERIA

    if rol == RolUsuario.JEFATURA:
        return section not in {BackofficeSection.CONFIGURATION, BackofficeSection.AZURE}

    if rol == RolUsuario.SECRETARIA:
        return section in {
            BackofficeSection.METRICS,
            BackofficeSection.POLLS,
            BackofficeSection.ANNOUNCEMENTS,
            BackofficeSection.INCIDENTS,
        }

    if rol == RolUsuario.GESTOR_SERVICIO:
        return section in {
            BackofficeSection.HISTORY,
            BackofficeSection.BOOKINGS,
            BackofficeSection.SERVICES,
            BackofficeSection.METRICS,
        }

    if rol == RolUsuario.CONTROL:
        return section in {BackofficeSection.BOOKINGS, BackofficeSection.HISTORY}

    return False


# Devuelve True si el rol tiene acceso a al menos una sección del backoffice
def has_any_backoffice_access(rol: RolUsuario) -> bool:
    return any(can_access_backoffice_section(rol, section) for section in BackofficeSection)
