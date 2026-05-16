import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

class AdminAzureSettingsState {
  final bool isLoading;
  final Map<String, String> data;
  final String? error;

  const AdminAzureSettingsState({
    required this.isLoading,
    required this.data,
    this.error,
  });

  AdminAzureSettingsState copyWith({
    bool? isLoading,
    Map<String, String>? data,
    String? error,
  }) {
    return AdminAzureSettingsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
    );
  }
}

class AdminAzureSettingsNotifier extends Notifier<AdminAzureSettingsState> {
  @override
  AdminAzureSettingsState build() {
    Future.microtask(loadSettings);
    return const AdminAzureSettingsState(isLoading: true, data: {});
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/admin/configuracion/azure');
      final decoded = response as Map<String, dynamic>;
      final map = decoded.map((key, value) => MapEntry(key, value.toString()));
      state = AdminAzureSettingsState(isLoading: false, data: map);
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

      await client.put('/admin/configuracion/azure', body: {'configs': configsList});
      await loadSettings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final adminAzureSettingsProvider =
    NotifierProvider.autoDispose<AdminAzureSettingsNotifier, AdminAzureSettingsState>(
  AdminAzureSettingsNotifier.new,
);
