"""
IES LUIS VIVES APP - Excepciones personalizadas.

Define excepciones de negocio que se traducen a respuestas HTTP.
"""


# Excepción base de la aplicación; todas las demás heredan de esta
class ReservivesException(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


# Recurso no encontrado en la base de datos
class NotFoundException(ReservivesException):
    def __init__(self, resource: str, id: str = ""):
        msg = f"{resource} no encontrado"
        if id:
            msg += f" (ID: {id})"
        super().__init__(msg, status_code=404)


# Conflicto de negocio, por ejemplo una reserva solapada
class ConflictException(ReservivesException):
    def __init__(self, message: str):
        super().__init__(message, status_code=409)


# Acción no permitida por el rol del usuario
class ForbiddenException(ReservivesException):
    def __init__(self, message: str = "No tienes permiso para realizar esta acción"):
        super().__init__(message, status_code=403)


# El usuario no tiene suficientes tokens para realizar la operación
class InsufficientTokensException(ReservivesException):
    def __init__(self, disponibles: int, necesarios: int):
        super().__init__(
            f"Tokens insuficientes: tienes {disponibles}, necesitas {necesarios}",
            status_code=400,
        )


# Error de validación de datos de negocio
class ValidationException(ReservivesException):
    def __init__(self, message: str):
        super().__init__(message, status_code=400)
