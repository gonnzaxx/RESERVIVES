import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reservives/i10n/app_localizations.dart';

/// Calcula la fecha del próximo día laboral (lunes a viernes).
///
/// Si la [date] proporcionada cae en fin de semana, devuelve el lunes siguiente.
/// Si es un día de semana, devuelve la misma fecha.
///
/// Útil para lógicas de asignación de citas o vencimientos que no deben ocurrir
/// en sábados o domingos.
DateTime nextWeekdayDate(DateTime date) {
  if (date.weekday == DateTime.saturday) {
    return date.add(const Duration(days: 2));
  }
  if (date.weekday == DateTime.sunday) {
    return date.add(const Duration(days: 1));
  }
  return date;
}

/// Convierte una [DateTime] en una cadena de texto amigable y localizada
/// basada en la proximidad con el momento actual (p. ej., "hace 5 min").
///
/// Lógica de visualización:
/// - Menos de 1 minuto: "Ahora mismo".
/// - Menos de 1 hora: "Hace X minutos".
/// - Menos de 24 horas: "Hace X horas".
/// - Exactamente 1 día: "Ayer".
/// - Menos de 7 días: "Hace X días".
/// - Más de 7 días: Fecha absoluta formateada (p. ej., "12 May 2024").
///
/// Requiere un [BuildContext] para acceder a las traducciones (`context.tr`)
/// y al idioma actual del dispositivo para el formato absoluto.
String formatRelativeDate(DateTime date, BuildContext context) {
  final diff = DateTime.now().difference(date);

  if (diff.inMinutes < 1) {
    return context.tr('time.justNow');
  }

  if (diff.inMinutes < 60) {
    return context.tr('time.minutesAgo').replaceAll('{n}', '${diff.inMinutes}');
  }

  if (diff.inHours < 24) {
    return context.tr('time.hoursAgo').replaceAll('{n}', '${diff.inHours}');
  }

  if (diff.inDays == 1) {
    return context.tr('time.yesterday');
  }

  if (diff.inDays < 7) {
    return context.tr('time.daysAgo').replaceAll('{n}', '${diff.inDays}');
  }

  // Formato por defecto para fechas antiguas
  final localeCode = Localizations.localeOf(context).languageCode;
  return DateFormat('dd MMM yyyy', localeCode).format(date);
}
