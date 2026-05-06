/// Modelo de datos para el resumen estadístico del Backoffice.
///
library;

/// Esta clase agrupa las métricas clave que se visualizan en el Dashboard
/// principal del administrador para ofrecer una visión rápida del estado del sistema.
class AdminSummary {
  final int totalUsuarios; // Cantidad total de usuarios registrados en la plataforma.
  final int reservasActivas; // Número de reservas que están pendientes o en curso actualmente.
  final int espaciosDisponibles; // Conteo de espacios físicos que están marcados como operativos y libres.
  final int anunciosActivos;

  AdminSummary({
    required this.totalUsuarios,
    required this.reservasActivas,
    required this.espaciosDisponibles,
    required this.anunciosActivos,
  });

  /// Constructor factory para crear una instancia desde un mapa JSON.
  ///
  /// Incluye valores por defecto (0) para evitar errores de nulidad si el backend
  /// no devuelve algún campo específico.
  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    return AdminSummary(
      totalUsuarios: json['total_usuarios'] ?? 0,
      reservasActivas: json['reservas_activas'] ?? 0,
      espaciosDisponibles: json['espacios_disponibles'] ?? 0,
      anunciosActivos: json['anuncios_activos'] ?? 0,
    );
  }
}
