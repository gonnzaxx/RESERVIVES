import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_settings_provider.dart';
import 'package:reservives/providers/roles_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/providers/spaces_provider.dart' show espaciosProvider, espacioDetalleProvider;
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/screens/admin/system/admin_tramos_section.dart';
import 'package:reservives/screens/admin/system/admin_non_working_days_section.dart';

const _kGeminiModelsFallback = [
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.0-flash',
  'gemini-2.0-flash-lite',
  'gemini-1.5-flash',
  'gemini-1.5-pro',
];

final geminiModelsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final resp = await client.get('/admin/configuracion/gemini-models') as Map<String, dynamic>;
    final models = (resp['models'] as List<dynamic>).cast<String>();
    return models.isNotEmpty ? models : _kGeminiModelsFallback;
  } catch (_) {
    return _kGeminiModelsFallback;
  }
});

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Tokens — dynamic per role
  final Map<String, TextEditingController> _tokenInicialesCtrl = {};
  final Map<String, TextEditingController> _tokenRecargaCtrl = {};

  // General
  final _announcementExpiryCtrl = TextEditingController();
  final _antelacionDiasCtrl = TextEditingController();

  // Vivi
  String _geminiModel = 'gemini-2.5-flash-lite';

  // Switches
  bool _reservasHabilitadas = true;
  bool _iaHabilitada = true;
  bool _firebaseHabilitado = true;

  String _nonWorkingDaysJson = '{"dates":[],"months":[]}';

  // Carga los roles y rellena los controladores con los datos actuales
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rolesProvider.notifier).loadRoles();
      _loadDataIntoControllers();
    });
  }

  @override
  void dispose() {
    for (final c in _tokenInicialesCtrl.values) c.dispose();
    for (final c in _tokenRecargaCtrl.values) c.dispose();
    _announcementExpiryCtrl.dispose();
    _antelacionDiasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);

    ref.listen<AdminSettingsState>(adminSettingsProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false && next.data.isNotEmpty) {
        _loadDataIntoControllers();
      }
    });
    ref.listen<RolesState>(rolesProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading && next.mappings.isNotEmpty) {
        _loadDataIntoControllers();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading && state.data.isEmpty
            ? const _AdminSettingsSkeleton()
            : state.error != null && state.data.isEmpty
            ? Center(child: RvApiErrorState(onRetry: () => ref.read(adminSettingsProvider.notifier).loadSettings()))
            : Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(title: context.tr('admin.settings.section.reservas'), icon: Icons.event_available_rounded),
                      const SizedBox(height: 10),
                      _buildReservasSection(),
                      const SizedBox(height: 10),
                      _buildTokensSection(),
                      const SizedBox(height: 10),
                      AdminNonWorkingDaysSection(
                        initialJson: _nonWorkingDaysJson,
                        onChanged: (json) => setState(() => _nonWorkingDaysJson = json),
                      ),
                      const SizedBox(height: 10),
                      const AdminTramosSection(),

                      const SizedBox(height: 24),
                      _SectionHeader(title: context.tr('admin.settings.section.vivi'), icon: Icons.auto_awesome_rounded),
                      const SizedBox(height: 10),
                      _buildViviSection(),

                      const SizedBox(height: 24),
                      _SectionHeader(title: context.tr('admin.settings.section.firebase'), icon: Icons.notifications_rounded),
                      const SizedBox(height: 10),
                      _buildFirebaseSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cabecera con título, botón de refresco y botón de guardar
  Widget _buildHeader(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);
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
                  context.tr('admin.settings.eyebrow').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('admin.settings.title'),
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
            onTap: () => ref.read(adminSettingsProvider.notifier).loadSettings(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: state.isLoading ? null : _saveSettings,
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

  // Sección de reservas: interruptor de habilitación, caducidad de anuncios y antelación máxima
  Widget _buildReservasSection() {
    return _card(
      title: context.tr('admin.settings.section.reservas'),
      icon: Icons.event_available_rounded,
      child: Column(
        children: [
          _switchRow(
            value: _reservasHabilitadas,
            onChanged: (v) => setState(() => _reservasHabilitadas = v),
            title: context.tr('admin.settings.reserves.allowed'),
            subtitle: context.tr('admin.settings.reserves.allowed.subtitle'),
            icon: Icons.calendar_month_rounded,
          ),
          const Divider(height: 20),
          _numberField(
            controller: _announcementExpiryCtrl,
            label: context.tr('admin.settings.announcements.expiry'),
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _antelacionDiasCtrl,
            label: context.tr('admin.settings.branding.antelacionDias'),
            icon: Icons.event_note_rounded,
          ),
        ],
      ),
    );
  }

  static const _rolesWithUnlimitedTokens = {'ADMINISTRADOR', 'JEFATURA'};

  // Sección de tokens: muestra campos de tokens iniciales y de recarga mensual por rol
  Widget _buildTokensSection() {
    final rolesState = ref.watch(rolesProvider);
    final allRoles = rolesState.mappings.map((m) => m.roleName).toList();
    final roles = allRoles
        .where((r) => !_rolesWithUnlimitedTokens.contains(r.toUpperCase()))
        .toList();

    if (rolesState.isLoading && roles.isEmpty) {
      return _card(
        title: context.tr('admin.settings.section.tokens'),
        icon: Icons.stars_rounded,
        child: const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return _card(
      title: context.tr('admin.settings.section.tokens'),
      icon: Icons.stars_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            Text(
              roles[i],
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            _numberField(
              controller: _tokenInicialesCtrl.putIfAbsent(roles[i], () => TextEditingController(text: '20')),
              label: context.tr('admin.settings.tokens.role.initial'),
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 8),
            _numberField(
              controller: _tokenRecargaCtrl.putIfAbsent(roles[i], () => TextEditingController(text: '20')),
              label: context.tr('admin.settings.tokens.role.monthly'),
              icon: Icons.autorenew_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // Sección del asistente IA: interruptor de habilitación y selector del modelo Gemini
  Widget _buildViviSection() {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(geminiModelsProvider);

    final isLoadingModels = modelsAsync is AsyncLoading;
    final hasModelError = modelsAsync is AsyncError;
    final models = modelsAsync.maybeWhen(data: (v) => v, orElse: () => _kGeminiModelsFallback);
    final effectiveModel = models.contains(_geminiModel) ? _geminiModel : models.first;

    return _card(
      title: context.tr('admin.settings.section.vivi'),
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _switchRow(
            value: _iaHabilitada,
            onChanged: (v) => setState(() => _iaHabilitada = v),
            title: context.tr('admin.settings.ia.enabled'),
            subtitle: context.tr('admin.settings.ia.enabled.subtitle'),
            icon: Icons.smart_toy_rounded,
          ),
          const Divider(height: 20),
          DropdownButtonFormField<String>(
            initialValue: effectiveModel,
            decoration: InputDecoration(
              labelText: context.tr('admin.settings.vivi.model'),
              prefixIcon: isLoadingModels
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
                  : Icon(
                hasModelError ? Icons.wifi_off_rounded : Icons.psychology_rounded,
                size: 18,
                color: hasModelError ? theme.colorScheme.error : null,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: theme.dividerColor.withValues(alpha: 0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              helperText: hasModelError
                  ? 'Sin conexión con Google AI — mostrando lista local'
                  : !isLoadingModels
                  ? '${models.length} modelos disponibles en tu cuenta'
                  : null,
              helperStyle: TextStyle(
                fontSize: 11,
                color: hasModelError ? theme.colorScheme.error : theme.colorScheme.outline,
              ),
            ),
            items: models
                .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => _geminiModel = v ?? _geminiModel),
          ),
        ],
      ),
    );
  }

  // Sección de notificaciones push: interruptor para habilitar o deshabilitar Firebase
  Widget _buildFirebaseSection() {
    return _card(
      title: context.tr('admin.settings.section.firebase'),
      icon: Icons.notifications_active_rounded,
      child: _switchRow(
        value: _firebaseHabilitado,
        onChanged: (v) => setState(() => _firebaseHabilitado = v),
        title: context.tr('admin.settings.firebase.enabled'),
        subtitle: context.tr('admin.settings.firebase.enabled.subtitle'),
        icon: Icons.phone_android_rounded,
      ),
    );
  }

  // Tarjeta de sección con icono, título y contenido variable
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

  // Fila con icono, título, subtítulo opcional y switch adaptativo
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
          activeThumbColor: cs.primary,
        ),
      ],
    );
  }

  // Campo numérico con validación de entero mínimo
  Widget _numberField({required TextEditingController controller, required String label, required IconData icon, int min = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) {
        final raw = v?.trim() ?? '';
        if (raw.isEmpty) return context.tr('validation.required');
        final n = int.tryParse(raw);
        if (n == null) return context.tr('validation.mustBeInt');
        if (n < min) return context.tr('validation.minValue').replaceAll('{n}', '$min');
        return null;
      },
    );
  }



  // Vuelca los datos del provider en los controladores de texto del formulario
  void _loadDataIntoControllers() {
    final state = ref.read(adminSettingsProvider);
    if (state.isLoading || state.data.isEmpty) return;
    final d = state.data;

    final roles = ref.read(rolesProvider).mappings.map((m) => m.roleName).toList();
    for (final role in roles) {
      final key = role.toLowerCase();
      _tokenInicialesCtrl.putIfAbsent(role, () => TextEditingController()).text =
          d['tokens_iniciales_$key'] ?? '20';
      _tokenRecargaCtrl.putIfAbsent(role, () => TextEditingController()).text =
          d['tokens_recarga_mensual_$key'] ?? '20';
    }

    _announcementExpiryCtrl.text = d['dias_caducidad_anuncio_defecto'] ?? '30';
    _antelacionDiasCtrl.text = d['antelacion_dias_defecto'] ?? '7';
    final model = d['gemini_model'] ?? 'gemini-2.5-flash-lite';
    setState(() {
      _reservasHabilitadas = d['se_permiten_reservas']?.toLowerCase() != 'false';
      _iaHabilitada = d['ia_habilitada']?.toLowerCase() != 'false';
      _firebaseHabilitado = d['firebase_habilitado']?.toLowerCase() != 'false';
      _geminiModel = model;
      _nonWorkingDaysJson = d['dias_no_laborables'] ?? '{"dates":[],"months":[]}';
    });
  }

  // Valida el formulario y guarda la configuración en el servidor
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = <String, String>{
      'se_permiten_reservas': _reservasHabilitadas.toString(),
      'ia_habilitada': _iaHabilitada.toString(),
      'dias_caducidad_anuncio_defecto': _announcementExpiryCtrl.text.trim(),
      'antelacion_dias_defecto': _antelacionDiasCtrl.text.trim(),
      'dias_no_laborables': _nonWorkingDaysJson,
      'firebase_habilitado': _firebaseHabilitado.toString(),
      'gemini_model': _geminiModel,
    };
    for (final entry in _tokenInicialesCtrl.entries) {
      settings['tokens_iniciales_${entry.key.toLowerCase()}'] = entry.value.text.trim();
    }
    for (final entry in _tokenRecargaCtrl.entries) {
      settings['tokens_recarga_mensual_${entry.key.toLowerCase()}'] = entry.value.text.trim();
    }
    final success = await ref.read(adminSettingsProvider.notifier).updateSettings(settings);
    if (mounted && success) {
      ref.invalidate(serviciosInstitutoProvider);
      ref.invalidate(espaciosProvider);
      ref.invalidate(espacioDetalleProvider);
      RvAlerts.success(context, context.tr('admin.settings.saved'));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

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

class _AdminSettingsSkeleton extends StatelessWidget {
  const _AdminSettingsSkeleton();

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
          for (int i = 0; i < 4; i++) ...[
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
