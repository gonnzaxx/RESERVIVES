/// Modelos de Notificación.
///
/// Gestiona el sistema de alertas y comunicaciones internas de la aplicación.
/// Permite clasificar las notificaciones por tipo para facilitar la navegación

library;

/// Clasificación de los eventos que pueden disparar una notificación.
enum TipoNotificacion {
  reservaAprobada('RESERVA_APROBADA'),
  reservaRechazada('RESERVA_RECHAZADA'),
  nuevoEspacio('NUEVO_ESPACIO'),
  nuevoServicio('NUEVO_SERVICIO'),
  nuevoAnuncio('NUEVO_ANUNCIO'),
  nuevaReservaPendiente('NUEVA_RESERVA_PENDIENTE'),
  reservaCancelada('RESERVA_CANCELADA'),
  recargaTokens('RECARGA_TOKENS'),
  nuevaEncuesta('NUEVA_ENCUESTA'),
  nuevaIncidencia('NUEVA_INCIDENCIA'),
  incidenciaResuelta('INCIDENCIA_RESUELTA'),
  reservaRecurrenteAprobada('RESERVA_RECURRENTE_APROBADA'),
  reservaRecurrenteRechazada('RESERVA_RECURRENTE_RECHAZADA'),
  nuevaReservaRecurrentePendiente('NUEVA_RESERVA_RECURRENTE_PENDIENTE'),
  listaEsperaDisponible('LISTA_ESPERA_DISPONIBLE');

  final String value;
  const TipoNotificacion(this.value);

  /// Convierte una cadena de texto del backend al tipo de notificación correspondiente.
  /// En caso de no reconocer el tipo, se asigna [nuevoAnuncio] por defecto.
  factory TipoNotificacion.fromString(String value) {
    return TipoNotificacion.values.firstWhere(
          (e) => e.value == value,
      orElse: () => TipoNotificacion.nuevoAnuncio,
    );
  }
}

/// Representa una notificación individual recibida por el usuario.
class Notificacion {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String mensaje;
  final bool leida;
  final String? referenciaId;
  final DateTime createdAt;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    this.referenciaId,
    required this.createdAt,
  });

  /// Crea una instancia de [Notificacion] desde un mapa JSON.
  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] as String,
      tipo: TipoNotificacion.fromString(json['tipo'] as String),
      titulo: json['titulo'] as String,
      mensaje: json['mensaje'] as String,
      leida: json['leida'] as bool,
      referenciaId: json['referencia_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
