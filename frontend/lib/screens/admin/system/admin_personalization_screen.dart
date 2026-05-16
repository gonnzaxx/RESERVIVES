import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_settings_provider.dart';
import 'package:reservives/providers/branding_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

class AdminPersonalizationScreen extends ConsumerStatefulWidget {
  const AdminPersonalizationScreen({super.key});

  @override
  ConsumerState<AdminPersonalizationScreen> createState() =>
      _AdminPersonalizationScreenState();
}

class _AdminPersonalizationScreenState
    extends ConsumerState<AdminPersonalizationScreen> {
  final _appNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _uploadingLogo = false;
  String _selectedColor = '#B53F7A';

  static const _colorPalette = [
    (label: 'Fucsia', shades: [
      (name: 'Rosa', hex: '#EC64B3'),
      (name: 'Fucsia', hex: '#B53F7A'),
      (name: 'Vino', hex: '#7A1C4A'),
    ]),
    (label: 'Rojo', shades: [
      (name: 'Coral', hex: '#FB7185'),
      (name: 'Rojo', hex: '#E11D48'),
      (name: 'Granate', hex: '#9F1239'),
    ]),
    (label: 'Naranja', shades: [
      (name: 'Melocotón', hex: '#FB923C'),
      (name: 'Naranja', hex: '#EA580C'),
      (name: 'Terracota', hex: '#9A3412'),
    ]),
    (label: 'Ámbar', shades: [
      (name: 'Dorado', hex: '#FCD34D'),
      (name: 'Ámbar', hex: '#D97706'),
      (name: 'Miel', hex: '#92400E'),
    ]),
    (label: 'Lima', shades: [
      (name: 'Lima', hex: '#A3E635'),
      (name: 'Verde', hex: '#65A30D'),
      (name: 'Bosque', hex: '#3F6212'),
    ]),
    (label: 'Esmeralda', shades: [
      (name: 'Menta', hex: '#34D399'),
      (name: 'Esmeralda', hex: '#059669'),
      (name: 'Pino', hex: '#065F46'),
    ]),
    (label: 'Cian', shades: [
      (name: 'Cian', hex: '#22D3EE'),
      (name: 'Pavo real', hex: '#0891B2'),
      (name: 'Marino', hex: '#164E63'),
    ]),
    (label: 'Azul', shades: [
      (name: 'Celeste', hex: '#60A5FA'),
      (name: 'Azul', hex: '#2563EB'),
      (name: 'Marino', hex: '#1E3A8A'),
    ]),
    (label: 'Índigo', shades: [
      (name: 'Lavanda', hex: '#818CF8'),
      (name: 'Índigo', hex: '#4F46E5'),
      (name: 'Real', hex: '#312E81'),
    ]),
    (label: 'Violeta', shades: [
      (name: 'Lila', hex: '#C084FC'),
      (name: 'Violeta', hex: '#7C3AED'),
      (name: 'Uva', hex: '#4C1D95'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _appNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final state = ref.read(adminSettingsProvider);
    if (state.isLoading || state.data.isEmpty) return;
    _appNameCtrl.text = state.data['app_name'] ?? 'IES Luis Vives App';
    _contactEmailCtrl.text = state.data['app_contact_email'] ?? 'secretaria@iesluisvives.es';
    _contactPhoneCtrl.text = state.data['app_contact_phone'] ?? '916 80 77 12';
    _addressCtrl.text = state.data['app_address'] ?? 'Paseo de la Ermita, 15\nLeganés (Madrid)';
    setState(() => _selectedColor = state.data['app_primary_color'] ?? '#B53F7A');
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFFB53F7A);
    }
  }

  Future<void> _pickAndUploadLogo(String variant) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final bytes = await picked.readAsBytes();
      final client = ref.read(apiClientProvider);
      await client.postMultipart(
        '/admin/configuracion/logo?variant=$variant',
        fileField: 'file',
        fileBytes: bytes,
        fileName: picked.name,
      );
      ref.invalidate(brandingProvider);
      if (mounted) RvAlerts.success(context, context.tr('admin.settings.logo.uploaded'));
    } catch (_) {
      if (mounted) RvAlerts.error(context, context.tr('admin.settings.logo.uploadError'));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    final settings = <String, String>{};
    if (_appNameCtrl.text.trim().isNotEmpty) settings['app_name'] = _appNameCtrl.text.trim();
    if (_contactEmailCtrl.text.trim().isNotEmpty) settings['app_contact_email'] = _contactEmailCtrl.text.trim();
    if (_contactPhoneCtrl.text.trim().isNotEmpty) settings['app_contact_phone'] = _contactPhoneCtrl.text.trim();
    if (_addressCtrl.text.trim().isNotEmpty) settings['app_address'] = _addressCtrl.text.trim();
    settings['app_primary_color'] = _selectedColor;

    final success = await ref.read(adminSettingsProvider.notifier).updateSettings(settings);
    if (mounted && success) {
      ref.invalidate(brandingProvider);
      RvAlerts.success(context, context.tr('admin.personalization.saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<AdminSettingsState>(adminSettingsProvider, (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false && next.data.isNotEmpty) {
        _loadData();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: state.isLoading && state.data.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 820;
                    return wide
                        ? _buildWideLayout(isDark)
                        : _buildMobileLayout(isDark);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = ref.watch(adminSettingsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('admin.personalization.eyebrow').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('admin.personalization.title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RvGhostIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => ref.read(adminSettingsProvider.notifier).loadSettings(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: state.isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: state.isLoading
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLogoSection(isDark)),
        const SizedBox(width: 10),
        Expanded(child: _buildIdentitySection(isDark)),
        const SizedBox(width: 10),
        Expanded(child: _buildColorSection(isDark)),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogoSection(isDark),
        const SizedBox(height: 10),
        _buildIdentitySection(isDark),
        const SizedBox(height: 10),
        _buildColorSection(isDark),
      ],
    );
  }

  Widget _buildLogoSection(bool isDark) {
    final branding = ref.watch(brandingProvider);
    return _section(
      title: context.tr('admin.settings.section.branding'),
      icon: Icons.image_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('admin.personalization.logos.hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LogoUploadCard(
                label: context.tr('admin.settings.logo.light'),
                variant: 'light',
                currentUrl: branding.logoLightUrl,
                isUploading: _uploadingLogo,
                onUpload: () => _pickAndUploadLogo('light'),
              ),
              const SizedBox(width: 12),
              _LogoUploadCard(
                label: context.tr('admin.settings.logo.dark'),
                variant: 'dark',
                currentUrl: branding.logoDarkUrl,
                isUploading: _uploadingLogo,
                onUpload: () => _pickAndUploadLogo('dark'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection(bool isDark) {
    return _section(
      title: context.tr('admin.personalization.identity.title'),
      icon: Icons.badge_rounded,
      child: Column(
        children: [
          _textField(controller: _appNameCtrl, label: context.tr('admin.settings.branding.appName'), icon: Icons.apps_rounded),
          const SizedBox(height: 12),
          _textField(controller: _contactEmailCtrl, label: context.tr('admin.settings.branding.contactEmail'), icon: Icons.email_rounded),
          const SizedBox(height: 12),
          _textField(controller: _contactPhoneCtrl, label: context.tr('admin.settings.branding.contactPhone'), icon: Icons.phone_rounded),
          const SizedBox(height: 12),
          _textField(controller: _addressCtrl, label: context.tr('admin.settings.branding.address'), icon: Icons.location_on_rounded, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildColorSection(bool isDark) {
    final theme = Theme.of(context);
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return _section(
      title: context.tr('admin.settings.section.appearance'),
      icon: Icons.color_lens_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('admin.settings.appearance.color'),
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: secondaryText),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final cols = (constraints.maxWidth / 110).floor().clamp(2, 10);
            return Wrap(
              spacing: 8,
              runSpacing: 16,
              children: _colorPalette.map((family) {
                final itemWidth = (constraints.maxWidth - (cols - 1) * 8) / cols;
                return SizedBox(
                  width: itemWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: secondaryText,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: family.shades.map((shade) {
                          final color = _hexToColor(shade.hex);
                          final isSelected = _selectedColor.toUpperCase() == shade.hex.toUpperCase();
                          return Tooltip(
                            message: shade.name,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedColor = shade.hex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : Colors.transparent,
                                    width: isSelected ? 2.5 : 0,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1)]
                                      : [],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return RvSurfaceCard(
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
    );
  }
}

class _LogoUploadCard extends StatefulWidget {
  final String label;
  final String variant;
  final String? currentUrl;
  final bool isUploading;
  final VoidCallback onUpload;

  const _LogoUploadCard({
    required this.label,
    required this.variant,
    this.currentUrl,
    required this.isUploading,
    required this.onUpload,
  });

  @override
  State<_LogoUploadCard> createState() => _LogoUploadCardState();
}

class _LogoUploadCardState extends State<_LogoUploadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.isUploading ? null : widget.onUpload,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 120,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: _hovered ? 0.06 : 0.03)
                  : Colors.black.withValues(alpha: _hovered ? 0.04 : 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.4)
                    : (isDark ? Colors.white12 : Colors.black12),
                width: 1.5,
                style: widget.currentUrl == null ? BorderStyle.none : BorderStyle.solid,
              ),
            ),
            child: widget.isUploading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.currentUrl != null)
                  Image.network(
                    AppConstants.resolveApiUrl(widget.currentUrl!),
                    height: 52,
                    errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, size: 36, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  )
                else
                  Icon(Icons.add_photo_alternate_rounded, size: 36, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
