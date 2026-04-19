library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

String toFriendlyErrorMessage(
    Object? error, {
      String fallback = 'Error al conectar con el servidor',
    }) {
  if (error == null) return fallback;

  if (error is ApiException) {
    if (error.statusCode == 401) {
      return 'Tu sesión ha expirado. Inicia sesión de nuevo.';
    }

    final msg = error.message.trim();

    // Mapeo de errores del backend a mensajes no técnicos para el usuario
    final errorMappings = {
      'ESPACIO_OCUPADO': 'Este horario ya está ocupado por otra reserva.',
      'ESPACIO_CERRADO': 'El espacio está cerrado en el horario seleccionado.',
      'LIMITE_RESERVAS_DIARIAS': 'Has alcanzado tu límite de reservas para hoy.',
      'USUARIO_BLOQUEADO': 'Tu cuenta tiene restringida la realización de reservas.',
      'TIEMPO_MINIMO_ANTELACION': 'Debes reservar con más antelación.',
      'DURACION_INVALIDA': 'La duración de la reserva no es válida.',
      'CONFIRMACION_REQUERIDA': 'Este espacio requiere confirmación previa.',
    };

    if (errorMappings.containsKey(msg)) {
      return errorMappings[msg]!;
    }

    if (error.statusCode >= 500) {
      return 'Error temporal en el servidor. Inténtalo de nuevo más tarde.';
    }

    if (msg.isEmpty || msg.toLowerCase().startsWith('apiexception')) {
      return fallback;
    }
    return msg;
  }

  if (error is AsyncError) {
    return toFriendlyErrorMessage(error.error, fallback: fallback);
  }

  return fallback;
}
