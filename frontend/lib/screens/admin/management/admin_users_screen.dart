import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/roles_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

final adminUsersProvider = FutureProvider.autoDispose<List<Usuario>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/usuarios/');
  return (response as List<dynamic>)
      .map((json) => Usuario.fromJson(json as Map<String, dynamic>))
      .toList();
});

// Devuelve el label traducido para un rol dado
String _roleLabelFromValue(BuildContext context, String role) {
  switch (role) {
    case 'ALUMNO':
      return context.tr('admin.users.role.student');
    case 'PROFESOR':
      return context.tr('admin.users.role.teacher');
    case 'ADMINISTRADOR':
      return context.tr('admin.users.role.administrador');
    case 'CAFETERIA':
      return context.tr('admin.users.role.cafeteria');
    case 'JEFATURA':
      return context.tr('admin.users.role.jefatura');
    case 'SECRETARIA':
      return context.tr('admin.users.role.secretaria');
    case 'GESTOR_SERVICIO':
      return context.tr('admin.users.role.gestorServicio');
    case 'CONTROL':
      return context.tr('admin.users.role.control');
    default:
      return role;
  }
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _selectedRole = 'TODOS';

  static const _baseRoles = [
    'ALUMNO', 'PROFESOR', 'ADMINISTRADOR', 'CAFETERIA',
    'JEFATURA', 'SECRETARIA', 'GESTOR_SERVICIO', 'CONTROL',
  ];

  // Combina los roles base con los roles configurados dinámicamente
  List<String> _mergedRoles() {
    final configured = ref.read(rolesProvider).mappings.map((m) => m.roleName).toList();
    final merged = {..._baseRoles, ...configured}.toList()..sort();
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final width = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    int crossAxisCount = 1;
    double extent = 120;
    if (width > 1200) {
      crossAxisCount = 3;
      extent = 140;
    } else if (width > 800) {
      crossAxisCount = 2;
      extent = 130;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin.users.eyebrow').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('admin.users.title'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RvGhostIconButton(
                    icon: Icons.add_card_rounded,
                    onTap: () => _bulkAdjustTokens(context),
                  ),
                  const SizedBox(width: 4),
                  RvGhostIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref.invalidate(adminUsersProvider),
                  ),
                ],
              ),
            ),

            _buildFilterBar(theme),

            Expanded(
              child: usersAsync.when(
                data: (users) {
                  final filtered = users.where((user) {
                    if (_selectedRole == 'TODOS') return true;
                    return user.rol.value.toUpperCase() == _selectedRole;
                  }).toList();

                  if (filtered.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: context.tr('admin.users.emptyTitle'),
                      subtitle: context.tr('admin.users.emptySubtitle'),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, width > 700 ? 40 : 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: extent,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _UserAdminCard(
                      user: filtered[index],
                      onAdjust: () => _editarUsuario(context, filtered[index]),
                    ),
                  );
                },
                loading: () => _AdminUsersSkeleton(crossAxisCount: crossAxisCount, extent: extent),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(adminUsersProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Barra de filtro para seleccionar el rol a mostrar
  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedRole,
        dropdownColor: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.primary),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        elevation: 16,
        decoration: InputDecoration(
          labelText: context.tr('admin.users.filterByRole'),
          prefixIcon: const Icon(Icons.filter_list_rounded),
          filled: true,
          fillColor: theme.dividerColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        items: [
          'TODOS', ..._mergedRoles(),
        ].map((role) {
          return DropdownMenuItem(
            value: role,
            child: Text(role == 'TODOS' ? context.tr('admin.users.role.all') : _roleLabelFromValue(context, role)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedRole = value);
        },
      ),
    );
  }

  // Ajuste masivo de tokens para todos los usuarios de un rol
  Future<void> _bulkAdjustTokens(BuildContext context) async {
    final tokenController = TextEditingController();
    final theme = Theme.of(context);
    String selectedRole = _selectedRole;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(context.tr('admin.users.bulkTokens.title'), style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('admin.users.bulkTokens.subtitle'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                dropdownColor: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                decoration: InputDecoration(
                  labelText: context.tr('admin.users.filterByRole'),
                  prefixIcon: const Icon(Icons.group_rounded),
                  filled: true,
                  fillColor: theme.dividerColor.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                items: [
                  'TODOS', ..._mergedRoles(),
                ].map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role == 'TODOS' ? context.tr('admin.users.role.all') : _roleLabelFromValue(context, role)),
                )).toList(),
                onChanged: (v) { if (v != null) setStateDialog(() => selectedRole = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*'))],
                decoration: InputDecoration(
                  labelText: context.tr('admin.users.bulkTokens.amount'),
                  prefixIcon: const Icon(Icons.stars_rounded),
                  suffixText: 'Tokens',
                  filled: true,
                  fillColor: theme.dividerColor.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('generic.cancel'))),
            FilledButton(
              onPressed: () {
                final amount = int.tryParse(tokenController.text);
                if (amount == null || amount == 0) return;
                Navigator.pop(ctx, {'role': selectedRole, 'amount': amount});
              },
              child: Text(context.tr('admin.users.save')),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      final amount = result['amount'] as int;
      final role = result['role'] as String;
      final apiClient = ref.read(apiClientProvider);
      final rolParam = (role == 'TODOS') ? '' : '&rol=$role';
      final response = await apiClient.post(
        '/usuarios/tokens/bulk?cantidad=$amount$rolParam',
      ) as Map<String, dynamic>;
      final count = response['count'] ?? 0;
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        RvAlerts.success(
          context,
          context.tr('admin.users.bulkTokens.success').replaceAll('{count}', '$count'),
        );
      }
    } catch (error) {
      if (context.mounted) RvAlerts.error(context, context.tr('admin.users.bulkTokens.error'));
    }
  }

  // Abre el formulario de edición de usuario (rol y tokens)
  Future<void> _editarUsuario(BuildContext context, Usuario user) async {
    final tokenController = TextEditingController();
    final theme = Theme.of(context);
    String currentRole = user.rol.value;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
              child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12, left: 24, right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RvSheetHeader(onClose: () => Navigator.pop(context)),
                  const SizedBox(height: 8),
                  Text(context.tr('admin.user.editUser.text'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text(user.nombreCompleto, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    initialValue: currentRole,
                    dropdownColor: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    icon: Icon(Icons.unfold_more_rounded, color: theme.colorScheme.primary),
                    decoration: InputDecoration(
                      labelText: context.tr('admin.user.editUser.label.rol'),
                      prefixIcon: const Icon(Icons.manage_accounts_rounded),
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: _mergedRoles().map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabelFromValue(context, role)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setStateModal(() => currentRole = value);
                    },
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: tokenController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
                    ],
                    decoration: InputDecoration(
                        labelText: context.tr('admin.user.editUser.label.tokens'),
                        hintText: 'Ej: 10 o -5',
                        prefixIcon: Icon(Icons.stars_rounded),
                        suffixText: 'Tokens'
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('generic.cancel')))),
                      const SizedBox(width: 16),
                      Expanded(child: RvPrimaryButton(
                          onTap: () => Navigator.pop(context, {
                            'rol': currentRole,
                            'tokens': int.tryParse(tokenController.text),
                          }),
                          label: context.tr('admin.users.save'))
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          }
      ),
    );

    if (result == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      bool changed = false;

      if (result['rol'] != user.rolRaw) {
        await apiClient.put('/usuarios/${user.id}', body: {'rol': result['rol']});
        changed = true;
        final currentUser = ref.read(authProvider).user;
        if (currentUser != null && currentUser.id == user.id) {
          await ref.read(authProvider.notifier).refreshCurrentUser();
        }
      }

      final tokensToAdd = result['tokens'] as int?;
      if (tokensToAdd != null && tokensToAdd != 0) {
        final nextTokens = user.tokens + tokensToAdd;
        if (nextTokens < 0 || nextTokens > maxUserTokens) {
          if (context.mounted) {
            RvAlerts.error(
              context,
              context.tr('admin.users.tokensRangeError').replaceAll('{max}', maxUserTokens.toString()),
            );
          }
          return;
        }
        await apiClient.post('/usuarios/${user.id}/tokens?cantidad=$tokensToAdd');
        changed = true;
      }

      if (changed) {
        ref.invalidate(adminUsersProvider);
        notifyAdminCountersChanged(ref);
        if (context.mounted) RvAlerts.success(context, 'Usuario actualizado correctamente');
      }
    } catch (error) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error));
    }
  }
}

class _UserAdminCard extends StatelessWidget {
  final Usuario user;
  final VoidCallback onAdjust;

  const _UserAdminCard({required this.user, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft(context),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onAdjust,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    user.nombre[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          RvBadge(
                            label: _roleLabelFromValue(context, user.rolRaw),
                            color: user.isAdministrador ? AppColors.accentPurple : AppColors.primaryBlue,
                          ),
                          RvBadge(
                            label: '${user.tokens} ${context.tr('admin.users.tokens')}',
                            color: isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade700,
                            icon: Icons.stars_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUsersSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double extent;
  const _AdminUsersSkeleton({required this.crossAxisCount, required this.extent});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: extent,
      ),
      itemCount: 9,
      itemBuilder: (context, index) => RvSkeleton(width: double.infinity, height: extent, borderRadius: 24),
    );
  }
}