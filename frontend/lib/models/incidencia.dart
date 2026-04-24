enum EstadoIncidencia {
  pendiente,
  resuelta,
  descartada;

  static EstadoIncidencia fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDIENTE':
        return EstadoIncidencia.pendiente;
      case 'RESUELTA':
        return EstadoIncidencia.resuelta;
      case 'DESCARTADA':
        return EstadoIncidencia.descartada;
      default:
        return EstadoIncidencia.pendiente;
    }
  }

  String toJson() => name.toUpperCase();
}

class Incidencia {
  final String id;
  final String usuarioId;
  final String descripcion;
  final String? imagenUrl;
  final EstadoIncidencia estado;
  final String? comentarioAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nombreUsuario;

  Incidencia({
    required this.id,
    required this.usuarioId,
    required this.descripcion,
    this.imagenUrl,
    required this.estado,
    this.comentarioAdmin,
    required this.createdAt,
    required this.updatedAt,
    this.nombreUsuario,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    return Incidencia(
      id: json['id'],
      usuarioId: json['usuario_id'],
      descripcion: json['descripcion'],
      imagenUrl: json['imagen_url'],
      estado: EstadoIncidencia.fromString(json['estado']),
      comentarioAdmin: json['comentario_admin'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      nombreUsuario: json['nombre_usuario'] ?? (json['usuario'] != null ? json['usuario']['nombre'] : null),
    );
  }

  Incidencia copyWith({
    EstadoIncidencia? estado,
    String? comentarioAdmin,
  }) {
    return Incidencia(
      id: id,
      usuarioId: usuarioId,
      descripcion: descripcion,
      imagenUrl: imagenUrl,
      estado: estado ?? this.estado,
      comentarioAdmin: comentarioAdmin ?? this.comentarioAdmin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      nombreUsuario: nombreUsuario,
    );
  }
}
