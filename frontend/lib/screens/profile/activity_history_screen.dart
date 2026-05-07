import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/core/utils/datetime_utils.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/core/utils/calendar_utils.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final historyAsync = ref.watch(activityHistoryProvider);
    final isWeb = MediaQuery.of(context).size.width > 700;

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
                              context.tr('profile.accountEyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('activity.title'),
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
                  child: historyAsync.when(
                    data: (history) {
                      if (history.isEmpty) {
                        return Center(
                          child: RvEmptyState(
                            icon: Icons.history_toggle_off_rounded,
                            title: context.tr('activity.emptyTitle'),
                            subtitle: context.tr('activity.emptySubtitle'),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            20, isWeb ? 8 : 4, 20, 48),
                        itemCount: history.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final isServicio =
                              item.tipoEspacio == 'SERVICIO';

                          final String displayStatus;
                          final Color statusColor;
                          if (item.isAprobada && item.isPasada) {
                            displayStatus = context
                                .tr('activity.status.finished')
                                .toUpperCase();
                            statusColor = AppColors.lightTextSecondary;
                          } else {
                            displayStatus = item.estado.value;
                            statusColor =
                                _statusColor(item.estado.value);
                          }

                          return _ActivityCard(
                            item: item,
                            isServicio: isServicio,
                            displayStatus: displayStatus,
                            statusColor: statusColor,
                            isDark: isDark,
                            theme: theme,
                            onCancel: () => _handleCancel(
                                context, ref, item, isServicio),
                            onAddToCalendar: () =>
                                CalendarUtils.addToCalendar(
                                  title: item.nombreEspacio ?? 'Reserva',
                                  startTime: item.fechaInicio,
                                  endTime: item.fechaFin,
                                  location: 'IES Luis Vives',
                                  details:
                                  'Reserva gestionada por RESERVIVES. ${item.observaciones ?? ""}',
                                ),
                          )
                              .animate()
                              .fadeIn(
                            delay: Duration(
                                milliseconds: 40 * index),
                            duration: 300.ms,
                          )
                              .slideY(
                            begin: 0.04,
                            delay: Duration(
                                milliseconds: 40 * index),
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          );
                        },
                      );
                    },
                    loading: () => _ActivitySkeleton(isWeb: isWeb),
                    error: (_, __) => Center(
                      child: RvApiErrorState(
                        onRetry: () =>
                            ref.invalidate(activityHistoryProvider),
                      ),
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

  Future<void> _handleCancel(
      BuildContext context,
      WidgetRef ref,
      dynamic item,
      bool isServicio,
      ) async {
    final confirm = await RvAlerts.confirm(
      context,
      title: context.tr('activity.cancelDialog.title'),
      content: context.tr('activity.cancelDialog.subtitle'),
      confirmLabel: context.tr('activity.cancelDialog.confirm'),
      cancelLabel: context.tr('activity.cancelDialog.keep'),
      isDestructive: true,
    );
    if (confirm != true || !context.mounted) return;

    final success = isServicio
        ? await ref
        .read(reservarServicioProvider.notifier)
        .cancelarReservaServicio(item.id)
        : await ref
        .read(crearReservaProvider.notifier)
        .cancelarReserva(item.id);

    if (!context.mounted) return;
    if (success) {
      await RvAlerts.dialog(
        context,
        title: 'Reserva cancelada',
        content: context.tr('activity.cancelDialog.successMessage'),
      );
    } else {
      final error = isServicio
          ? ref.read(reservarServicioProvider).error
          : ref.read(crearReservaProvider).error;
      RvAlerts.error(
        context,
        toFriendlyErrorMessage(
            error, fallback: context.tr('booking.error')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APROBADA':
        return AppColors.success;
      case 'RECHAZADA':
      case 'CANCELADA':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }
}

class _ActivityCard extends StatefulWidget {
  final dynamic item;
  final bool isServicio;
  final String displayStatus;
  final Color statusColor;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onCancel;
  final VoidCallback onAddToCalendar;

  const _ActivityCard({
    required this.item,
    required this.isServicio,
    required this.displayStatus,
    required this.statusColor,
    required this.isDark,
    required this.theme,
    required this.onCancel,
    required this.onAddToCalendar,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(
            color: _hovered
                ? primary.withValues(alpha: 0.22)
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05)),
            width: 1.5,
          ),
          boxShadow: _hovered
              ? AppShadows.deep(context)
              : AppShadows.soft(context),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RvBadge(
                        label: widget.isServicio
                            ? context.tr('activity.badge.service')
                            : (widget.item.tipoEspacio ??
                            context.tr('activity.badge.space')),
                        color: widget.isServicio
                            ? AppColors.accentPurple
                            : AppColors.accentBlue,
                        icon: widget.isServicio
                            ? Icons.build_circle_rounded
                            : Icons.place_rounded,
                      ),
                      const Spacer(),
                      _StatusPill(
                        label: widget.displayStatus,
                        color: widget.statusColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    widget.item.nombreEspacio ??
                        context.tr('activity.defaultReservation'),
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatRelativeDate(
                            widget.item.fechaInicio, context),
                        style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (widget.item.isActiva) ...[
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: widget.theme.dividerColor.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  children: [
                    _CancelButton(
                      label: context.tr('activity.cancelBooking'),
                      onTap: widget.onCancel,
                    ),
                    if (widget.item.isAprobada) ...[
                      const Spacer(),
                      _CalendarButton(
                        label: context.tr('activity.addToCalendar'),
                        onTap: widget.onAddToCalendar,
                        primary: primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CancelButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _CancelButton({required this.label, required this.onTap});

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color primary;

  const _CalendarButton({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_CalendarButton> createState() => _CalendarButtonState();
}

class _CalendarButtonState extends State<_CalendarButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.primary.withValues(alpha: 0.14)
                  : widget.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: widget.primary.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_calendar_rounded,
                    size: 15, color: widget.primary),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

class _ActivitySkeleton extends StatelessWidget {
  final bool isWeb;
  const _ActivitySkeleton({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding:
      EdgeInsets.fromLTRB(20, isWeb ? 8 : 4, 20, 48),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(18),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                RvSkeleton(width: 90, height: 22, borderRadius: 100),
                RvSkeleton(width: 70, height: 22, borderRadius: 100),
              ],
            ),
            const SizedBox(height: 14),
            const RvSkeleton(
                width: double.infinity, height: 18, borderRadius: 6),
            const SizedBox(height: 8),
            const RvSkeleton(width: 140, height: 14, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}