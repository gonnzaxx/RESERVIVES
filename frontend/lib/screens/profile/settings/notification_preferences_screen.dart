import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/notification_preferences.dart';
import 'package:reservives/providers/notification_preferences_provider.dart';
import 'package:reservives/widgets/design_system.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                // Encabezado personalizado
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
                          loc.translate('notification_prefs.title'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 20),
                          child: Text(
                            loc.translate('notification_prefs.subtitle'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),

                        preferencesAsync.when(
                          loading: () => const _NotificationPreferencesSkeleton(),
                          error: (error, _) => Center(
                            child: RvApiErrorState(
                              onRetry: () => ref.invalidate(notificationPreferencesProvider),
                            ),
                          ),
                          data: (preferences) => Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(AppRadii.m),
                              boxShadow: AppShadows.soft(context),
                              border: isWeb
                                  ? Border.all(color: theme.dividerColor.withValues(alpha: 0.05))
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.m),
                              child: Column(
                                children: [
                                  _PreferenceRow(
                                    icon: Icons.check_circle_rounded,
                                    title: loc.translate('pref.reservationApproved.title'),
                                    subtitle: loc.translate('pref.reservationApproved.subtitle'),
                                    value: preferences.reservaAprobada,
                                    onChanged: (value) => _update(ref, preferences.copyWith(reservaAprobada: value)),
                                  ),
                                  _divider(context),
                                  _PreferenceRow(
                                    icon: Icons.cancel_rounded,
                                    title: loc.translate('pref.reservationRejected.title'),
                                    subtitle: loc.translate('pref.reservationRejected.subtitle'),
                                    value: preferences.reservaRechazada,
                                    onChanged: (value) => _update(ref, preferences.copyWith(reservaRechazada: value)),
                                  ),
                                  _divider(context),
                                  _PreferenceRow(
                                    icon: Icons.grid_view_rounded,
                                    title: loc.translate('pref.newSpacesServices.title'),
                                    subtitle: loc.translate('pref.newSpacesServices.subtitle'),
                                    value: preferences.nuevoEspacio && preferences.nuevoServicio,
                                    onChanged: (value) => _update(ref, preferences.copyWith(nuevoEspacio: value, nuevoServicio: value)),
                                  ),
                                  _divider(context),
                                  _PreferenceRow(
                                    icon: Icons.campaign_rounded,
                                    title: loc.translate('pref.announcements.title'),
                                    subtitle: loc.translate('pref.announcements.subtitle'),
                                    value: preferences.nuevoAnuncio,
                                    onChanged: (value) => _update(ref, preferences.copyWith(nuevoAnuncio: value)),
                                  ),
                                  _divider(context),
                                  _PreferenceRow(
                                    icon: Icons.mail_outline_rounded,
                                    title: loc.translate('pref.emailReservations.title'),
                                    subtitle: loc.translate('pref.emailReservations.subtitle'),
                                    value: preferences.emailReservas,
                                    onChanged: (value) => _update(ref, preferences.copyWith(emailReservas: value)),
                                  ),
                                  _divider(context),
                                  _PreferenceRow(
                                    icon: Icons.mark_email_read_rounded,
                                    title: loc.translate('pref.emailAnnouncements.title'),
                                    subtitle: loc.translate('pref.emailAnnouncements.subtitle'),
                                    value: preferences.emailAnuncios,
                                    onChanged: (value) => _update(ref, preferences.copyWith(emailAnuncios: value)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 68,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
    );
  }

  Future<void> _update(WidgetRef ref, NotificationPreferences preferences) async {
    await ref.read(notificationPreferencesProvider.notifier).savePreferences(preferences);
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPreferencesSkeleton extends StatelessWidget {
  const _NotificationPreferencesSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
      ),
      child: Column(
        children: List.generate(11, (index) {
          if (index.isOdd) return Divider(height: 0.5, indent: 68, color: theme.dividerColor.withValues(alpha: 0.1));
          return const _SkeletonPreferenceRow();
        }),
      ),
    );
  }
}

class _SkeletonPreferenceRow extends StatelessWidget {
  const _SkeletonPreferenceRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const RvSkeleton(width: 40, height: 40, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                RvSkeleton(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                RvSkeleton(width: 200, height: 10, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const RvSkeleton(width: 40, height: 20, borderRadius: 20),
        ],
      ),
    );
  }
}