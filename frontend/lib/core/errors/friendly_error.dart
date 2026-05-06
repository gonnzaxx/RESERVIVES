/// Utilidades para la gestión de errores orientada al usuario final.
///
/// Este archivo se encarga de interceptar las excepciones técnicas y
/// transformarlas en mensajes amigables y localizados.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

/// Esta función centraliza la lógica de comunicación de errores de la app.
/// Analiza el tipo de [error] y devuelve una cadena de texto descriptiva.
///
/// [error]: El objeto de excepción capturado (usualmente desde un [catch] o [AsyncValue]).
/// [fallback]: El mensaje que se mostrará si no se reconoce el error específico.
///

String toFriendlyErrorMessage(
    Object? error, {
      String fallback = 'Error al conectar con el servidor',
    }) {
  if (error == null) return fallback;

  // Manejo de excepciones específicas de la API
  if (error is ApiException) {
    // 1. Errores de Autenticación
    if (error.statusCode == 401) {
      return 'Tu sesión ha expirado. Inicia sesión de nuevo.';
    }

    final msg = error.message.trim();

    /// Diccionario de códigos de error del backend.
    ///
    /// Mapea las constantes de negocio definidas en el servidor a
    /// explicaciones claras para el usuario
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

    // 2. Errores de Infraestructura (500s)
    if (error.statusCode >= 500) {
      return 'Error temporal en el servidor. Inténtalo de nuevo más tarde.';
    }

    // Si el mensaje es genérico o vacío, usamos el fallback
    if (msg.isEmpty || msg.toLowerCase().startsWith('apiexception')) {
      return fallback;
    }
    return msg;
  }

  // Desempaquetado de errores de Riverpod (AsyncValue)
  if (error is AsyncError) {
    return toFriendlyErrorMessage(error.error, fallback: fallback);
  }

  return fallback;
}
