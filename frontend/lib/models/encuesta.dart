class EncuestaOpcion {
  final String id;
  final String texto;
  final int votos;

  EncuestaOpcion({
    required this.id,
    required this.texto,
    required this.votos,
  });

  factory EncuestaOpcion.fromJson(Map<String, dynamic> json) {
    return EncuestaOpcion(
      id: json['id'],
      texto: json['texto'],
      votos: json['votos_count'] ?? json['votos'] ?? 0,
    );
  }
}

class Encuesta {
  final String id;
  final String titulo;
  final String? descripcion;
  final DateTime createdAt;
  final DateTime fechaFin;
  final bool activa;
  final bool usuarioHaVotado;
  final int totalVotos;
  final List<EncuestaOpcion> opciones;

  Encuesta({
    required this.id,
    required this.titulo,
    this.descripcion,
    required this.createdAt,
    required this.fechaFin,
    required this.activa,
    required this.usuarioHaVotado,
    required this.totalVotos,
    required this.opciones,
  });

  factory Encuesta.fromJson(Map<String, dynamic> json) {
    return Encuesta(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      // El backend lo llama created_at
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()).toLocal(),
      fechaFin: DateTime.parse(json['fecha_fin']).toLocal(),
      activa: json['activa'] ?? true,
      // Estos campos pueden faltar en el listado básico
      usuarioHaVotado: (json['voto_usuario_opcion_id'] != null) || (json['usuario_ha_votado'] ?? false),
      totalVotos: json['total_votos'] ?? 0,
      opciones: (json['opciones'] as List? ?? [])
          .map((e) => EncuestaOpcion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
