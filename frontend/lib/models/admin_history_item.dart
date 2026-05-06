/// Modelo de datos y filtros para el historial de administración.
///
/// Representa un ítem individual en el historial de administración.
class AdminHistoryItem {
  final String id;
  final String tipoReserva;
  final String? nombreUsuario;
  final String? emailUsuario;
  final String? nombreRecurso;
  final String estado;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? observaciones;

  const AdminHistoryItem({
    required this.id,
    required this.tipoReserva,
    required this.estado,
    required this.fechaInicio,
    required this.fechaFin,
    this.nombreUsuario,
    this.emailUsuario,
    this.nombreRecurso,
    this.observaciones,
  });

  /// Crea una instancia a partir de un JSON proveniente de la API.
  factory AdminHistoryItem.fromJson(Map<String, dynamic> json) {
    return AdminHistoryItem(
      id: json['id'] as String,
      tipoReserva: json['tipo_reserva'] as String,
      nombreUsuario: json['nombre_usuario'] as String?,
      emailUsuario: json['email_usuario'] as String?,
      nombreRecurso: json['nombre_recurso'] as String?,
      estado: json['estado'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(json['fecha_fin'] as String).toLocal(),
      observaciones: json['observaciones'] as String?,
    );
  }
}

/// Estructura para gestionar los criterios de filtrado en la vista de historial.
class AdminHistoryFilters {
  final DateTime? day;    // Filtrar por un día específico
  final int? month;       // Filtrar por mes (1-12)
  final int? year;        // Filtrar por año
  final String? tipo;     // Filtrar por tipo de recurso
  final String? estado;   // Filtrar por estado de la reserva
  final String? usuarioQ; // Búsqueda por texto (nombre o email)

  const AdminHistoryFilters({
    this.day,
    this.month,
    this.year,
    this.tipo,
    this.estado,
    this.usuarioQ,
  });
}