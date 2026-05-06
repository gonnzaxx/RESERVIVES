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
  final bool isFavorite;

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
    this.isFavorite = false,
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
    bool? isFavorite,
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
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Construye una instancia de [ServicioInstituto] desde un mapa JSON.
  factory ServicioInstituto.fromJson(Map<String, dynamic> json) {
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
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  /// Convierte la instancia a un formato JSON para persistencia o envío a la API.
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
      'is_favorite': isFavorite,
    };
  }
}
