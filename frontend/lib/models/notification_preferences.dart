library;

class NotificationPreferences {
  final bool reservaAprobada;
  final bool reservaRechazada;
  final bool nuevoEspacio;
  final bool nuevoServicio;
  final bool nuevoAnuncio;
  final bool emailReservas;
  final bool emailAnuncios;

  const NotificationPreferences({
    required this.reservaAprobada,
    required this.reservaRechazada,
    required this.nuevoEspacio,
    required this.nuevoServicio,
    required this.nuevoAnuncio,
    required this.emailReservas,
    required this.emailAnuncios,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      reservaAprobada: json['reserva_aprobada'] as bool? ?? true,
      reservaRechazada: json['reserva_rechazada'] as bool? ?? true,
      nuevoEspacio: json['nuevo_espacio'] as bool? ?? true,
      nuevoServicio: json['nuevo_servicio'] as bool? ?? true,
      nuevoAnuncio: json['nuevo_anuncio'] as bool? ?? true,
      emailReservas: json['email_reservas'] as bool? ?? true,
      emailAnuncios: json['email_anuncios'] as bool? ?? true,
    );
  }

  NotificationPreferences copyWith({
    bool? reservaAprobada,
    bool? reservaRechazada,
    bool? nuevoEspacio,
    bool? nuevoServicio,
    bool? nuevoAnuncio,
    bool? emailReservas,
    bool? emailAnuncios,
  }) {
    return NotificationPreferences(
      reservaAprobada: reservaAprobada ?? this.reservaAprobada,
      reservaRechazada: reservaRechazada ?? this.reservaRechazada,
      nuevoEspacio: nuevoEspacio ?? this.nuevoEspacio,
      nuevoServicio: nuevoServicio ?? this.nuevoServicio,
      nuevoAnuncio: nuevoAnuncio ?? this.nuevoAnuncio,
      emailReservas: emailReservas ?? this.emailReservas,
      emailAnuncios: emailAnuncios ?? this.emailAnuncios,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reserva_aprobada': reservaAprobada,
      'reserva_rechazada': reservaRechazada,
      'nuevo_espacio': nuevoEspacio,
      'nuevo_servicio': nuevoServicio,
      'nuevo_anuncio': nuevoAnuncio,
      'email_reservas': emailReservas,
      'email_anuncios': emailAnuncios,
    };
  }
}
