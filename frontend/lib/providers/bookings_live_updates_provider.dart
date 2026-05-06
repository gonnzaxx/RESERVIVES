/// Servicio de Sincronización de Reservas en Tiempo Real.
///
/// Este archivo gestiona la conectividad WebSocket específica para las reservas
/// de los usuarios. Proporciona un sistema  que notifica
/// a la UI cuándo debe invalidar la caché y recargar la lista de reservas
/// tras cambios realizados en el servidor o por otros procesos.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Proveedor global para la versión de reservas en vivo.
final bookingsLiveVersionProvider =
    NotifierProvider<BookingsLiveVersionNotifier, int>(
      BookingsLiveVersionNotifier.new,
    );

/// Notifier que actúa como un contador de versiones de datos de reservas.
/// Los widgets y otros providers pueden observar este entero para reaccionar
/// a actualizaciones externas.
class BookingsLiveVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Proveedor del servicio de WebSocket. Se elimina automáticamente cuando
/// ya no hay escuchas activos para ahorrar recursos de red.
final bookingsWebSocketProvider =
    Provider.autoDispose<BookingsWebSocketService>((ref) {
      final service = BookingsWebSocketService(ref);
      ref.onDispose(service.dispose);
      return service;
    });

/// Servicio encargado de mantener la conexión persistente con el servidor
/// para el flujo de eventos de reservas.
class BookingsWebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  final Set<String> _recentEventKeys = <String>{};

  BookingsWebSocketService(this._ref);

  /// Establece la conexión con el endpoint de reservas.
  /// Requiere un token de autenticación válido.
  void connect() {
    if (_isConnecting || _channel != null) return;

    final token = _ref.read(authProvider.notifier).token;
    if (token == null) return;

    _isConnecting = true;
    _reconnectTimer?.cancel();

    // Construcción de la URI adaptando el protocolo según el entorno (WS o WSS).
    final wsUri = Uri.parse(AppConstants.apiBaseUrl).replace(
      scheme: AppConstants.apiBaseUrl.startsWith('https') ? 'wss' : 'ws',
      path: '/api/ws/reservations',
      queryParameters: {'token': token},
    );

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _subscription = _channel?.stream.listen(
        _onMessage,
        onError: (Object error) {
          developer.log('Bookings WS error', error: error, name: 'bookings.websocket');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
    } catch (error) {
      developer.log('Bookings WS connect error', error: error, name: 'bookings.websocket');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  /// Procesa los mensajes entrantes del servidor.
  void _onMessage(dynamic message) {
    final event = _extractEvent(message);
    if (event == null) return;

    final eventKey = '${event.type}:${event.id}';
    if (_recentEventKeys.contains(eventKey)) return;
    _recentEventKeys.add(eventKey);
    if (_recentEventKeys.length > 200) {
      _recentEventKeys.remove(_recentEventKeys.first);
    }

    // Notificamos al sistema que la información de reservas ha cambiado.
    _ref.read(bookingsLiveVersionProvider.notifier).bump();
  }

  /// Parsea el JSON del socket y extrae los metadatos del evento.
  _ReservationSocketEvent? _extractEvent(dynamic message) {
    try {
      if (message is! String) return null;
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'] as String?;
      final data = decoded['data'] as Map<String, dynamic>?;
      final id = data?['reservation_id'] as String?;
      if (type == null || id == null || id.isEmpty) return null;
      return _ReservationSocketEvent(type: type, id: id);
    } catch (_) {
      return null;
    }
  }

  /// Agenda un intento de reconexión tras una pérdida de señal.
  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      final token = _ref.read(authProvider.notifier).token;
      if (token != null) connect();
    });
  }

  /// Cierra todos los recursos y limpia el estado del servicio.
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnecting = false;
    _recentEventKeys.clear();
  }
}

/// Estructura interna para representar un evento de cambio de reserva.
class _ReservationSocketEvent {
  final String type;
  final String id;

  const _ReservationSocketEvent({
    required this.type,
    required this.id,
  });
}
