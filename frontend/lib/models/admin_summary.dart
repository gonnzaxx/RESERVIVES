class AdminSummary {
  final int totalUsuarios;
  final int reservasActivas;
  final int espaciosDisponibles;
  final int anunciosActivos;

  AdminSummary({
    required this.totalUsuarios,
    required this.reservasActivas,
    required this.espaciosDisponibles,
    required this.anunciosActivos,
  });

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    return AdminSummary(
      totalUsuarios: json['total_usuarios'] ?? 0,
      reservasActivas: json['reservas_activas'] ?? 0,
      espaciosDisponibles: json['espacios_disponibles'] ?? 0,
      anunciosActivos: json['anuncios_activos'] ?? 0,
    );
  }
}
