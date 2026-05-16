import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

/// Devuelve las secciones de backoffice configuradas en DB por cada rol.
/// Formato: { "CONTROL": ["bookings"], "CAFETERIA": ["cafeteria"], ... }
final rolePermissionsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final resp = await client.get('/admin/configuracion/role-sections') as Map<String, dynamic>;
    return resp.map(
      (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
    );
  } catch (_) {
    return {};
  }
});
