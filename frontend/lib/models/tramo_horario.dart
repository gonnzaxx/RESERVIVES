/// Modelo de Tramo Horario.
///
/// Define la estructura de los bloques temporales en los que se divide la jornada
/// lectiva del centro. Gestiona la lógica de turnos (mañana/tarde), recreos
/// y el estado de ocupación para el sistema de reservas.
library;

/// Representa un bloque de tiempo fijo en el calendario escolar.
class TramoHorario {
  final String id;
  final String nombre;
  final String turno;
  final int numero;
  final String horaInicio;
  final String horaFin;
  final bool esRecreo;
  final bool activo;

  const TramoHorario({
    required this.id,
    required this.nombre,
    required this.turno,
    required this.numero,
    required this.horaInicio,
    required this.horaFin,
    required this.esRecreo,
    required this.activo,
  });

  /// Crea un [TramoHorario] desde un mapa JSON, recortando la hora a formato HH:mm.
  factory TramoHorario.fromJson(Map<String, dynamic> json) {
    // Trunca el string de hora a los primeros 5 caracteres para quedarnos solo con HH:mm.
    String parseHora(dynamic raw) {
      final s = (raw as String).substring(0, 5);
      return s;
    }

    return TramoHorario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      turno: json['turno'] as String,
      numero: json['numero'] as int,
      horaInicio: parseHora(json['hora_inicio']),
      horaFin: parseHora(json['hora_fin']),
      esRecreo: json['es_recreo'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
    );
  }

  // Rango horario legible: p. ej. "08:00 – 08:55"
  String get rangoHorario => '$horaInicio – $horaFin';

  // Etiqueta completa para mostrar en listas: distingue recreos de clases normales.
  String get labelCompleto => esRecreo ? 'Recreo ($rangoHorario)' : '$nombre ($rangoHorario)';
}

/// Define los estados lógicos de un tramo tras cruzar datos de disponibilidad.
enum EstadoTramo {
  disponible,
  reservado,
  noPermitido,
  horarioPasado,
}

/// Representa el estado de ocupación de un [TramoHorario] para un recurso y fecha concretos.
class TramoDisponibilidad {
  final TramoHorario tramo;
  final bool disponible;
  final bool permitido;
  final bool reservado;
  final bool reservadoPorMi;
  final String? mensaje;

  const TramoDisponibilidad({
    required this.tramo,
    required this.disponible,
    required this.permitido,
    required this.reservado,
    this.reservadoPorMi = false,
    this.mensaje,
  });

  /// Clasifica la disponibilidad en un [EstadoTramo] para facilitar la lógica de estilos en UI.
  EstadoTramo get estado {
    if (mensaje == "Horario pasado") return EstadoTramo.horarioPasado;
    if (!permitido) return EstadoTramo.noPermitido;
    if (reservado) return EstadoTramo.reservado;
    return EstadoTramo.disponible;
  }

  /// Construye el objeto de disponibilidad cruzando la información del tramo y su estado actual.
  factory TramoDisponibilidad.fromJson(Map<String, dynamic> json) {
    return TramoDisponibilidad(
      tramo: TramoHorario.fromJson(json['tramo'] as Map<String, dynamic>),
      disponible: json['disponible'] as bool,
      permitido: json['permitido'] as bool,
      reservado: json['reservado'] as bool,
      reservadoPorMi: json['reservado_por_mi'] as bool? ?? false,
      mensaje: json['mensaje'] as String?,
    );
  }
}
