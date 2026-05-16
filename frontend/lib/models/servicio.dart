/// Modelo de Servicio.
///
/// Define la estructura de los servicios ofrecidos por el centro.
/// Gestiona la información descriptiva,
/// costes, visibilidad y reglas de antelación para las citas.
library;

import 'package:reservives/config/constants.dart';

class ServicioInstituto {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;
  final String? ubicacion;
  final String? horario;
  final int precioTokens;
  final bool activo;
  final int orden;
  final int antelacionDias;
  final String? gestorUsuarioId;
  final String? gestorNombre;
  final bool isFavorite;
  final List<String> rolesPermitidos;

  const ServicioInstituto({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
    this.ubicacion,
    this.horario,
    required this.precioTokens,
    required this.activo,
    required this.orden,
    this.antelacionDias = 7,
    this.gestorUsuarioId,
    this.gestorNombre,
    this.isFavorite = false,
    this.rolesPermitidos = const [],
  });

  ServicioInstituto copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? imagenUrl,
    String? ubicacion,
    String? horario,
    int? precioTokens,
    bool? activo,
    int? orden,
    int? antelacionDias,
    String? gestorUsuarioId,
    String? gestorNombre,
    bool? isFavorite,
    List<String>? rolesPermitidos,
  }) {
    return ServicioInstituto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      ubicacion: ubicacion ?? this.ubicacion,
      horario: horario ?? this.horario,
      precioTokens: precioTokens ?? this.precioTokens,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
      antelacionDias: antelacionDias ?? this.antelacionDias,
      gestorUsuarioId: gestorUsuarioId ?? this.gestorUsuarioId,
      gestorNombre: gestorNombre ?? this.gestorNombre,
      isFavorite: isFavorite ?? this.isFavorite,
      rolesPermitidos: rolesPermitidos ?? this.rolesPermitidos,
    );
  }

  /// Crea un [ServicioInstituto] desde el JSON de la API, resolviendo la URL de imagen y el nombre del gestor.
  factory ServicioInstituto.fromJson(Map<String, dynamic> json) {
    final gestor = json['gestor'] as Map<String, dynamic>?;
    return ServicioInstituto(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      imagenUrl: AppConstants.resolveApiUrl(json['imagen_url'] as String?),
      ubicacion: json['ubicacion'] as String?,
      horario: json['horario'] as String?,
      precioTokens: json['precio_tokens'] as int,
      activo: json['activo'] as bool,
      orden: json['orden'] as int,
      antelacionDias: json['antelacion_dias'] as int? ?? 7,
      gestorUsuarioId: json['gestor_usuario_id'] as String?,
      gestorNombre: gestor != null ? '${gestor['nombre']} ${gestor['apellidos']}' : null,
      isFavorite: json['is_favorite'] as bool? ?? false,
      rolesPermitidos: List<String>.from(json['roles_permitidos'] ?? []),
    );
  }

  /// Serializa el objeto a JSON para enviarlo a la API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
      'ubicacion': ubicacion,
      'horario': horario,
      'precio_tokens': precioTokens,
      'activo': activo,
      'orden': orden,
      'antelacion_dias': antelacionDias,
      'gestor_usuario_id': gestorUsuarioId,
      'is_favorite': isFavorite,
    };
  }
}
