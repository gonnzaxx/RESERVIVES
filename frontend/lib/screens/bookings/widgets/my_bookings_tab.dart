import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/core/utils/calendar_utils.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';

class ReservasTab extends ConsumerWidget {
  const ReservasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservasAsync = ref.watch(activityHistoryProvider);
    final dateFormat = DateFormat('dd MMM', 'es');
    final timeFormat = DateFormat('HH:mm');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(activityHistoryProvider),
      child: CustomScrollView(
        slivers: [
          reservasAsync.when(
            data: (reservas) {
              final reservasOrdenadas = reservas.toList()
                ..sort((a, b) {
                  final bool aFinalizada =
                      a.estado == EstadoReserva.cancelada ||
                          a.estado == EstadoReserva.rechazada ||
                          a.fechaInicio.isBefore(DateTime.now());
                  final bool bFinalizada =
                      b.estado == EstadoReserva.cancelada ||
                          b.estado == EstadoReserva.rechazada ||
                          b.fechaInicio.isBefore(DateTime.now());
                  if (aFinalizada != bFinalizada) return aFinalizada ? 1 : -1;
                  return a.fechaInicio.compareTo(b.fechaInicio);
                });

              if (reservasOrdenadas.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: RvEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: context.tr('services.bookings.emptyTitle'),
                      subtitle: context.tr('services.bookings.emptySubtitle'),
                      buttonLabel: context.tr('emptyState.bookNow'),
                      onButtonPressed: () => context.goNamed('espacios'),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReservaCard(
                        reserva: reservasOrdenadas[index],
                        dateFormat: dateFormat,
                        timeFormat: timeFormat,
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 40 * index),
                            duration: 300.ms,
                          )
                          .slideY(
                            begin: 0.05,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ),
                    childCount: reservasOrdenadas.length,
                  ),
                ),
              );
            },
            loading: () =>
                const SliverToBoxAdapter(child: LoadingSkeletonList()),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: RvApiErrorState(
                  onRetry: () => ref.invalidate(activityHistoryProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservaCard extends ConsumerStatefulWidget {
  final Reserva reserva;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  const _ReservaCard({
    required this.reserva,
    required this.dateFormat,
    required this.timeFormat,
  });

  @override
  ConsumerState<_ReservaCard> createState() => _ReservaCardState();
}

class _ReservaCardState extends ConsumerState<_ReservaCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _openDetail() {
    context.pushNamed(
      'reserva_detalle',
      pathParameters: {'reservaId': widget.reserva.id},
      queryParameters: {
        'tipo': (widget.reserva.tipoEspacio ?? '').toUpperCase(),
      },
      extra: widget.reserva,
    );
  }

  Future<void> _cancelar() async {
    final reserva = widget.reserva;

    final confirm = await RvAlerts.confirm(
      context,
      title: context.tr('activity.cancelBooking'),
      content: context.tr('activity.cancelBooking.text'),
      confirmLabel: context.tr('activity.cancelDialog.confirm'),
      cancelLabel: context.tr('activity.cancelDialog.text.back'),
      isDestructive: true,
    );
    if (confirm != true) return;

    final isServicio = reserva.tipoEspacio == 'SERVICIO';
    RvAlerts.info(context, context.tr('booking.canceling.alert'));

    final success = isServicio
        ? await ref
            .read(reservarServicioProvider.notifier)
            .cancelarReservaServicio(reserva.id)
        : await ref
            .read(crearReservaProvider.notifier)
            .cancelarReserva(reserva.id);

    if (!mounted) return;

    if (success) {
      RvAlerts.success(context, context.tr('activity.cancelDialog.successMessage'));
      return;
    }

    final error = isServicio
        ? ref.read(reservarServicioProvider).error
        : ref.read(crearReservaProvider).error;
    RvAlerts.error(context, toFriendlyErrorMessage(error));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reserva = widget.reserva;
    final isPast = reserva.isPasada;
    final statusColor = isPast && reserva.isActiva == false && !reserva.isCancelada && !reserva.isRechazada
        ? AppColors.lightTextSecondary
        : _statusColor(reserva.estado);
    final mostrarCancelar = !isPast &&
        (reserva.estado == EstadoReserva.pendiente ||
        reserva.estado == EstadoReserva.aprobada);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _openDetail();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.l),
              border: Border.all(
                color: _hovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.30)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05)),
                width: 1.5,
              ),
              boxShadow: _hovered
                  ? AppShadows.deep(context)
                  : AppShadows.soft(context),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusDot(color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TipoBadge(reserva: reserva),
                            const SizedBox(height: 8),
                            Text(
                              reserva.nombreEspacio ??
                                  context.tr('bookings.defaultName'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _InfoPills(
                              reserva: reserva,
                              dateFormat: widget.dateFormat,
                              timeFormat: widget.timeFormat,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      RvBadge(
                        label: isPast && !reserva.isCancelada && !reserva.isRechazada
                            ? context.tr('activity.status.finished')
                            : reserva.estado.value,
                        color: statusColor,
                        icon: isPast && !reserva.isCancelada && !reserva.isRechazada
                            ? Icons.check_circle_outline_rounded
                            : _statusIcon(reserva.estado),
                      ),
                    ],
                  ),

                  if (mostrarCancelar || (!isPast && reserva.estado == EstadoReserva.aprobada)) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (mostrarCancelar)
                          GestureDetector(
                            onTap: _cancelar,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                context.tr('activity.cancelBooking'),
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (!isPast && reserva.estado == EstadoReserva.aprobada)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              CalendarUtils.addToCalendar(
                                title: reserva.nombreEspacio ?? 'Reserva',
                                startTime: reserva.fechaInicio,
                                endTime: reserva.fechaFin,
                                location: 'IES Luis Vives',
                                details: 'Reserva gestionada por RESERVIVES.',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.18),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.tr('activity.addToCalendar'),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.aprobada:
        return AppColors.success;
      case EstadoReserva.pendiente:
        return AppColors.warning;
      case EstadoReserva.rechazada:
      case EstadoReserva.cancelada:
        return AppColors.error;
    }
  }

  IconData _statusIcon(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.aprobada:
        return Icons.check_circle_rounded;
      case EstadoReserva.pendiente:
        return Icons.schedule_rounded;
      case EstadoReserva.rechazada:
      case EstadoReserva.cancelada:
        return Icons.cancel_rounded;
    }
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}


class _TipoBadge extends StatelessWidget {
  final Reserva reserva;
  const _TipoBadge({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final isServicio = reserva.tipoEspacio == 'SERVICIO';
    return RvBadge(
      label: isServicio
          ? context.tr('services.type.service')
          : context.tr('spaces.type.court'),
      color: AppColors.accentPurple,
      icon: isServicio
          ? Icons.build_circle_rounded
          : Icons.meeting_room_rounded,
    );
  }
}


class _InfoPills extends StatelessWidget {
  final Reserva reserva;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final bool isDark;

  const _InfoPills({
    required this.reserva,
    required this.dateFormat,
    required this.timeFormat,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Pill(
          icon: Icons.calendar_today_rounded,
          text: dateFormat.format(reserva.fechaInicio),
          bg: pillBg,
          iconColor: AppColors.primaryBlue,
        ),
        _Pill(
          icon: Icons.access_time_rounded,
          text:
              '${timeFormat.format(reserva.fechaInicio)} – ${timeFormat.format(reserva.fechaFin)}',
          bg: pillBg,
          iconColor: AppColors.accentPurple,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color iconColor;

  const _Pill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
