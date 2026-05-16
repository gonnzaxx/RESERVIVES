/// Provider de Calendario de Disponibilidad.
///
/// Obtiene la disponibilidad de tramos día a día para un rango de fechas,
/// permitiendo renderizar una vista de calendario semanal.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/services/api_client.dart';

/// Representa la disponibilidad completa de un día en el calendario.
class CalendarioDia {
  final DateTime fecha;
  final String diaSemana;
  final List<TramoDisponibilidad> tramos;

  const CalendarioDia({
    required this.fecha,
    required this.diaSemana,
    required this.tramos,
  });

  /// Construye el objeto a partir del JSON del backend.
  factory CalendarioDia.fromJson(Map<String, dynamic> json) {
    return CalendarioDia(
      fecha: DateTime.parse(json['fecha'] as String),
      diaSemana: json['dia_semana'] as String,
      tramos: (json['tramos'] as List)
          .map((t) => TramoDisponibilidad.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  // True si la fecha cae en sábado o domingo.
  bool get esFinDeSemana =>
      fecha.weekday == DateTime.saturday || fecha.weekday == DateTime.sunday;

  // Número de tramos que aún tienen hueco disponible.
  int get tramosDisponibles => tramos.where((t) => t.disponible).length;
  // Número de tramos ya reservados.
  int get tramosOcupados => tramos.where((t) => t.reservado).length;
}

/// Argumentos para parametrizar la consulta del calendario de un espacio.
typedef CalendarioArgs = ({
  String espacioId,
  DateTime fechaInicio,
  DateTime fechaFin
});

/// Obtiene el calendario de disponibilidad de un espacio para el rango de fechas indicado.
final calendarioDisponibilidadProvider =
    FutureProvider.autoDispose.family<List<CalendarioDia>, CalendarioArgs>(
  (ref, args) async {
    final api = ref.read(apiClientProvider);
    final inicio = _fmt(args.fechaInicio);
    final fin = _fmt(args.fechaFin);
    final response = await api.get(
      '/espacios/${args.espacioId}/calendario?fecha_inicio=$inicio&fecha_fin=$fin',
    );
    return (response as List)
        .map((d) => CalendarioDia.fromJson(d as Map<String, dynamic>))
        .toList();
  },
);

// Formatea un DateTime al estándar YYYY-MM-DD.
String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
