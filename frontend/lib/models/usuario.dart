/// RESERVIVES - Modelo de Usuario.

library;

import 'package:reservives/config/constants.dart';

enum RolUsuario {
  alumno('ALUMNO'),
  profesor('PROFESOR'),
  admin('ADMIN'),
  cafeteria('CAFETERIA'),
  jefeEstudios('JEFE_ESTUDIOS'),
  secretaria('SECRETARIA'),
  profesorServicio('PROFESOR_SERVICIO');

  final String value;
  const RolUsuario(this.value);

  factory RolUsuario.fromString(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
    return RolUsuario.values.firstWhere(
          (e) => e.value == normalized,
      orElse: () => RolUsuario.alumno,
    );
  }
}

class Usuario {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String? avatarUrl;
  final RolUsuario rol;
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
    required this.tokens,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellidos: json['apellidos'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      rol: RolUsuario.fromString(json['rol'] as String),
      tokens: json['tokens'] as int,
      activo: json['activo'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellidos': apellidos,
      'email': email,
      'avatar_url': avatarUrl,
      'rol': rol.value,
      'tokens': tokens,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get nombreCompleto => '$nombre $apellidos';
  bool get isAlumno => rol == RolUsuario.alumno;
  bool get isProfesor => rol == RolUsuario.profesor;
  bool get isAdmin => rol == RolUsuario.admin;
  bool get isCafeteria => rol == RolUsuario.cafeteria;
  bool get isJefeEstudios => rol == RolUsuario.jefeEstudios;
  bool get isSecretaria => rol == RolUsuario.secretaria;
  bool get isProfesorServicio => rol == RolUsuario.profesorServicio;

  bool get hasStudentBookingPermissions =>
      rol == RolUsuario.alumno ||
      rol == RolUsuario.profesor ||
      rol == RolUsuario.secretaria ||
      rol == RolUsuario.profesorServicio;

  bool get usesTokens => hasStudentBookingPermissions;

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
      tokens: tokens ?? this.tokens,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
