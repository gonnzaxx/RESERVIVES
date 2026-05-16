library;

import 'package:url_launcher/url_launcher.dart';

/// Utilidades para interactuar con aplicaciones de calendario externas (Google Calendar).
class CalendarUtils {

  /// Genera un evento y abre Google Calendar en el navegador o aplicación.
  ///
  /// Utiliza el formato de URL "TEMPLATE" de Google para pre-rellenar los campos
  /// del evento.
  ///
  /// [title]: El nombre del evento que aparecerá en el calendario.
  /// [startTime]: Fecha y hora de inicio (se convierte automáticamente a UTC).
  /// [endTime]: Fecha y hora de finalización (se convierte automáticamente a UTC).
  /// [location]: Dirección física o nombre del lugar (opcional).
  /// [details]: Descripción o notas adicionales del evento (opcional).
  static Future<void> addToCalendar({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? details,
  }) async {
    // Formatea las fechas al estándar de Google Calendar (YYYYMMDDTHHmmSSZ).
    // Se eliminan guiones, puntos y dos puntos para cumplir con el formato ISO 8601 compacto.
    final startStr = startTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';
    final endStr = endTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';

    // Construcción de la URI con los parámetros codificados para evitar errores con espacios o caracteres especiales.
    final url = Uri.parse(
        'https://www.google.com/calendar/render?'
            'action=TEMPLATE&'
            'text=${Uri.encodeComponent(title)}&'
            'dates=$startStr/$endStr&'
            'details=${Uri.encodeComponent(details ?? '')}&'
            'location=${Uri.encodeComponent(location ?? '')}'
    );

    // Intenta lanzar la URL en una aplicación externa (navegador o app de Google Calendar).
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
