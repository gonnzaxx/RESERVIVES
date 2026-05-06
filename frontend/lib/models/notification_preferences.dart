/// Modelo de Preferencias de Notificación.
///
/// Gestiona la configuración de privacidad y comunicación del usuario.
/// Permite habilitar o deshabilitar de forma granular las notificaciones push
/// y los correos electrónicos informativos.

library;

class NotificationPreferences {
  final bool reservaAprobada;
  final bool reservaRechazada;
  final bool nuevoEspacio;
  final bool nuevoServicio;
  final bool nuevoAnuncio;
  final bool nuevaEncuesta;
  final bool listaEspera;
  final bool emailReservas;
  final bool emailAnuncios;
  final bool emailIncidencias;
  final bool emailTokens;

  const NotificationPreferences({
    required this.reservaAprobada,
    required this.reservaRechazada,
    required this.nuevoEspacio,
    required this.nuevoServicio,
    required this.nuevoAnuncio,
    required this.nuevaEncuesta,
    required this.listaEspera,
    required this.emailReservas,
    required this.emailAnuncios,
    required this.emailIncidencias,
    required this.emailTokens,
  });

  /// Instancia con todos los valores habilitados por defecto (usada en modo invitado).
  factory NotificationPreferences.defaults() {
    return const NotificationPreferences(
      reservaAprobada: true,
      reservaRechazada: true,
      nuevoEspacio: true,
      nuevoServicio: true,
      nuevoAnuncio: true,
      nuevaEncuesta: true,
      listaEspera: true,
      emailReservas: true,
      emailAnuncios: true,
      emailIncidencias: true,
      emailTokens: true,
    );
  }

  /// Crea una instancia de preferencias desde JSON.
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      reservaAprobada: json['reserva_aprobada'] as bool? ?? true,
      reservaRechazada: json['reserva_rechazada'] as bool? ?? true,
      nuevoEspacio: json['nuevo_espacio'] as bool? ?? true,
      nuevoServicio: json['nuevo_servicio'] as bool? ?? true,
      nuevoAnuncio: json['nuevo_anuncio'] as bool? ?? true,
      nuevaEncuesta: json['nueva_encuesta'] as bool? ?? true,
      listaEspera: json['lista_espera'] as bool? ?? true,
      emailReservas: json['email_reservas'] as bool? ?? true,
      emailAnuncios: json['email_anuncios'] as bool? ?? true,
      emailIncidencias: json['email_incidencias'] as bool? ?? true,
      emailTokens: json['email_tokens'] as bool? ?? true,
    );
  }

  /// Crea una copia de las preferencias modificando solo los campos indicados.
  NotificationPreferences copyWith({
    bool? reservaAprobada,
    bool? reservaRechazada,
    bool? nuevoEspacio,
    bool? nuevoServicio,
    bool? nuevoAnuncio,
    bool? nuevaEncuesta,
    bool? listaEspera,
    bool? emailReservas,
    bool? emailAnuncios,
    bool? emailIncidencias,
    bool? emailTokens,
  }) {
    return NotificationPreferences(
      reservaAprobada: reservaAprobada ?? this.reservaAprobada,
      reservaRechazada: reservaRechazada ?? this.reservaRechazada,
      nuevoEspacio: nuevoEspacio ?? this.nuevoEspacio,
      nuevoServicio: nuevoServicio ?? this.nuevoServicio,
      nuevoAnuncio: nuevoAnuncio ?? this.nuevoAnuncio,
      nuevaEncuesta: nuevaEncuesta ?? this.nuevaEncuesta,
      listaEspera: listaEspera ?? this.listaEspera,
      emailReservas: emailReservas ?? this.emailReservas,
      emailAnuncios: emailAnuncios ?? this.emailAnuncios,
      emailIncidencias: emailIncidencias ?? this.emailIncidencias,
      emailTokens: emailTokens ?? this.emailTokens,
    );
  }

  /// Convierte las preferencias a un mapa para persistencia en el backend.
  Map<String, dynamic> toJson() {
    return {
      'reserva_aprobada': reservaAprobada,
      'reserva_rechazada': reservaRechazada,
      'nuevo_espacio': nuevoEspacio,
      'nuevo_servicio': nuevoServicio,
      'nuevo_anuncio': nuevoAnuncio,
      'nueva_encuesta': nuevaEncuesta,
      'lista_espera': listaEspera,
      'email_reservas': emailReservas,
      'email_anuncios': emailAnuncios,
      'email_incidencias': emailIncidencias,
      'email_tokens': emailTokens,
    };
  }
}
