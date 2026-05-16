import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/roles_provider.dart';
import 'package:reservives/widgets/design_system.dart';


const _sectionMeta = <BackofficeSection, ({IconData icon, String label})>{
  BackofficeSection.summary:       (icon: Icons.dashboard_rounded,        label: 'Dashboard'),
  BackofficeSection.users:         (icon: Icons.people_rounded,            label: 'Usuarios'),
  BackofficeSection.bookings:      (icon: Icons.event_available_rounded,   label: 'Reservas'),
  BackofficeSection.history:       (icon: Icons.history_rounded,            label: 'Historial'),
  BackofficeSection.polls:         (icon: Icons.poll_rounded,              label: 'Encuestas'),
  BackofficeSection.incidents:     (icon: Icons.report_problem_rounded,    label: 'Incidencias'),
  BackofficeSection.metrics:       (icon: Icons.bar_chart_rounded,         label: 'Métricas'),
  BackofficeSection.spaces:        (icon: Icons.meeting_room_rounded,      label: 'Espacios'),
  BackofficeSection.services:      (icon: Icons.miscellaneous_services_rounded, label: 'Servicios'),
  BackofficeSection.announcements: (icon: Icons.campaign_rounded,          label: 'Anuncios'),
  BackofficeSection.cafeteria:     (icon: Icons.restaurant_rounded,        label: 'Cafetería'),
  BackofficeSection.configuration: (icon: Icons.settings_rounded,          label: 'Configuración'),
  BackofficeSection.azure:         (icon: Icons.cloud_rounded,             label: 'Azure & Entra ID'),
};

class AdminRolesSection extends ConsumerWidget {
  const AdminRolesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolesProvider);
    final theme = Theme.of(context);

    return RvSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('admin.settings.roles.title'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              RvGhostIconButton(
                icon: Icons.refresh_rounded,
                onTap: () => ref.read(rolesProvider.notifier).loadRoles(),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _showRoleDialog(context, ref, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('admin.settings.roles.add')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('admin.settings.roles.subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          if (state.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (state.error != null)
            RvApiErrorState(onRetry: () => ref.read(rolesProvider.notifier).loadRoles())
          else if (state.mappings.isEmpty)
              _EmptyRolesState(onAdd: () => _showRoleDialog(context, ref, null))
            else
              _RolesList(
                mappings: state.mappings,
                onEdit: (m) => _showRoleDialog(context, ref, m),
                onDelete: (m) => _confirmDelete(context, ref, m),
              ),
        ],
      ),
    );
  }

  // Abre el diálogo para crear o editar un rol y su mapeo de permisos
  void _showRoleDialog(BuildContext context, WidgetRef ref, RolMapping? existing) {
    showDialog(
      context: context,
      builder: (_) => _RoleFormDialog(existing: existing, ref: ref),
    );
  }

  // Pide confirmación y elimina el mapeo de rol si el usuario acepta
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, RolMapping mapping) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.settings.roles.deleteTitle'),
      content: context.tr('admin.settings.roles.deleteContent')
          .replaceAll('{role}', mapping.roleName),
      isDestructive: true,
    );
    if (confirmed != true) return;
    final ok = await ref.read(rolesProvider.notifier).deleteMapping(mapping.roleName);
    if (context.mounted) {
      if (ok) {
        RvAlerts.success(context, context.tr('admin.settings.roles.deleteSuccess'));
      } else {
        RvAlerts.error(context, context.tr('admin.settings.roles.deleteError'));
      }
    }
  }
}

class _RolesList extends StatelessWidget {
  final List<RolMapping> mappings;
  final ValueChanged<RolMapping> onEdit;
  final ValueChanged<RolMapping> onDelete;

  const _RolesList({
    required this.mappings,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: mappings
          .map((m) => _RoleCard(mapping: m, onEdit: onEdit, onDelete: onDelete))
          .toList(),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final RolMapping mapping;
  final ValueChanged<RolMapping> onEdit;
  final ValueChanged<RolMapping> onDelete;

  const _RoleCard({
    required this.mapping,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupIds = widget.mapping.groupIds;
    final sections = widget.mapping.backofficeSections;
    final hasAccess = widget.mapping.hasBackofficeAccess;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user_rounded, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mapping.roleName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${groupIds.length} grupo${groupIds.length == 1 ? '' : 's'} de Azure',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  onPressed: () {
                    setState(() => _visible = !_visible);
                    HapticFeedback.selectionClick();
                  },
                  tooltip: _visible ? 'Ocultar IDs' : 'Mostrar IDs',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.primary),
                  onPressed: () => widget.onEdit(widget.mapping),
                  tooltip: 'Editar',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                  onPressed: () => widget.onDelete(widget.mapping),
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 10),
            if (!hasAccess)
              _BackofficeBadge(
                label: 'Sin acceso al backoffice',
                icon: Icons.block_rounded,
                color: theme.colorScheme.error,
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sections.map((s) {
                  final section = BackofficeSection.values.firstWhere(
                        (e) => e.name == s,
                    orElse: () => BackofficeSection.summary,
                  );
                  final meta = _sectionMeta[section]!;
                  return _SectionChip(icon: meta.icon, label: meta.label, theme: theme);
                }).toList(),
              ),

            if (_visible && groupIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...groupIds.asMap().entries.map((entry) {
                final i = entry.key;
                final gid = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 6, left: 50),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          gid,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', letterSpacing: 0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: gid));
                          HapticFeedback.lightImpact();
                        },
                        tooltip: 'Copiar',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackofficeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _BackofficeBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _SectionChip({required this.icon, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRolesState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRolesState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              context.tr('admin.settings.roles.empty'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('admin.settings.roles.add')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleFormDialog extends StatefulWidget {
  final RolMapping? existing;
  final WidgetRef ref;

  const _RoleFormDialog({required this.existing, required this.ref});

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roleNameCtrl;
  late List<TextEditingController> _groupIdCtrls;
  late List<bool> _groupIdVisible;
  late bool _hasBackofficeAccess;
  late Set<String> _selectedSections;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _roleNameCtrl = TextEditingController(text: widget.existing?.roleName ?? '');
    final ids = widget.existing?.groupIds ?? [''];
    _groupIdCtrls = ids.map((id) => TextEditingController(text: id)).toList();
    _groupIdVisible = List.filled(ids.length, false, growable: true);
    _hasBackofficeAccess = widget.existing?.hasBackofficeAccess ?? false;
    _selectedSections = Set.from(widget.existing?.backofficeSections ?? []);
  }

  @override
  void dispose() {
    _roleNameCtrl.dispose();
    for (final c in _groupIdCtrls) c.dispose();
    super.dispose();
  }

  // Añade un nuevo campo de ID de grupo al formulario
  void _addGroupIdField() {
    setState(() {
      _groupIdCtrls.add(TextEditingController());
      _groupIdVisible.add(false);
    });
  }

  // Elimina el campo de ID de grupo en la posición dada (mínimo uno siempre)
  void _removeGroupIdField(int index) {
    if (_groupIdCtrls.length <= 1) return;
    setState(() {
      _groupIdCtrls[index].dispose();
      _groupIdCtrls.removeAt(index);
      _groupIdVisible.removeAt(index);
    });
  }

  // Alterna la selección de una sección del backoffice para el rol
  void _toggleSection(String sectionName) {
    setState(() {
      if (_selectedSections.contains(sectionName)) {
        _selectedSections.remove(sectionName);
      } else {
        _selectedSections.add(sectionName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.07),
                border: Border(bottom: BorderSide(color: cs.primary.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shield_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? context.tr('admin.settings.roles.editTitle')
                              : context.tr('admin.settings.roles.createTitle'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.existing!.roleName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: cs.outline, size: 20),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        TextFormField(
                          controller: _roleNameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                          decoration: InputDecoration(
                            labelText: context.tr('admin.settings.roles.field.roleName'),
                            hintText: 'Ej: ADMINISTRADOR, CONTROL',
                            prefixIcon: Icon(Icons.badge_rounded, color: cs.primary, size: 20),
                            filled: true,
                            fillColor: cs.primary.withValues(alpha: 0.04),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.2))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.15))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary, width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return context.tr('validation.required');
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // IDs de grupo Azure
                      _SectionHeader(icon: Icons.group_rounded, label: 'IDs de grupo Azure AD', trailing: '${_groupIdCtrls.length} grupo${_groupIdCtrls.length == 1 ? '' : 's'}', cs: cs, theme: theme),
                      const SizedBox(height: 10),

                      for (int i = 0; i < _groupIdCtrls.length; i++)
                        Padding(
                          key: ObjectKey(_groupIdCtrls[i]),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  margin: const EdgeInsets.only(left: 10),
                                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: cs.primary))),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _groupIdCtrls[i],
                                    obscureText: !_groupIdVisible[i],
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', letterSpacing: 0.2),
                                    decoration: InputDecoration(
                                      hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                                      hintStyle: TextStyle(fontSize: 12, color: cs.outline.withValues(alpha: 0.5)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return context.tr('validation.required');
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(_groupIdVisible[i] ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 17, color: cs.outline),
                                  onPressed: () => setState(() => _groupIdVisible[i] = !_groupIdVisible[i]),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (_groupIdCtrls.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 17, color: cs.error),
                                      onPressed: () => _removeGroupIdField(i),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      GestureDetector(
                        onTap: _addGroupIdField,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 16, color: cs.primary),
                              const SizedBox(width: 6),
                              Text('Añadir ID de grupo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Acceso al backoffice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _hasBackofficeAccess
                              ? cs.primary.withValues(alpha: isDark ? 0.12 : 0.06)
                              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasBackofficeAccess
                                ? cs.primary.withValues(alpha: 0.25)
                                : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Toggle
                            Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _hasBackofficeAccess ? cs.primary.withValues(alpha: 0.12) : cs.outline.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 18,
                                    color: _hasBackofficeAccess ? cs.primary : cs.outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Acceso al backoffice',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: _hasBackofficeAccess ? cs.primary : cs.onSurface,
                                        ),
                                      ),
                                      Text(
                                        _hasBackofficeAccess ? 'Elige las pantallas permitidas' : 'Este rol no puede entrar al panel de administración',
                                        style: TextStyle(fontSize: 11, color: cs.outline),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _hasBackofficeAccess,
                                  onChanged: (v) => setState(() {
                                    _hasBackofficeAccess = v;
                                    if (!v) _selectedSections.clear();
                                  }),
                                  activeThumbColor: cs.primary,
                                ),
                              ],
                            ),


                            if (_hasBackofficeAccess) ...[
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    'Pantallas permitidas',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.outline,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      if (_selectedSections.length == _sectionMeta.length) {
                                        _selectedSections.clear();
                                      } else {
                                        _selectedSections = _sectionMeta.keys.map((s) => s.name).toSet();
                                      }
                                    }),
                                    child: Text(
                                      _selectedSections.length == _sectionMeta.length ? 'Desmarcar todo' : 'Marcar todo',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...BackofficeSection.values.map((section) {
                                final meta = _sectionMeta[section]!;
                                final isSelected = _selectedSections.contains(section.name);
                                return _SectionToggleRow(
                                  icon: meta.icon,
                                  label: meta.label,
                                  selected: isSelected,
                                  onTap: () => _toggleSection(section.name),
                                  cs: cs,
                                  isDark: isDark,
                                );
                              }),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(context.tr('generic.cancel')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    label: Text(_isEditing ? context.tr('common.save') : context.tr('admin.settings.roles.create')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Valida y envía el formulario para crear o actualizar el mapeo de rol
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasBackofficeAccess && _selectedSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una pantalla del backoffice.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final roleName = _roleNameCtrl.text.trim().toUpperCase();
    final groupIds = _groupIdCtrls.map((c) => c.text.trim()).where((id) => id.isNotEmpty).toList();
    final sections = _hasBackofficeAccess ? _selectedSections.toList() : <String>[];
    bool ok;

    if (_isEditing) {
      ok = await widget.ref.read(rolesProvider.notifier).updateMapping(roleName, groupIds, sections);
    } else {
      ok = await widget.ref.read(rolesProvider.notifier).createMapping(roleName, groupIds, sections);
    }

    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        RvAlerts.success(
          context,
          _isEditing
              ? context.tr('admin.settings.roles.updateSuccess')
              : context.tr('admin.settings.roles.createSuccess'),
        );
      } else {
        RvAlerts.error(context, context.tr('admin.settings.roles.saveError'));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  final ColorScheme cs;
  final ThemeData theme;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.outline),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.outline, letterSpacing: 0.3)),
        const Spacer(),
        Text(trailing, style: TextStyle(fontSize: 11, color: cs.outline)),
      ],
    );
  }
}

class _SectionToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  const _SectionToggleRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? cs.primary : cs.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
