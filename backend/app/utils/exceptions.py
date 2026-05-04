"""
RESERVIVES - Excepciones personalizadas.

Define excepciones de negocio que se traducen a respuestas HTTP.
"""


class ReservivesException(Exception):
    """Excepción base de la aplicación."""

    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class NotFoundException(ReservivesException):
    """Recurso no encontrado."""

    def __init__(self, resource: str, id: str = ""):
        msg = f"{resource} no encontrado"
        if id:
            msg += f" (ID: {id})"
        super().__init__(msg, status_code=404)


class ConflictException(ReservivesException):
    """Conflicto de negocio (ej: reserva solapada)."""

    def __init__(self, message: str):
        super().__init__(message, status_code=409)


class ForbiddenException(ReservivesException):
    """Acción no permitida por el rol del usuario."""

    def __init__(self, message: str = "No tienes permiso para realizar esta acción"):
        super().__init__(message, status_code=403)


class InsufficientTokensException(ReservivesException):
    """El usuario no tiene suficientes tokens."""

    def __init__(self, disponibles: int, necesarios: int):
        super().__init__(
            f"Tokens insuficientes: tienes {disponibles}, necesitas {necesarios}",
            status_code=400,
        )


class ValidationException(ReservivesException):
    """Error de validación de datos de negocio."""

    def __init__(self, message: str):
        super().__init__(message, status_code=400)
