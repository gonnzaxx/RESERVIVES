library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/firebase_options.dart';
import 'package:reservives/services/api_client.dart';

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((
    ref,
    ) {
  return PushNotificationsService(ref);
});

const AndroidNotificationChannel _reservivesChannel =
AndroidNotificationChannel(
  'reservives_notifications',
  'Reservives Notifications',
  description: 'Canal principal de notificaciones de RESERVIVES',
  importance: Importance.high,
);

const String _webVapidKey = String.fromEnvironment(
  'FIREBASE_WEB_VAPID_KEY',
  defaultValue: '',
);

final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

Future<void> initializePushNotificationsBootstrap() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (kIsWeb) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >()
        ?.createNotificationChannel(_reservivesChannel);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reservives_notifications',
            'Reservives Notifications',
            channelDescription:
            'Canal principal de notificaciones de RESERVIVES',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  } catch (e, st) {
    developer.log(
      'No se pudo inicializar Firebase Messaging',
      name: 'services.push_notifications',
      error: e,
      stackTrace: st,
    );
  }
}

class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> syncTokenWithBackend() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await _getPushToken(messaging);
      if (token == null || token.isEmpty) return;

      await _sendTokenToBackend(token);

      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((
          newToken,
          ) async {
        try {
          await _sendTokenToBackend(newToken);
        } catch (e, st) {
          developer.log(
            'No se pudo refrescar el token push',
            name: 'services.push_notifications',
            error: e,
            stackTrace: st,
          );
        }
      });
    } catch (e, st) {
      developer.log(
        'No se pudo sincronizar el token push con backend',
        name: 'services.push_notifications',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> _getPushToken(FirebaseMessaging messaging) async {
    if (!kIsWeb) {
      return messaging.getToken();
    }

    if (_webVapidKey.isEmpty) {
      developer.log(
        'No hay VAPID key configurada para web. Usa --dart-define=FIREBASE_WEB_VAPID_KEY=... al ejecutar la app.',
        name: 'services.push_notifications',
      );
      return null;
    }

    return messaging.getToken(vapidKey: _webVapidKey);
  }

  Future<void> _sendTokenToBackend(String token) {
    return _ref
        .read(apiClientProvider)
        .post(
      '/notificaciones/push-token',
      body: {
        'token': token,
        'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      },
    );
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
