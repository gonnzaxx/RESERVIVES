import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_settings_provider.dart';
import 'package:reservives/widgets/design_system.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _tokensRecargaCtrl = TextEditingController();
  final _tokensInicialesCtrl = TextEditingController();
  final _smtpFromCtrl = TextEditingController();
  final _announcementExpiryCtrl = TextEditingController();

  bool _smtpEnabled = false;
  bool _reservasHabilitadas = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataIntoControllers());
  }

  @override
  void dispose() {
    _tokensRecargaCtrl.dispose();
    _tokensInicialesCtrl.dispose();
    _smtpFromCtrl.dispose();
    _announcementExpiryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 900;
    final theme = Theme.of(context);

    ref.listen<AdminSettingsState>(adminSettingsProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false && next.data.isNotEmpty) {
        _loadDataIntoControllers();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading && state.data.isEmpty
            ? const Center(child: RvLogoLoader())
            : state.error != null && state.data.isEmpty
            ? Center(child: RvApiErrorState(onRetry: () => ref.read(adminSettingsProvider.notifier).loadSettings()))
            : Form(
          key: _formKey,
          child: Column(
            children: [
              // Cabecera Moderna Integrada
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: RvPageHeader(
                        title: context.tr('admin.settings.title'),
                        eyebrow: 'Configuración',
                        subtitle: context.tr('admin.settings.subtitle'),
                      ),
                    ),
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.read(adminSettingsProvider.notifier).loadSettings(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isWeb) _buildWebLayout() else _buildMobileLayout(),
                          const SizedBox(height: 100), // Espacio para el bottom bar
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: !state.isLoading && state.data.isNotEmpty ? _buildBottomAction(state.isLoading) : null,
    );
  }

  Widget _buildWebLayout() {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _buildSection(
          title: context.tr('admin.settings.section.tokens'),
          icon: Icons.stars_rounded,
          child: Column(
            children: [
              _numberField(controller: _tokensInicialesCtrl, label: context.tr('admin.label.initial.tokens'), icon: Icons.person_add_rounded),
              const SizedBox(height: 20),
              _numberField(controller: _tokensRecargaCtrl, label: context.tr('admin.label.mensual.tokens'), icon: Icons.auto_awesome_rounded),
            ],
          ),
        ),
        _buildSection(
          title: 'Sistema',
          icon: Icons.settings_suggest_rounded,
          child: Column(
            children: [
              _buildSwitchTile(
                value: _reservasHabilitadas,
                onChanged: (v) => setState(() => _reservasHabilitadas = v),
                title: context.tr('admin.settings.reserves.allowed'),
                subtitle: context.tr('admin.settings.reserves.allowed.subtitle'),
              ),
              const Divider(height: 32),
              _numberField(controller: _announcementExpiryCtrl, label: context.tr('admin.settings.announcements.expiry'), icon: Icons.timer_outlined),
            ],
          ),
        ),
        _buildSection(
          title: context.tr('admin.settings.notification.text'),
          icon: Icons.mail_rounded,
          child: Column(
            children: [
              _buildSwitchTile(
                value: _smtpEnabled,
                onChanged: (v) => setState(() => _smtpEnabled = v),
                title: context.tr('admin.settings.email.enabled'),
                subtitle: 'Envío automático de notificaciones',
              ),
              const SizedBox(height: 20),
              _textField(
                controller: _smtpFromCtrl,
                label: context.tr('admin.settings.email.from'),
                icon: Icons.alternate_email_rounded,
                enabled: _smtpEnabled,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildWebLayout(),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 1200 ? (1200 - 48 - 48) / 3 : (width > 900 ? (width - 48 - 24) / 2 : double.infinity);

    return SizedBox(
      width: cardWidth,
      child: RvSurfaceCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required bool value, required ValueChanged<bool> onChanged, required String title, String? subtitle}) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (v) {
        HapticFeedback.lightImpact();
        onChanged(v);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      contentPadding: EdgeInsets.zero,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildBottomAction(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: RvPrimaryButton(
            onTap: isLoading ? null : _saveSettings,
            isLoading: isLoading,
            label: context.tr('common.save'),
            icon: Icons.save_rounded,
          ),
        ),
      ),
    );
  }

  Widget _numberField({required TextEditingController controller, required String label, required IconData icon, int min = 0}) {
    return _textField(controller: controller, label: label, icon: icon, isNumber: true, min: min);
  }

  Widget _textField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false, int min = 0, bool enabled = true}) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: enabled ? null : theme.disabledColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.dividerColor.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (value) {
        if (!enabled) return null;
        final raw = value?.trim() ?? '';
        if (raw.isEmpty) return context.tr('validation.required');
        if (isNumber) {
          final parsed = int.tryParse(raw);
          if (parsed == null) return context.tr('validation.mustBeInt');
          if (parsed < min) return context.tr('validation.minValue').replaceAll('{n}', '$min');
        }
        return null;
      },
    );
  }

  void _loadDataIntoControllers() {
    final state = ref.read(adminSettingsProvider);
    if (state.isLoading || state.data.isEmpty) return;

    _tokensRecargaCtrl.text = state.data['tokens_por_recarga_alumno'] ?? '20';
    _tokensInicialesCtrl.text = state.data['tokens_iniciales_nuevo_usuario'] ?? '20';
    _smtpFromCtrl.text = state.data['smtp_from_email'] ?? '';
    _announcementExpiryCtrl.text = state.data['dias_caducidad_anuncio_defecto'] ?? '30';

    setState(() {
      _smtpEnabled = state.data['smtp_enabled']?.toLowerCase() == 'true';
      _reservasHabilitadas = state.data['se_permiten_reservas']?.toLowerCase() != 'false';
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(adminSettingsProvider.notifier).updateSettings({
      'tokens_por_recarga_alumno': _tokensRecargaCtrl.text.trim(),
      'tokens_iniciales_nuevo_usuario': _tokensInicialesCtrl.text.trim(),
      'smtp_enabled': _smtpEnabled.toString(),
      'smtp_from_email': _smtpFromCtrl.text.trim(),
      'se_permiten_reservas': _reservasHabilitadas.toString(),
      'dias_caducidad_anuncio_defecto': _announcementExpiryCtrl.text.trim(),
    });
    if (mounted && success) RvAlerts.success(context, context.tr('admin.settings.saved'));
  }
}