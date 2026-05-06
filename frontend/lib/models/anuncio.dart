/// Modelo de datos de los anuncios de la plataforma
///
/// Representa una publicación informativa o aviso dentro del sistema.
/// Incluye soporte para contenido multimedia, estados de visibilidad
/// y gestión de fechas de expiración.
library;

import 'package:reservives/config/constants.dart';

class Anuncio {
  final String id;
  final String autorId;
  final String titulo;
  final String contenido;
  final String? imagenUrl;
  final bool destacado;
  final bool activo;
  final DateTime fechaPublicacion;
  final DateTime? fechaExpiracion;
  final String? nombreAutor;

  const Anuncio({
    required this.id,
    required this.autorId,
    required this.titulo,
    required this.contenido,
    this.imagenUrl,
    required this.destacado,
    required this.activo,
    required this.fechaPublicacion,
    this.fechaExpiracion,
    this.nombreAutor,
  });

  /// Crea una instancia de [Anuncio] desde un mapa JSON
  factory Anuncio.fromJson(Map<String, dynamic> json) {
    return Anuncio(
      id: json['id'] as String,
      autorId: json['autor_id'] as String,
      titulo: json['titulo'] as String,
      contenido: json['contenido'] as String,
      imagenUrl: AppConstants.resolveApiUrl(json['imagen_url'] as String?),
      destacado: json['destacado'] as bool,
      activo: json['activo'] as bool,
      fechaPublicacion: DateTime.parse(json['fecha_publicacion'] as String).toLocal(),
      fechaExpiracion: json['fecha_expiracion'] != null
          ? DateTime.parse(json['fecha_expiracion'] as String).toLocal()
          : null,
      nombreAutor: json['nombre_autor'] as String?,
    );
  }
}
