/// Modelo de Usuario.
///
/// Define la entidad central de identidad del sistema. Gestiona la información
/// de perfil, el sistema de moneda virtual (tokens) y la jerarquía de permisos
/// mediante roles para el control de acceso.
library;

import 'package:reservives/config/constants.dart';

/// Define los roles y privilegios disponibles.
enum RolUsuario {
  alumno('ALUMNO'),
  profesor('PROFESOR'),
  administrador('ADMINISTRADOR'),
  cafeteria('CAFETERIA'),
  jefatura('JEFATURA'),
  secretaria('SECRETARIA'),
  gestorServicio('GESTOR_SERVICIO'),
  control('CONTROL');

  final String value;
  const RolUsuario(this.value);

  // Mapa de compatibilidad para roles renombrados en migraciones anteriores.
  static const _legacyMap = <String, String>{
    'ADMIN': 'ADMINISTRADOR',
    'JEFE_ESTUDIOS': 'JEFATURA',
    'PROFESOR_SERVICIO': 'GESTOR_SERVICIO',
  };

  /// Convierte el string del backend al enum, normalizando mayúsculas y nombres legacy.
  factory RolUsuario.fromString(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
    final mapped = _legacyMap[normalized] ?? normalized;
    return RolUsuario.values.firstWhere(
      (e) => e.value == mapped,
      orElse: () => RolUsuario.alumno,
    );
  }
}

/// Representa a un usuario autenticado en la plataforma.
class Usuario {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String? avatarUrl;
  final RolUsuario rol;
  /// String original del rol tal como lo devuelve la API. Puede ser un rol
  /// custom no presente en [RolUsuario] (ej. "INSPECTOR").
  final String rolRaw;
  final int tokens;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.email,
    this.avatarUrl,
    required this.rol,
    required this.rolRaw,
    required this.tokens,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea un [Usuario] desde un mapa JSON.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rawRol = json['rol'] as String;
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellidos: json['apellidos'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      rol: RolUsuario.fromString(rawRol),
      rolRaw: rawRol.trim().toUpperCase(),
      tokens: json['tokens'] as int,
      activo: json['activo'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Serializa el objeto a JSON para su almacenamiento local o envío a la API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellidos': apellidos,
      'email': email,
      'avatar_url': avatarUrl,
      'rol': rolRaw,
      'tokens': tokens,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helpers de identidad y rol para simplificar condicionales en la UI.
  String get nombreCompleto => '$nombre $apellidos';
  bool get isAlumno => rol == RolUsuario.alumno;
  bool get isProfesor => rol == RolUsuario.profesor;
  bool get isAdministrador => rol == RolUsuario.administrador;
  bool get isCafeteria => rol == RolUsuario.cafeteria;
  bool get isJefatura => rol == RolUsuario.jefatura;
  bool get isSecretaria => rol == RolUsuario.secretaria;
  bool get isGestorServicio => rol == RolUsuario.gestorServicio;
  bool get isControl => rol == RolUsuario.control;

  // True si el rol puede realizar reservas de espacios y servicios.
  bool get hasStudentBookingPermissions =>
      rol == RolUsuario.alumno ||
      rol == RolUsuario.profesor ||
      rol == RolUsuario.secretaria ||
      rol == RolUsuario.gestorServicio ||
      rol == RolUsuario.control ||
      rol == RolUsuario.cafeteria;

  /// Todos los roles usan tokens excepto ADMINISTRADOR y JEFATURA (acceso ilimitado).
  /// Incluye roles custom creados en producción.
  bool get usesTokens {
    final raw = rolRaw.toUpperCase();
    return raw != 'ADMINISTRADOR' && raw != 'JEFATURA';
  }

  // Devuelve la URL completa del avatar o null si no tiene foto de perfil.
  String? get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    return AppConstants.resolveApiUrl(avatarUrl);
  }

  Usuario copyWith({
    String? id,
    String? nombre,
    String? apellidos,
    String? email,
    String? avatarUrl,
    RolUsuario? rol,
    String? rolRaw,
    int? tokens,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rol: rol ?? this.rol,
      rolRaw: rolRaw ?? this.rolRaw,
      tokens: tokens ?? this.tokens,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
