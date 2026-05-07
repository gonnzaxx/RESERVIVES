import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_settings_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/screens/admin/admin_tramos_section.dart';
import 'package:reservives/config/constants.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _tokensInicialesAlumnoCtrl = TextEditingController();
  final _tokensInicialesProfesorCtrl = TextEditingController();
  final _tokensRecargaAlumnoCtrl = TextEditingController();
  final _tokensRecargaProfesorCtrl = TextEditingController();
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
    _tokensInicialesAlumnoCtrl.dispose();
    _tokensInicialesProfesorCtrl.dispose();
    _tokensRecargaAlumnoCtrl.dispose();
    _tokensRecargaProfesorCtrl.dispose();
    _announcementExpiryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 900;

    ref.listen<AdminSettingsState>(adminSettingsProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          next.data.isNotEmpty) {
        _loadDataIntoControllers();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading && state.data.isEmpty
            ? const _AdminSettingsSkeleton()
            : state.error != null && state.data.isEmpty
            ? Center(
          child: RvApiErrorState(
            onRetry: () =>
                ref.read(adminSettingsProvider.notifier).loadSettings(),
          ),
        )
            : Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: RvPageHeader(
                        title: context.tr('admin.settings.title'),
                        eyebrow: context.tr('admin.settings.eyebrow'),
                        subtitle: context.tr('admin.settings.subtitle'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref
                          .read(adminSettingsProvider.notifier)
                          .loadSettings(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isWeb)
                            _buildWebLayout()
                          else
                            _buildMobileLayout(),
                          const SizedBox(height: 120), // Espacio para el FAB
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
      // Botón de guardar como Floating Action Button moderno
      floatingActionButton: !state.isLoading && state.data.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton.extended(
          onPressed: state.isLoading ? null : _saveSettings,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          icon: state.isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded),
          label: Text(
            context.tr('common.save').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: context.tr('admin.settings.section.tokens'),
                icon: Icons.stars_rounded,
                child: Column(
                  children: [
                    _numberField(controller: _tokensInicialesAlumnoCtrl, label: context.tr('admin.settings.tokens.students.initial'), icon: Icons.school_rounded, min: 1),
                    const SizedBox(height: 20),
                    _numberField(controller: _tokensInicialesProfesorCtrl, label: context.tr('admin.settings.tokens.teachers.initial'), icon: Icons.badge_rounded, min: 1),
                    const SizedBox(height: 20),
                    _numberField(controller: _tokensRecargaAlumnoCtrl, label: context.tr('admin.settings.tokens.students.monthly'), icon: Icons.autorenew_rounded, min: 1),
                    const SizedBox(height: 20),
                    _numberField(controller: _tokensRecargaProfesorCtrl, label: context.tr('admin.settings.tokens.teachers.monthly'), icon: Icons.refresh_rounded, min: 1),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: context.tr('admin.settings.eyebrow'),
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
                    _numberField(controller: _announcementExpiryCtrl, label: context.tr('admin.settings.announcements.expiry'), icon: Icons.timer_outlined, min: 1),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: context.tr('admin.settings.notification.text'),
                icon: Icons.mail_rounded,
                child: _buildSwitchTile(
                  value: _smtpEnabled,
                  onChanged: (v) => setState(() => _smtpEnabled = v),
                  title: context.tr('admin.settings.email.enabled'),
                  subtitle: context.tr('admin.settings.email.automatic'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        const Expanded(
          flex: 3,
          child: AdminTramosSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSection(
          title: context.tr('admin.settings.section.tokens'),
          icon: Icons.stars_rounded,
          child: Column(
            children: [
              _numberField(controller: _tokensInicialesAlumnoCtrl, label: context.tr('admin.settings.tokens.students.initial'), icon: Icons.school_rounded, min: 1),
              const SizedBox(height: 20),
              _numberField(controller: _tokensInicialesProfesorCtrl, label: context.tr('admin.settings.tokens.teachers.initial'), icon: Icons.badge_rounded, min: 1),
              const SizedBox(height: 20),
              _numberField(controller: _tokensRecargaAlumnoCtrl, label: context.tr('admin.settings.tokens.students.monthly'), icon: Icons.autorenew_rounded, min: 1),
              const SizedBox(height: 20),
              _numberField(controller: _tokensRecargaProfesorCtrl, label: context.tr('admin.settings.tokens.teachers.monthly'), icon: Icons.refresh_rounded, min: 1),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: context.tr('admin.settings.eyebrow'),
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
              _numberField(controller: _announcementExpiryCtrl, label: context.tr('admin.settings.announcements.expiry'), icon: Icons.timer_outlined, min: 1),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: context.tr('admin.settings.notification.text'),
          icon: Icons.mail_rounded,
          child: _buildSwitchTile(
            value: _smtpEnabled,
            onChanged: (v) => setState(() => _smtpEnabled = v),
            title: context.tr('admin.settings.email.enabled'),
            subtitle: context.tr('admin.settings.email.automatic'),
          ),
        ),
        const SizedBox(height: 24),
        const AdminTramosSection(),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return RvSurfaceCard(
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
    );
  }

  Widget _buildSwitchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    String? subtitle,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (v) {
        HapticFeedback.lightImpact();
        onChanged(v);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int min = 0,
  }) {
    return _textField(controller: controller, label: label, icon: icon, isNumber: true, min: min);
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    int min = 0,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
      style: TextStyle(fontWeight: FontWeight.bold, color: enabled ? null : theme.disabledColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.dividerColor.withValues(alpha: 0.03),
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

    _tokensInicialesAlumnoCtrl.text = state.data['tokens_iniciales_alumno'] ?? state.data['tokens_iniciales_nuevo_usuario'] ?? '20';
    _tokensInicialesProfesorCtrl.text = state.data['tokens_iniciales_profesor'] ?? '60';
    _tokensRecargaAlumnoCtrl.text = state.data['tokens_recarga_mensual_alumno'] ?? state.data['tokens_por_recarga_alumno'] ?? '20';
    _tokensRecargaProfesorCtrl.text = state.data['tokens_recarga_mensual_profesor'] ?? '60';
    _announcementExpiryCtrl.text = state.data['dias_caducidad_anuncio_defecto'] ?? '30';

    setState(() {
      _smtpEnabled = state.data['smtp_enabled']?.toLowerCase() == 'true';
      _reservasHabilitadas = state.data['se_permiten_reservas']?.toLowerCase() != 'false';
    });
  }

  Future<void> _saveSettings() async {

    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(adminSettingsProvider.notifier).updateSettings({
      'tokens_iniciales_alumno': _tokensInicialesAlumnoCtrl.text.trim(),
      'tokens_iniciales_profesor': _tokensInicialesProfesorCtrl.text.trim(),
      'tokens_recarga_mensual_alumno': _tokensRecargaAlumnoCtrl.text.trim(),
      'tokens_recarga_mensual_profesor': _tokensRecargaProfesorCtrl.text.trim(),
      'tokens_por_recarga_alumno': _tokensRecargaAlumnoCtrl.text.trim(),
      'tokens_iniciales_nuevo_usuario': _tokensInicialesAlumnoCtrl.text.trim(),
      'smtp_enabled': _smtpEnabled.toString(),
      'se_permiten_reservas': _reservasHabilitadas.toString(),
      'dias_caducidad_anuncio_defecto': _announcementExpiryCtrl.text.trim(),
    });
    if (mounted && success) {
      RvAlerts.success(context, context.tr('admin.settings.saved'));
    }
  }
}

class _AdminSettingsSkeleton extends StatelessWidget {
  const _AdminSettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              const RvSkeleton(width: 160, height: 12, borderRadius: 6),
              const SizedBox(height: 10),
              const RvSkeleton(width: 240, height: 22, borderRadius: 8),
              const SizedBox(height: 8),
              const RvSkeleton(width: 320, height: 14, borderRadius: 6),
              const SizedBox(height: 32),
              if (isWeb)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _sectionsSkeleton()),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _cardSkeleton(fieldCount: 6)),
                  ],
                )
              else
                _sectionsSkeleton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionsSkeleton() {
    return Column(
      children: [
        _cardSkeleton(fieldCount: 4),
        const SizedBox(height: 24),
        _cardSkeleton(fieldCount: 2),
        const SizedBox(height: 24),
        _cardSkeleton(fieldCount: 1),
      ],
    );
  }

  Widget _cardSkeleton({required int fieldCount}) {
    return RvSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección
          Row(
            children: const [
              RvSkeleton(width: 20, height: 20, borderRadius: 6),
              SizedBox(width: 12),
              RvSkeleton(width: 140, height: 16, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 24),
          // Campos
          for (int i = 0; i < fieldCount; i++) ...[
            RvSkeleton(width: double.infinity, height: 56, borderRadius: 16),
            if (i < fieldCount - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}