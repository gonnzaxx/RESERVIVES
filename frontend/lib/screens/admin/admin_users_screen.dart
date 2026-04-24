import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

final adminUsersProvider = FutureProvider.autoDispose<List<Usuario>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/usuarios/');
  return (response as List<dynamic>)
      .map((json) => Usuario.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _selectedRole = 'TODOS';

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
      // Quitamos el AppBar para tener control total del diseño superior
      body: SafeArea(
        child: Column(
          children: [
            // --- NUEVA CABECERA MODERNA ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: RvPageHeader(
                title: context.tr('admin.users.title'),
                eyebrow: 'Gestión',
                trailing: Row(
                  children: [
                    // Icono de recarga con estilo "Ghost"
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(adminUsersProvider),
                    ),
                  ],
                ),
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

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          labelText: context.tr('admin.users.filterByRole'),
          prefixIcon: const Icon(Icons.filter_list_rounded),
          filled: true,
          fillColor: theme.dividerColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        items: [
          DropdownMenuItem(value: 'TODOS', child: Text(context.tr('admin.users.role.all'))),
          DropdownMenuItem(value: 'ALUMNO', child: Text(context.tr('admin.users.role.student'))),
          DropdownMenuItem(value: 'PROFESOR', child: Text(context.tr('admin.users.role.teacher'))),
          DropdownMenuItem(value: 'ADMIN', child: Text(context.tr('admin.users.role.admin'))),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _selectedRole = value);
        },
      ),
    );
  }

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
            return Container(
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
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text('Editar a', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text(user.nombreCompleto, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: currentRole,
                    decoration: InputDecoration(
                      labelText: 'Rol del usuario',
                      prefixIcon: const Icon(Icons.manage_accounts_rounded),
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALUMNO', child: Text('Alumno')),
                      DropdownMenuItem(value: 'PROFESOR', child: Text('Profesor')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                    ],
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
                    decoration: const InputDecoration(
                        labelText: 'Añadir o quitar tokens',
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
            );
          }
      ),
    );

    if (result == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      bool changed = false;

      // Actualizar el rol si cambió
      if (result['rol'] != user.rol.value) {
        await apiClient.put('/usuarios/${user.id}', body: {'rol': result['rol']});
        changed = true;
      }

      // Actualizar tokens si hay una cantidad
      final tokensToAdd = result['tokens'] as int?;
      if (tokensToAdd != null && tokensToAdd != 0) {
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
                          RvBadge(label: user.rol.value, color: user.isAdmin ? AppColors.accentPurple : AppColors.primaryBlue),
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