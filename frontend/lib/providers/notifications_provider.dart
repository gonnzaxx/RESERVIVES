library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/notificacion.dart';
import 'package:reservives/services/api_client.dart';

final notificationsRefreshTickProvider = StreamProvider.autoDispose<int>((
    ref,
    ) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 8));
    tick++;
    yield tick;
  }
});

final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(notificationsRefreshTickProvider);
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/notificaciones/count');
  return (response['no_leidas'] as num).toInt();
});

final notificationsInboxProvider =
AsyncNotifierProvider<NotificationsInboxNotifier, List<Notificacion>>(() {
  return NotificationsInboxNotifier();
});

class NotificationsInboxNotifier extends AsyncNotifier<List<Notificacion>> {

  @override
  Future<List<Notificacion>> build() async {
    return _fetchNotifications();
  }

  Future<List<Notificacion>> _fetchNotifications() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/notificaciones/');
    return (response as List<dynamic>)
        .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadUnread() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  Future<void> consumeUnread() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/notificaciones/consumir');

      ref.invalidate(unreadNotificationsCountProvider);

      return (response as List<dynamic>)
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> deleteNotification(String id) async {
    final oldState = state.value ?? [];
    state = AsyncData(oldState.where((n) => n.id != id).toList());

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/notificaciones/$id');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      state = AsyncData(oldState);
    }
  }
}
