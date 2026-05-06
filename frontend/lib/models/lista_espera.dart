/// Modelo de Lista de Espera.
///
/// Representa la posición de un usuario en la cola de espera
/// para un tramo concreto de un espacio en una fecha determinada.
library;

enum EstadoListaEspera {
  activa('ACTIVA'),
  notificada('NOTIFICADA'),
  reservada('RESERVADA'),
  expirada('EXPIRADA'),
  cancelada('CANCELADA');

  final String value;
  const EstadoListaEspera(this.value);

  factory EstadoListaEspera.fromString(String v) =>
      EstadoListaEspera.values.firstWhere((e) => e.value == v,
          orElse: () => EstadoListaEspera.activa);
}

class ListaEspera {
  final String id;
  final String usuarioId;
  final String espacioId;
  final String tramoId;
  final DateTime fecha;
  final int posicion;
  final EstadoListaEspera estado;
  final String? nombreUsuario;
  final String? nombreEspacio;
  final String? nombreTramo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListaEspera({
    required this.id,
    required this.usuarioId,
    required this.espacioId,
    required this.tramoId,
    required this.fecha,
    required this.posicion,
    required this.estado,
    this.nombreUsuario,
    this.nombreEspacio,
    this.nombreTramo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ListaEspera.fromJson(Map<String, dynamic> json) {
    return ListaEspera(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      espacioId: json['espacio_id'] as String,
      tramoId: json['tramo_id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      posicion: json['posicion'] as int,
      estado: EstadoListaEspera.fromString(json['estado'] as String),
      nombreUsuario: json['nombre_usuario'] as String?,
      nombreEspacio: json['nombre_espacio'] as String?,
      nombreTramo: json['nombre_tramo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isActiva => estado == EstadoListaEspera.activa;
  bool get isNotificada => estado == EstadoListaEspera.notificada;
}
