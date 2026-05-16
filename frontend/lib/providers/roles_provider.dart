import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/providers/role_permissions_provider.dart';
import 'package:reservives/services/api_client.dart';

class RolMapping {
  final String roleName;
  final List<String> groupIds;
  final List<String> backofficeSections;

  bool get hasBackofficeAccess => backofficeSections.isNotEmpty;

  const RolMapping({
    required this.roleName,
    required this.groupIds,
    this.backofficeSections = const [],
  });

  factory RolMapping.fromJson(Map<String, dynamic> json) => RolMapping(
        roleName: json['role_name'] as String,
        groupIds: (json['group_ids'] as List<dynamic>).map((e) => e as String).toList(),
        backofficeSections: ((json['backoffice_sections'] as List<dynamic>?) ?? [])
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'role_name': roleName,
        'group_ids': groupIds,
        'backoffice_sections': backofficeSections,
      };

  RolMapping copyWith({
    String? roleName,
    List<String>? groupIds,
    List<String>? backofficeSections,
  }) =>
      RolMapping(
        roleName: roleName ?? this.roleName,
        groupIds: groupIds ?? this.groupIds,
        backofficeSections: backofficeSections ?? this.backofficeSections,
      );
}

class RolesState {
  final List<RolMapping> mappings;
  final bool isLoading;
  final String? error;

  const RolesState({
    this.mappings = const [],
    this.isLoading = false,
    this.error,
  });

  RolesState copyWith({
    List<RolMapping>? mappings,
    bool? isLoading,
    String? error,
  }) =>
      RolesState(
        mappings: mappings ?? this.mappings,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class RolesNotifier extends Notifier<RolesState> {
  @override
  RolesState build() {
    Future.microtask(loadRoles);
    return const RolesState(isLoading: true);
  }

  Future<void> loadRoles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/admin/configuracion/roles');
      final list = (response as List<dynamic>)
          .map((e) => RolMapping.fromJson(e as Map<String, dynamic>))
          .toList();
      state = RolesState(mappings: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createMapping(
    String roleName,
    List<String> groupIds,
    List<String> backofficeSections,
  ) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/admin/configuracion/roles', body: {
        'role_name': roleName.trim().toUpperCase(),
        'group_ids': groupIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList(),
        'backoffice_sections': backofficeSections,
      });
      await loadRoles();
      ref.invalidate(rolePermissionsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMapping(
    String roleName,
    List<String> groupIds,
    List<String> backofficeSections,
  ) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        '/admin/configuracion/roles/${roleName.toUpperCase()}',
        body: {
          'group_ids': groupIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList(),
          'backoffice_sections': backofficeSections,
        },
      );
      await loadRoles();
      ref.invalidate(rolePermissionsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMapping(String roleName) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/admin/configuracion/roles/${roleName.toUpperCase()}');
      await loadRoles();
      ref.invalidate(rolePermissionsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final rolesProvider = NotifierProvider<RolesNotifier, RolesState>(
  RolesNotifier.new,
);
