/// RESERVIVES - Tipos de errores de dominio
library;

sealed class AppFailure {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

// Sin internet o fallo en resolución DNS
class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Sin conexión a Internet']);
}

// El servidor devolvió un error 5xx o la conexión fue rechazada
class ServerFailure extends AppFailure {
  const ServerFailure([
    super.message = 'El servidor no está disponible en este momento',
  ]);
}

// 401 — El token ha caducado o no es válido
class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Tu sesión ha expirado. Inicia sesión de nuevo.',
  ]);
}

// Errores genéricos de cliente (400, 403, 404, 409 …).
class ClientFailure extends AppFailure {
  final int? statusCode;
  const ClientFailure(super.message, {this.statusCode});
}

// Desconocidos
class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Ha ocurrido un error inesperado']);
}
