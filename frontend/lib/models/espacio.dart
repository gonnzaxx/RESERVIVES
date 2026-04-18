/// RESERVIVES - Modelo de Espacio.


library;

import 'package:reservives/config/constants.dart';

enum TipoEspacio {
  pista('PISTA'),
  aula('AULA');

  final String value;
  const TipoEspacio(this.value);

  factory TipoEspacio.fromString(String value) {
    return TipoEspacio.values.firstWhere(
          (e) => e.value == value,
      orElse: () => TipoEspacio.pista,
    );
  }
}

class Espacio {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;
  final TipoEspacio tipo;
  final int precioTokens;
  final bool reservable;
  final bool requiereAutorizacion;
  final int antelacionDias;
  final String? ubicacion;
  final int? capacidad;
  final bool activo;
  final List<String> rolesPermitidos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  const Espacio({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
    required this.tipo,
    required this.precioTokens,
    required this.reservable,
    required this.requiereAutorizacion,
    required this.antelacionDias,
    this.ubicacion,
    this.capacidad,
    required this.activo,
    required this.rolesPermitidos,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  Espacio copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? imagenUrl,
    TipoEspacio? tipo,
    int? precioTokens,
    bool? reservable,
    bool? requiereAutorizacion,
    int? antelacionDias,
    String? ubicacion,
    int? capacidad,
    bool? activo,
    List<String>? rolesPermitidos,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return Espacio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      tipo: tipo ?? this.tipo,
      precioTokens: precioTokens ?? this.precioTokens,
      reservable: reservable ?? this.reservable,
      requiereAutorizacion: requiereAutorizacion ?? this.requiereAutorizacion,
      antelacionDias: antelacionDias ?? this.antelacionDias,
      ubicacion: ubicacion ?? this.ubicacion,
      capacidad: capacidad ?? this.capacidad,
      activo: activo ?? this.activo,
      rolesPermitidos: rolesPermitidos ?? this.rolesPermitidos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Espacio.fromJson(Map<String, dynamic> json) {
    return Espacio(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      imagenUrl: AppConstants.resolveApiUrl(json['imagen_url'] as String?),
      tipo: TipoEspacio.fromString(json['tipo'] as String),
      precioTokens: json['precio_tokens'] as int,
      reservable: json['reservable'] as bool,
      requiereAutorizacion: json['requiere_autorizacion'] as bool,
      antelacionDias: json['antelacion_dias'] as int,
      ubicacion: json['ubicacion'] as String?,
      capacidad: json['capacidad'] as int?,
      activo: json['activo'] as bool,
      rolesPermitidos: List<String>.from(json['roles_permitidos'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
      'tipo': tipo.value,
      'precio_tokens': precioTokens,
      'reservable': reservable,
      'requiere_autorizacion': requiereAutorizacion,
      'antelacion_dias': antelacionDias,
      'ubicacion': ubicacion,
      'capacidad': capacidad,
      'activo': activo,
      'roles_permitidos': rolesPermitidos,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite,
    };
  }
}
