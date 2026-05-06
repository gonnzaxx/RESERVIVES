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

/// Provider global para acceder al servicio de notificaciones push.
final pushNotificationsServiceProvider = Provider<PushNotificationsService>((ref) {
  return PushNotificationsService(ref);
});

/// Definición del canal de notificaciones para Android
const AndroidNotificationChannel _reservivesChannel =
AndroidNotificationChannel(
  'reservives_notifications',
  'Reservives Notifications',
  description: 'Canal principal de notificaciones de RESERVIVES',
  importance: Importance.high,
);

/// Clave VAPID necesaria para recibir notificaciones en navegadores Web.
const String _webVapidKey = String.fromEnvironment(
  'FIREBASE_WEB_VAPID_KEY',
  defaultValue: '',
);

/// Plugin para mostrar notificaciones locales cuando la app está en primer plano.
final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();


/// Handler global para procesar notificaciones de Firebase en segundo plano.
/// Debe ser una función de nivel superior y estar anotada para el entry-point de la VM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

/// Inicializa el bootstrap de notificaciones: Firebase, Handlers y canales locales.
Future<void> initializePushNotificationsBootstrap() async {
  try {
    // Inicializar Firebase con las opciones de la plataforma actual.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar el handler de mensajes en segundo plano.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // La configuración de notificaciones locales no es soportada igual en Web.
    if (kIsWeb) {
      return;
    }

    // Configuración de inicialización para Android e iOS.
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Crear el canal en Android para permitir notificaciones heads-up.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >()
        ?.createNotificationChannel(_reservivesChannel);

    // Listener para mensajes cuando la app está abierta.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      // Mostrar la notificación localmente ya que Firebase no la muestra automáticamente en foreground.
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

/// Servicio encargado de la lógica de negocio de las notificaciones push:
/// permisos, obtención de tokens y sincronización con el backend.
class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Solicita permisos al usuario y sincroniza el token FCM con nuestro servidor.
  Future<void> syncTokenWithBackend() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Obtener el token actual del dispositivo.
      final token = await _getPushToken(messaging);
      if (token == null || token.isEmpty) return;

      // Enviar el token inicial al backend.
      await _sendTokenToBackend(token);

      // Suscribirse a la renovación del token (si Firebase lo invalida o cambia).
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

  /// Obtiene el token de Firebase considerando las particularidades de la Web (VAPID).
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

  /// Envía el [token] al servidor mediante el [ApiClient].
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

  /// Cancela las suscripciones activas para evitar fugas de memoria.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
