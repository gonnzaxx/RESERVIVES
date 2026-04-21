import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'dart:developer' as developer;

final adminWebSocketProvider = Provider.autoDispose<AdminWebSocketService>((
  ref,
) {
  final service = AdminWebSocketService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class AdminWebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnecting = false;

  AdminWebSocketService(this._ref);

  void connect() {
    if (_isConnecting || _channel != null) return;

    final token = _ref.read(authProvider.notifier).token;
    if (token == null) return;

    _isConnecting = true;

    final wsUri = Uri.parse(AppConstants.apiBaseUrl).replace(
      scheme: AppConstants.apiBaseUrl.startsWith('https') ? 'wss' : 'ws',
    );
    final adminWsUrl = '${wsUri.toString()}/admin/ws?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(adminWsUrl));
      _subscription = _channel?.stream.listen(
        (message) {
          developer.log('Admin WS received: $message', name: 'admin.websocket');
          final event = _extractEventName(message);
          if (shouldRefreshAdminDashboardCounters(event)) {
            _ref.read(adminCountersVersionProvider.notifier).bump();
          }
        },
        onError: (e) {
          developer.log('Admin WS Error', error: e, name: 'admin.websocket');
          _reconnect();
        },
        onDone: () {
          _reconnect();
        },
      );
    } catch (e) {
      _reconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _reconnect() {
    dispose();
    Future.delayed(const Duration(seconds: 5), () {
      if (_ref.read(authProvider).user?.rol.value == 'ADMIN') {
        connect();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
  }

  String? _extractEventName(dynamic message) {
    try {
      if (message is! String) return null;
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        final event = decoded['event'];
        if (event is String && event.isNotEmpty) {
          return event;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
