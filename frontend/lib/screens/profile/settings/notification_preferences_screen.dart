import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/notification_preferences.dart';
import 'package:reservives/providers/notification_preferences_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final isWeb = AppConstants.isWideScreen(context);

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
                  padding:
                  EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
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
                              loc.translate('notification_prefs.title'),
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 4 : 0, 20, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('notification_prefs.subtitle'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

                        const SizedBox(height: 24),

                        preferencesAsync.when(
                          loading: () => _PreferencesSkeleton(isDark: isDark),
                          error: (_, __) => Center(
                            child: RvApiErrorState(
                              onRetry: () => ref.invalidate(
                                  notificationPreferencesProvider),
                            ),
                          ),
                          data: (prefs) => Column(
                            children: [
                              _PreferencesSection(
                                title: loc.translate('pref.section.push'),
                                icon: Icons.notifications_rounded,
                                isDark: isDark,
                                theme: theme,
                                animDelay: 120.ms,
                                rows: [
                                  _RowData(
                                    icon: Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    title: loc.translate('pref.reservationApproved.title'),
                                    subtitle: loc.translate('pref.reservationApproved.subtitle'),
                                    value: prefs.reservaAprobada,
                                    onChanged: (v) => _update(ref, prefs.copyWith(reservaAprobada: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.cancel_rounded,
                                    color: AppColors.error,
                                    title: loc.translate('pref.reservationRejected.title'),
                                    subtitle: loc.translate('pref.reservationRejected.subtitle'),
                                    value: prefs.reservaRechazada,
                                    onChanged: (v) => _update(ref, prefs.copyWith(reservaRechazada: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.grid_view_rounded,
                                    color: AppColors.accentPurple,
                                    title: loc.translate('pref.newSpacesServices.title'),
                                    subtitle: loc.translate('pref.newSpacesServices.subtitle'),
                                    value: prefs.nuevoEspacio && prefs.nuevoServicio,
                                    onChanged: (v) => _update(ref, prefs.copyWith(nuevoEspacio: v, nuevoServicio: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.campaign_rounded,
                                    color: AppColors.warning,
                                    title: loc.translate('pref.announcements.title'),
                                    subtitle: loc.translate('pref.announcements.subtitle'),
                                    value: prefs.nuevoAnuncio,
                                    onChanged: (v) => _update(ref, prefs.copyWith(nuevoAnuncio: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.how_to_vote_rounded,
                                    color: AppColors.accentPurple,
                                    title: loc.translate('pref.newSurvey.title'),
                                    subtitle: loc.translate('pref.newSurvey.subtitle'),
                                    value: prefs.nuevaEncuesta,
                                    onChanged: (v) => _update(ref, prefs.copyWith(nuevaEncuesta: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.queue_rounded,
                                    color: AppColors.accentBlue,
                                    title: loc.translate('pref.waitlist.title'),
                                    subtitle: loc.translate('pref.waitlist.subtitle'),
                                    value: prefs.listaEspera,
                                    onChanged: (v) => _update(ref, prefs.copyWith(listaEspera: v)),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              _PreferencesSection(
                                title: loc.translate('pref.section.email'),
                                icon: Icons.mail_rounded,
                                isDark: isDark,
                                theme: theme,
                                animDelay: 200.ms,
                                rows: [
                                  _RowData(
                                    icon: Icons.mail_outline_rounded,
                                    color: AppColors.accentBlue,
                                    title: loc.translate('pref.emailReservations.title'),
                                    subtitle: loc.translate('pref.emailReservations.subtitle'),
                                    value: prefs.emailReservas,
                                    onChanged: (v) => _update(ref, prefs.copyWith(emailReservas: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.mark_email_read_rounded,
                                    color: AppColors.primaryBlue,
                                    title: loc.translate('pref.emailAnnouncements.title'),
                                    subtitle: loc.translate('pref.emailAnnouncements.subtitle'),
                                    value: prefs.emailAnuncios,
                                    onChanged: (v) => _update(ref, prefs.copyWith(emailAnuncios: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.report_problem_rounded,
                                    color: AppColors.warning,
                                    title: loc.translate('pref.emailIncidents.title'),
                                    subtitle: loc.translate('pref.emailIncidents.subtitle'),
                                    value: prefs.emailIncidencias,
                                    onChanged: (v) => _update(ref, prefs.copyWith(emailIncidencias: v)),
                                  ),
                                  _RowData(
                                    icon: Icons.toll_rounded,
                                    color: AppColors.success,
                                    title: loc.translate('pref.emailTokens.title'),
                                    subtitle: loc.translate('pref.emailTokens.subtitle'),
                                    value: prefs.emailTokens,
                                    onChanged: (v) => _update(ref, prefs.copyWith(emailTokens: v)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  Future<void> _update(
      WidgetRef ref, NotificationPreferences preferences) async {
    await ref
        .read(notificationPreferencesProvider.notifier)
        .savePreferences(preferences);
  }
}

class _RowData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RowData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
}

class _PreferencesSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final ThemeData theme;
  final Duration animDelay;
  final List<_RowData> rows;

  const _PreferencesSection({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.theme,
    required this.animDelay,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
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
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 68,
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  _PreferenceRow(row: rows[i], isDark: isDark, theme: theme),
                ],
              ],
            ),
          ),
        ),
      ],
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

class _PreferenceRow extends StatefulWidget {
  final _RowData row;
  final bool isDark;
  final ThemeData theme;

  const _PreferenceRow({
    required this.row,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_PreferenceRow> createState() => _PreferenceRowState();
}

class _PreferenceRowState extends State<_PreferenceRow> {
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
          widget.row.onChanged(!widget.row.value);
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
                  color: widget.row.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.row.icon,
                  color: widget.row.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.row.title,
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.row.subtitle,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: widget.row.value,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  widget.row.onChanged(v);
                },
                activeTrackColor: widget.row.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesSkeleton extends StatelessWidget {
  final bool isDark;
  const _PreferencesSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonSection(theme, isDark, 6),
        const SizedBox(height: 20),
        _skeletonSection(theme, isDark, 4),
      ],
    );
  }

  Widget _skeletonSection(ThemeData theme, bool isDark, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: RvSkeleton(width: 90, height: 12, borderRadius: 6),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.l),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: AppShadows.soft(
              // ignore: use_build_context_synchronously
                WidgetsBinding.instance.rootElement!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.l),
            child: Column(
              children: [
                for (int i = 0; i < count; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 68,
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  const _SkeletonRow(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          const RvSkeleton(width: 44, height: 24, borderRadius: 100),
        ],
      ),
    );
  }
}