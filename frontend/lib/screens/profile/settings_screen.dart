import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/l10n/app_localizations.dart';
import 'package:reservives/providers/locale_provider.dart';
import 'package:reservives/widgets/design_system.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.translate('settings.title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 20),
                    children: [
                      _SettingsItem(
                        icon: Icons.language_rounded,
                        title: loc.translate('settings.language.title'),
                        subtitle: locale.languageCode == 'es'
                            ? loc.translate('settings.language.spanish')
                            : loc.translate('settings.language.english'),
                        color: AppColors.primaryBlue,
                        onTap: () {
                          if (isWeb) {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: _LanguageContent(
                                    currentLocale: locale,
                                    onLocaleSelected: (newLocale) async {
                                      await ref.read(localeProvider.notifier).setLocale(newLocale);
                                    },
                                  ),
                                ),
                              ),
                            );
                          } else {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _LanguageBottomSheet(
                                currentLocale: locale,
                                onLocaleSelected: (newLocale) async {
                                  await ref.read(localeProvider.notifier).setLocale(newLocale);
                                },
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _SettingsItem(
                        icon: Icons.history_rounded,
                        title: loc.translate('settings.history.title'),
                        subtitle: loc.translate('settings.history.subtitle'),
                        color: AppColors.primaryBlue,
                        onTap: () => context.pushNamed('actividad'),
                      ),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.translate('settings.language.dialogTitle'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _LanguageOption(
            label: loc.translate('settings.language.spanish'),
            isSelected: currentLocale.languageCode == 'es',
            onTap: () {
              onLocaleSelected(const Locale('es'));
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          _LanguageOption(
            label: loc.translate('settings.language.english'),
            isSelected: currentLocale.languageCode == 'en',
            onTap: () {
              onLocaleSelected(const Locale('en'));
              Navigator.pop(context);
            },
          ),
        ],
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPadding + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _LanguageContent(
            currentLocale: currentLocale,
            onLocaleSelected: onLocaleSelected,
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            width: 1.5,
          ),
          color: isSelected
              ? AppColors.primaryBlue.withOpacity(0.05)
              : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primaryBlue : null,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22)
            else
              Icon(Icons.circle_outlined, color: Theme.of(context).dividerColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsItem({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: AppShadows.soft(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.m),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).dividerColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}