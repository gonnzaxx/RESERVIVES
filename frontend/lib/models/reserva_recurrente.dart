/// Modelo de Reserva Recurrente.
///
/// Representa un patrón de reserva periódica que requiere aprobación
/// del administrador antes de generar instancias concretas.
library;

enum TipoRecurrencia {
  semanal('SEMANAL'),
  quincenal('QUINCENAL'),
  mensual('MENSUAL');

  final String value;
  const TipoRecurrencia(this.value);

  factory TipoRecurrencia.fromString(String v) =>
      TipoRecurrencia.values.firstWhere((e) => e.value == v,
          orElse: () => TipoRecurrencia.semanal);

  String get label {
    switch (this) {
      case TipoRecurrencia.semanal:
        return 'Semanal';
      case TipoRecurrencia.quincenal:
        return 'Quincenal';
      case TipoRecurrencia.mensual:
        return 'Mensual';
    }
  }
}

enum EstadoReservaRecurrente {
  pendienteAprobacion('PENDIENTE_APROBACION'),
  aprobada('APROBADA'),
  rechazada('RECHAZADA'),
  cancelada('CANCELADA');

  final String value;
  const EstadoReservaRecurrente(this.value);

  factory EstadoReservaRecurrente.fromString(String v) =>
      EstadoReservaRecurrente.values.firstWhere((e) => e.value == v,
          orElse: () => EstadoReservaRecurrente.pendienteAprobacion);
}

class ReservaRecurrente {
  final String id;
  final String usuarioId;
  final String espacioId;
  final String tramoId;
  final TipoRecurrencia tipoRecurrencia;
  final DateTime fechaInicio;
  final DateTime fechaFinRecurrencia;
  final EstadoReservaRecurrente estado;
  final String? observaciones;
  final String? motivoRechazo;
  final int tokensPorInstancia;
  final DateTime? ultimaInstanciaGenerada;
  final String? nombreUsuario;
  final String? nombreEspacio;
  final String? nombreTramo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReservaRecurrente({
    required this.id,
    required this.usuarioId,
    required this.espacioId,
    required this.tramoId,
    required this.tipoRecurrencia,
    required this.fechaInicio,
    required this.fechaFinRecurrencia,
    required this.estado,
    this.observaciones,
    this.motivoRechazo,
    required this.tokensPorInstancia,
    this.ultimaInstanciaGenerada,
    this.nombreUsuario,
    this.nombreEspacio,
    this.nombreTramo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReservaRecurrente.fromJson(Map<String, dynamic> json) {
    return ReservaRecurrente(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      espacioId: json['espacio_id'] as String,
      tramoId: json['tramo_id'] as String,
      tipoRecurrencia: TipoRecurrencia.fromString(json['tipo_recurrencia'] as String),
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFinRecurrencia: DateTime.parse(json['fecha_fin_recurrencia'] as String),
      estado: EstadoReservaRecurrente.fromString(json['estado'] as String),
      observaciones: json['observaciones'] as String?,
      motivoRechazo: json['motivo_rechazo'] as String?,
      tokensPorInstancia: json['tokens_por_instancia'] as int,
      ultimaInstanciaGenerada: json['ultima_instancia_generada'] != null
          ? DateTime.parse(json['ultima_instancia_generada'] as String)
          : null,
      nombreUsuario: json['nombre_usuario'] as String?,
      nombreEspacio: json['nombre_espacio'] as String?,
      nombreTramo: json['nombre_tramo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPendiente => estado == EstadoReservaRecurrente.pendienteAprobacion;
  bool get isAprobada => estado == EstadoReservaRecurrente.aprobada;
  bool get isRechazada => estado == EstadoReservaRecurrente.rechazada;
  bool get isCancelada => estado == EstadoReservaRecurrente.cancelada;
  bool get isActiva => isAprobada || isPendiente;
}
