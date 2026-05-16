import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_azure_settings_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/screens/admin/system/admin_roles_section.dart';

class AdminAzureScreen extends ConsumerStatefulWidget {
  const AdminAzureScreen({super.key});

  @override
  ConsumerState<AdminAzureScreen> createState() => _AdminAzureScreenState();
}

class _AdminAzureScreenState extends ConsumerState<AdminAzureScreen> {
  final _azureClientIdCtrl = TextEditingController();
  final _azureTenantIdCtrl = TextEditingController();
  final _azureClientSecretCtrl = TextEditingController();
  final _azureAuthorityCtrl = TextEditingController();
  final _graphFromEmailCtrl = TextEditingController();

  bool _graphEmailEnabled = true;
  bool _azureSecretVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _azureClientIdCtrl.dispose();
    _azureTenantIdCtrl.dispose();
    _azureClientSecretCtrl.dispose();
    _azureAuthorityCtrl.dispose();
    _graphFromEmailCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final state = ref.read(adminAzureSettingsProvider);
    if (state.isLoading || state.data.isEmpty) return;
    final d = state.data;
    _azureClientIdCtrl.text = d['azure_client_id'] ?? '';
    _azureTenantIdCtrl.text = d['azure_tenant_id'] ?? '';
    _azureClientSecretCtrl.text = d['azure_client_secret'] ?? '';
    _azureAuthorityCtrl.text = d['azure_authority'] ?? '';
    _graphFromEmailCtrl.text = d['graph_from_email'] ?? '';
    setState(() {
      _graphEmailEnabled = d['graph_email_enabled']?.toLowerCase() != 'false';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAzureSettingsProvider);
    final theme = Theme.of(context);

    ref.listen<AdminAzureSettingsState>(adminAzureSettingsProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false && next.data.isNotEmpty) {
        _loadData();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading && state.data.isEmpty
            ? const _Skeleton()
            : state.error != null && state.data.isEmpty
                ? Center(child: RvApiErrorState(onRetry: () => ref.read(adminAzureSettingsProvider.notifier).loadSettings()))
                : Column(
                    children: [
                      _buildHeader(context, state),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionLabel(title: context.tr('admin.settings.section.graph'), icon: Icons.email_rounded),
                              const SizedBox(height: 10),
                              _buildGraphSection(theme),

                              const SizedBox(height: 24),
                              _SectionLabel(title: context.tr('admin.settings.section.azure'), icon: Icons.shield_rounded),
                              const SizedBox(height: 10),
                              _buildAzureSection(theme),

                              const SizedBox(height: 24),
                              _SectionLabel(title: context.tr('admin.settings.section.roles'), icon: Icons.manage_accounts_rounded),
                              const SizedBox(height: 10),
                              const AdminRolesSection(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminAzureSettingsState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('admin.azure.eyebrow').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('admin.azure.title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          RvGhostIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => ref.read(adminAzureSettingsProvider.notifier).loadSettings(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: state.isLoading ? null : _save,
            style: FilledButton.styleFrom(
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: state.isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphSection(ThemeData theme) {
    return _card(
      title: context.tr('admin.settings.section.graph'),
      icon: Icons.email_rounded,
      child: Column(
        children: [
          _switchRow(
            value: _graphEmailEnabled,
            onChanged: (v) => setState(() => _graphEmailEnabled = v),
            title: context.tr('admin.settings.graph.emailEnabled'),
            subtitle: context.tr('admin.settings.graph.emailEnabled.subtitle'),
            icon: Icons.mark_email_read_rounded,
          ),
          const Divider(height: 20),
          _textField(controller: _graphFromEmailCtrl, label: context.tr('admin.settings.graph.fromEmail'), icon: Icons.alternate_email_rounded),
        ],
      ),
    );
  }

  Widget _buildAzureSection(ThemeData theme) {
    return _card(
      title: context.tr('admin.settings.section.azure'),
      icon: Icons.cloud_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(controller: _azureClientIdCtrl, label: context.tr('admin.settings.azure.clientId'), icon: Icons.fingerprint_rounded),
          const SizedBox(height: 12),
          _textField(controller: _azureTenantIdCtrl, label: context.tr('admin.settings.azure.tenantId'), icon: Icons.domain_rounded),
          const SizedBox(height: 12),
          _secretField(
            controller: _azureClientSecretCtrl,
            label: context.tr('admin.settings.azure.clientSecret'),
            icon: Icons.vpn_key_rounded,
            visible: _azureSecretVisible,
            onToggle: () => setState(() => _azureSecretVisible = !_azureSecretVisible),
          ),
          const SizedBox(height: 12),
          _textField(controller: _azureAuthorityCtrl, label: context.tr('admin.settings.azure.authority'), icon: Icons.link_rounded),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('admin.settings.azure.note'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return RvSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _switchRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required IconData icon,
    String? subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); },
          activeColor: cs.primary,
        ),
      ],
    );
  }

  Widget _textField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _secretField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
          onPressed: onToggle,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _save() async {
    final settings = <String, String>{
      'graph_email_enabled': _graphEmailEnabled.toString(),
      'graph_from_email': _graphFromEmailCtrl.text.trim(),
      if (_azureClientIdCtrl.text.trim().isNotEmpty)
        'azure_client_id': _azureClientIdCtrl.text.trim(),
      if (_azureTenantIdCtrl.text.trim().isNotEmpty)
        'azure_tenant_id': _azureTenantIdCtrl.text.trim(),
      if (_azureClientSecretCtrl.text.trim().isNotEmpty)
        'azure_client_secret': _azureClientSecretCtrl.text.trim(),
      if (_azureAuthorityCtrl.text.trim().isNotEmpty)
        'azure_authority': _azureAuthorityCtrl.text.trim(),
    };
    final success = await ref.read(adminAzureSettingsProvider.notifier).updateSettings(settings);
    if (mounted && success) RvAlerts.success(context, context.tr('admin.settings.saved'));
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: theme.colorScheme.primary.withValues(alpha: 0.15))),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RvSkeleton(width: 140, height: 11, borderRadius: 5),
          const SizedBox(height: 8),
          const RvSkeleton(width: 220, height: 20, borderRadius: 7),
          const SizedBox(height: 20),
          for (int i = 0; i < 3; i++) ...[
            RvSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    RvSkeleton(width: 18, height: 18, borderRadius: 5),
                    SizedBox(width: 10),
                    RvSkeleton(width: 120, height: 14, borderRadius: 5),
                  ]),
                  const SizedBox(height: 16),
                  for (int j = 0; j < 2; j++) ...[
                    RvSkeleton(width: double.infinity, height: 40, borderRadius: 10),
                    if (j < 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
