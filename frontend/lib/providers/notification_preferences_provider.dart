library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/notification_preferences.dart';
import 'package:reservives/services/api_client.dart';

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>(() {
  return NotificationPreferencesNotifier();
});

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    return _fetch();
  }

  Future<NotificationPreferences> _fetch() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/notificaciones/preferencias');
    return NotificationPreferences.fromJson(response as Map<String, dynamic>);
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    state = AsyncData(preferences);
    state = await AsyncValue.guard(() async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/notificaciones/preferencias',
        body: preferences.toJson(),
      );
      return NotificationPreferences.fromJson(response as Map<String, dynamic>);
    });
  }
}
