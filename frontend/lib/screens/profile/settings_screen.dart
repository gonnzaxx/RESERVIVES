import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/locale_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final isGuest = ref.watch(authProvider).isGuest;
    final isWeb = AppConstants.isWideScreen(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentLangLabel = locale.languageCode == 'es'
        ? loc.translate('settings.language.spanish')
        : locale.languageCode == 'fr'
        ? loc.translate('settings.language.french')
        : loc.translate('settings.language.english');

    void showLanguagePicker() {
      if (isWeb) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _LanguageContent(
                currentLocale: locale,
                onLocaleSelected: (l) async =>
                    ref.read(localeProvider.notifier).setLocale(l),
              ),
            ),
          ),
        );
      } else {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _LanguageBottomSheet(
            currentLocale: locale,
            onLocaleSelected: (l) async =>
                ref.read(localeProvider.notifier).setLocale(l),
          ),
        );
      }
    }

    final sections = [
      _Section(items: [
        _ItemData(
          icon: Icons.language_rounded,
          color: AppColors.accentBlue,
          title: loc.translate('settings.language.title'),
          subtitle: currentLangLabel,
          onTap: showLanguagePicker,
        ),
      ]),
      if (!isGuest)
        _Section(items: [
          _ItemData(
            icon: Icons.history_rounded,
            color: AppColors.accentPurple,
            title: loc.translate('settings.history.title'),
            subtitle: loc.translate('settings.history.subtitle'),
            onTap: () => context.pushNamed('actividad'),
          ),
          _ItemData(
            icon: Icons.notifications_active_rounded,
            color: AppColors.warning,
            title: loc.translate('settings.notification_prefs.title'),
            subtitle: loc.translate('settings.notification_prefs.subtitle'),
            onTap: () => context.pushNamed('preferencias'),
          ),
        ]),
      _Section(items: [
        _ItemData(
          icon: Icons.info_outline_rounded,
          color: AppColors.primaryBlue,
          title: loc.translate('settings.about.title'),
          subtitle: loc.translate('settings.about.subtitle'),
          onTap: () => context.pushNamed('acerca_de'),
        ),
        _ItemData(
          icon: Icons.question_answer_rounded,
          color: const Color(0xFF607D8B),
          title: loc.translate('settings.faq.title'),
          subtitle: loc.translate('settings.faq.subtitle'),
          onTap: () => context.pushNamed('faq'),
        ),
        _ItemData(
          icon: Icons.help_outline_rounded,
          color: AppColors.success,
          title: loc.translate('settings.help.title'),
          subtitle: loc.translate('settings.help.subtitle'),
          onTap: () => context.pushNamed('ayuda'),
        ),
      ]),
      if (!isGuest)
        _Section(items: [
          _ItemData(
            icon: Icons.report_problem_rounded,
            color: AppColors.error,
            title: loc.translate('settings.incidents.title'),
            subtitle: loc.translate('settings.incidents.subtitle'),
            onTap: () => context.pushNamed('reportar_incidencia'),
          ),
        ]),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      8, 12, 20, isWeb ? 20 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.translate('profile.accountEyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.translate('settings.title'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 8 : 4, 20, 48),
                    children: [
                      for (int i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        _SectionCard(
                          section: sections[i],
                          isDark: isDark,
                          theme: theme,
                          animDelay: Duration(milliseconds: 60 * (i + 1)),
                        ),
                      ],
                    ],
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

class _Section {
  final List<_ItemData> items;
  const _Section({required this.items});
}

class _ItemData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}


class _SectionCard extends StatelessWidget {
  final _Section section;
  final bool isDark;
  final ThemeData theme;
  final Duration animDelay;

  const _SectionCard({
    required this.section,
    required this.isDark,
    required this.theme,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.l),
        child: Column(
          children: [
            for (int i = 0; i < section.items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              _SettingsTile(
                item: section.items[i],
                isDark: isDark,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animDelay, duration: 300.ms)
        .slideY(
      begin: 0.04,
      delay: animDelay,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final _ItemData item;
  final bool isDark;
  final ThemeData theme;

  const _SettingsTile({
    required this.item,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.item.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item.icon,
                  color: widget.item.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.subtitle,
                      style: widget.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: widget.theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageContent extends StatelessWidget {
  final Locale currentLocale;
  final Function(Locale) onLocaleSelected;

  const _LanguageContent({
    required this.currentLocale,
    required this.onLocaleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final langs = [
      (code: 'es', label: loc.translate('settings.language.spanish')),
      (code: 'en', label: loc.translate('settings.language.english')),
      (code: 'fr', label: loc.translate('settings.language.french')),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.translate('settings.language.dialogTitle'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          ...langs.map((lang) {
            final isSelected = currentLocale.languageCode == lang.code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LanguageOption(
                label: lang.label,
                isSelected: isSelected,
                isDark: isDark,
                theme: theme,
                onTap: () {
                  onLocaleSelected(Locale(lang.code));
                  Navigator.pop(context);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_LanguageOption> createState() => _LanguageOptionState();
}

class _LanguageOptionState extends State<_LanguageOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primary.withValues(alpha: 0.08)
                : (_hovered
                ? (widget.isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02))
                : (widget.isDark
                ? AppColors.darkCard
                : Colors.white)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? primary.withValues(alpha: 0.35)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: widget.theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: widget.isSelected ? primary : null,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.isSelected
                    ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey('check'),
                    color: primary,
                    size: 22)
                    : Icon(Icons.circle_outlined,
                    key: const ValueKey('empty'),
                    color: widget.theme.hintColor,
                    size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageBottomSheet extends StatelessWidget {
  final Locale currentLocale;
  final Function(Locale) onLocaleSelected;

  const _LanguageBottomSheet({
    required this.currentLocale,
    required this.onLocaleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RvSheetHeader(onClose: () => Navigator.pop(context)),
          _LanguageContent(
            currentLocale: currentLocale,
            onLocaleSelected: onLocaleSelected,
          ),
        ],
      ),
    );
  }
}