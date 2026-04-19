library;

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
  incidenciaResueltas('INCIDENCIA_RESUELTA');

  final String value;
  const TipoNotificacion(this.value);

  factory TipoNotificacion.fromString(String value) {
    return TipoNotificacion.values.firstWhere(
          (e) => e.value == value,
      orElse: () => TipoNotificacion.nuevoAnuncio,
    );
  }
}

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
