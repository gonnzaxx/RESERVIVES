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
    final loc = AppLocalizations.of(context);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('notification_prefs.title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: isWeb ? null : 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              // En móvil reducimos el vertical a 4 para que pegue más arriba
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 40 : 20,
                  vertical: isWeb ? 12 : 4
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.translate('notification_prefs.subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  // Espacio dinámico: más pequeño en móvil
                  SizedBox(height: isWeb ? 24 : 16),
                  preferencesAsync.when(
                    loading: () => _NotificationPreferencesSkeleton(),
                    error: (error, _) => Center(
                      child: RvApiErrorState(onRetry: () => ref.invalidate(notificationPreferencesProvider)),
                    ),
                    data: (preferences) => Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppRadii.m),
                        boxShadow: AppShadows.soft(context),
                        border: isWeb ? Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)) : null,
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
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(reservaAprobada: value),
                              ),
                            ),
                            _divider(context),
                            _PreferenceRow(
                              icon: Icons.cancel_rounded,
                              title: loc.translate('pref.reservationRejected.title'),
                              subtitle: loc.translate('pref.reservationRejected.subtitle'),
                              value: preferences.reservaRechazada,
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(reservaRechazada: value),
                              ),
                            ),
                            _divider(context),
                            _PreferenceRow(
                              icon: Icons.grid_view_rounded,
                              title: loc.translate('pref.newSpacesServices.title'),
                              subtitle: loc.translate('pref.newSpacesServices.subtitle'),
                              value: preferences.nuevoEspacio && preferences.nuevoServicio,
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(
                                  nuevoEspacio: value,
                                  nuevoServicio: value,
                                ),
                              ),
                            ),
                            _divider(context),
                            _PreferenceRow(
                              icon: Icons.campaign_rounded,
                              title: loc.translate('pref.announcements.title'),
                              subtitle: loc.translate('pref.announcements.subtitle'),
                              value: preferences.nuevoAnuncio,
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(nuevoAnuncio: value),
                              ),
                            ),
                            _divider(context),
                            _PreferenceRow(
                              icon: Icons.mail_outline_rounded,
                              title: loc.translate('pref.emailReservations.title'),
                              subtitle: loc.translate('pref.emailReservations.subtitle'),
                              value: preferences.emailReservas,
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(emailReservas: value),
                              ),
                            ),
                            _divider(context),
                            _PreferenceRow(
                              icon: Icons.mark_email_read_rounded,
                              title: loc.translate('pref.emailAnnouncements.title'),
                              subtitle: loc.translate('pref.emailAnnouncements.subtitle'),
                              value: preferences.emailAnuncios,
                              onChanged: (value) => _update(
                                ref,
                                preferences.copyWith(emailAnuncios: value),
                              ),
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
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 56,
        color: Theme.of(context).dividerColor
    );
  }

  Future<void> _update(WidgetRef ref, NotificationPreferences preferences) async {
    await ref.read(notificationPreferencesProvider.notifier).savePreferences(preferences);
  }
}

class _NotificationPreferencesSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppRadii.m);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: borderRadius,
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          children: [
            _SkeletonPreferenceRow(),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: theme.dividerColor),
            _SkeletonPreferenceRow(),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: theme.dividerColor),
            _SkeletonPreferenceRow(),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: theme.dividerColor),
            _SkeletonPreferenceRow(),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: theme.dividerColor),
            _SkeletonPreferenceRow(),
            Divider(height: 0.5, thickness: 0.5, indent: 56, color: theme.dividerColor),
            _SkeletonPreferenceRow(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPreferenceRow extends StatelessWidget {
  const _SkeletonPreferenceRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const RvSkeleton(width: 20, height: 20, borderRadius: 6),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RvSkeleton(width: 180, height: 16, borderRadius: 8),
                const SizedBox(height: 6),
                RvSkeleton(
                  width: double.infinity,
                  height: 12,
                  borderRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const RvSkeleton(width: 52, height: 28, borderRadius: 20),
        ],
      ),
    );
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
    );
  }
}
