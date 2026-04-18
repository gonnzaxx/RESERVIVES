/// RESERVIVES - Modelo de Reserva de Espacio.


library;

import 'package:reservives/models/tramo_horario.dart';

enum EstadoReserva {
  pendiente('PENDIENTE'),
  aprobada('APROBADA'),
  rechazada('RECHAZADA'),
  cancelada('CANCELADA');

  final String value;
  const EstadoReserva(this.value);

  factory EstadoReserva.fromString(String value) {
    return EstadoReserva.values.firstWhere(
          (e) => e.value == value,
      orElse: () => EstadoReserva.pendiente,
    );
  }
}

class Reserva {
  final String id;
  final String usuarioId;
  final String espacioId;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? observaciones;
  final EstadoReserva estado;
  final int tokensConsumidos;
  final String? tramoId;
  final TramoHorario? tramo;
  final String? nombreUsuario;
  final String? nombreEspacio;
  final String? tipoEspacio;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reserva({
    required this.id,
    required this.usuarioId,
    required this.espacioId,
    required this.fechaInicio,
    required this.fechaFin,
    this.observaciones,
    required this.estado,
    required this.tokensConsumidos,
    this.tramoId,
    this.tramo,
    this.nombreUsuario,
    this.nombreEspacio,
    this.tipoEspacio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    final espacioId = (json['espacio_id'] ?? json['servicio_id']).toString();
    final nombreEspacio = (json['nombre_espacio'] ?? json['nombre_servicio']) as String?;
    final tipoEspacio = json['tipo_espacio'] as String? ?? 'SERVICIO';

    return Reserva(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      espacioId: espacioId,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(json['fecha_fin'] as String).toLocal(),
      observaciones: json['observaciones'] as String?,
      estado: EstadoReserva.fromString(json['estado'] as String),
      tokensConsumidos: json['tokens_consumidos'] as int,
      tramoId: json['tramo_id'] as String?,
      tramo: json['tramo'] != null
          ? TramoHorario.fromJson(json['tramo'] as Map<String, dynamic>)
          : null,
      nombreUsuario: json['nombre_usuario'] as String?,
      nombreEspacio: nombreEspacio,
      tipoEspacio: tipoEspacio,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'espacio_id': espacioId,
      'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
      'fecha_fin': fechaFin.toUtc().toIso8601String(),
      'observaciones': observaciones,
      'estado': estado.value,
      'tokens_consumidos': tokensConsumidos,
      if (tramoId != null) 'tramo_id': tramoId,
    };
  }

  bool get isPendiente => estado == EstadoReserva.pendiente;
  bool get isAprobada => estado == EstadoReserva.aprobada;
  bool get isRechazada => estado == EstadoReserva.rechazada;
  bool get isCancelada => estado == EstadoReserva.cancelada;
  bool get isPasada => fechaFin.isBefore(DateTime.now());
  bool get isActiva => (isPendiente || isAprobada) && !isPasada;
}



