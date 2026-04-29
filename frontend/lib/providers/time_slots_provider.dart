/// RESERVIVES - Providers de Tramos Horarios.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/services/api_client.dart';

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Todos los tramos
final tramosProvider = FutureProvider<List<TramoHorario>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/tramos/');
  return (response as List)
      .map((e) => TramoHorario.fromJson(e as Map<String, dynamic>))
      .toList();
});


typedef DisponibilidadEspacioArgs = ({String espacioId, DateTime fecha});

/// Provider de disponibilidad de tramos para un espacio y fecha.
final disponibilidadEspacioProvider = FutureProvider.autoDispose
    .family<List<TramoDisponibilidad>, DisponibilidadEspacioArgs>(
      (ref, args) async {
    final api = ref.read(apiClientProvider);
    final dateStr = _formatDate(args.fecha);
    final response = await api.get(
      '/tramos/disponibilidad/espacio/${args.espacioId}?fecha=$dateStr',
    );
    return (response as List)
        .map((e) => TramoDisponibilidad.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

typedef DisponibilidadServicioArgs = ({String servicioId, DateTime fecha});

/// Provider de disponibilidad de tramos para un servicio y fecha.
final disponibilidadServicioProvider = FutureProvider.autoDispose
    .family<List<TramoDisponibilidad>, DisponibilidadServicioArgs>(
      (ref, args) async {
    final api = ref.read(apiClientProvider);
    final dateStr = _formatDate(args.fecha);
    final response = await api.get(
      '/tramos/disponibilidad/servicio/${args.servicioId}?fecha=$dateStr',
    );
    return (response as List)
        .map((e) => TramoDisponibilidad.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

final tramosPermitidosEspacioProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, espacioId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/tramos/espacio/$espacioId/tramos-permitidos');
    return (response as List).map((e) => e.toString()).toList();
  },
);

/// Provider de IDs de tramos permitidos para un servicio
final tramosPermitidosServicioProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, servicioId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/tramos/servicio/$servicioId/tramos-permitidos');
    return (response as List).map((e) => e.toString()).toList();
  },
);
