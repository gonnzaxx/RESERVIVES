/// RESERVIVES - Modelos de Encuestas.
///
/// Define la estructura para el sistema de votaciones y participación del alumnado
/// del centro. Gestiona el ciclo de vida de la encuesta, el recuento de votos
/// y el estado de participación del usuario.
library;

/// Representa una opción seleccionable dentro de una encuesta.
class EncuestaOpcion {
  final String id;
  final String texto;
  final int votos;

  EncuestaOpcion({
    required this.id,
    required this.texto,
    required this.votos,
  });

  /// Crea una opción desde JSON.
  ///
  /// Soporta diferentes nombres de campo ([votos_count] o [votos]) para mantener
  factory EncuestaOpcion.fromJson(Map<String, dynamic> json) {
    return EncuestaOpcion(
      id: json['id'],
      texto: json['texto'],
      votos: json['votos_count'] ?? json['votos'] ?? 0,
    );
  }
}

/// Representa una encuesta completa con su configuración y resultados.
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

  /// Crea una instancia de [Encuesta] desde un mapa JSON.
  factory Encuesta.fromJson(Map<String, dynamic> json) {
    return Encuesta(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()).toLocal(),
      fechaFin: DateTime.parse(json['fecha_fin']).toLocal(),
      activa: json['activa'] ?? true,
      usuarioHaVotado: (json['voto_usuario_opcion_id'] != null) || (json['usuario_ha_votado'] ?? false),
      totalVotos: json['total_votos'] ?? 0,
      opciones: (json['opciones'] as List? ?? [])
          .map((e) => EncuestaOpcion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
