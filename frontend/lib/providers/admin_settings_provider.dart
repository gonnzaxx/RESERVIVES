import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

class AdminSettingsState {
  final bool isLoading;
  final Map<String, String> data;
  final String? error;

  AdminSettingsState({required this.isLoading, required this.data, this.error});

  AdminSettingsState copyWith({
    bool? isLoading,
    Map<String, String>? data,
    String? error,
  }) {
    return AdminSettingsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
    );
  }
}

class AdminSettingsNotifier extends Notifier<AdminSettingsState> {
  @override
  AdminSettingsState build() {
    Future.microtask(loadSettings);
    return AdminSettingsState(isLoading: true, data: {});
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final responseBody = await client.get('/admin/configuracion');

      final decoded = responseBody as Map<String, dynamic>;
      final map = decoded.map((key, value) => MapEntry(key, value.toString()));

      state = state.copyWith(isLoading: false, data: map);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateSettings(Map<String, String> newSettings) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);

      final configsList = newSettings.entries
          .map((e) => {'clave': e.key, 'valor': e.value})
          .toList();

      await client.put('/admin/configuracion', body: {'configs': configsList});

      await loadSettings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final adminSettingsProvider =
NotifierProvider.autoDispose<AdminSettingsNotifier, AdminSettingsState>(
  AdminSettingsNotifier.new,
);