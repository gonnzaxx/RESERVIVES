import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/core/utils/datetime_utils.dart';
import 'package:reservives/l10n/app_localizations.dart';
import 'package:reservives/providers/reservas_provider.dart';
import 'package:reservives/providers/servicio_provider.dart';
import 'package:reservives/core/utils/calendar_utils.dart';
import 'package:reservives/widgets/design_system.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityHistoryProvider);
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
                          context.tr('activity.title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
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
                        padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 40),
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final isServicio = item.tipoEspacio == 'SERVICIO';

                          final String displayStatus;
                          final Color statusColor;
                          if (item.isAprobada && item.isPasada) {
                            displayStatus = context.tr('activity.status.finished').toUpperCase();
                            statusColor = const Color(0xFF8E8E93);
                          } else {
                            displayStatus = item.estado.value;
                            statusColor = _statusColor(item.estado.value);
                          }

                          return RvSurfaceCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          RvBadge(
                                            label: isServicio
                                                ? context.tr('activity.badge.service')
                                                : (item.tipoEspacio ?? context.tr('activity.badge.space')),
                                            color: isServicio ? AppColors.accentPurple : AppColors.primaryBlue,
                                          ),
                                          const Spacer(),
                                          RvBadge(
                                            label: displayStatus,
                                            color: statusColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        item.nombreEspacio ?? context.tr('activity.defaultReservation'),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatRelativeDate(item.fechaInicio, context),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      if (item.tokensConsumidos > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '-${item.tokensConsumidos} ${context.tr('home.tokens')}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.isActiva)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (isWeb) const Spacer(),

                                        Expanded(
                                          flex: isWeb ? 0 : 1,
                                          child: SizedBox(
                                            width: isWeb ? 180 : null,
                                            child: RvPrimaryButton(
                                              label: context.tr('activity.cancelBooking'),
                                              backgroundColor: AppColors.error,
                                              onTap: () => _handleCancel(context, ref, item, isServicio),
                                            ),
                                          ),
                                        ),

                                        if (item.isAprobada) ...[
                                          const SizedBox(width: 12),
                                          RvGhostIconButton(
                                            icon: Icons.calendar_today_rounded,
                                            onTap: () => CalendarUtils.addToCalendar(
                                              title: item.nombreEspacio ?? 'Reserva',
                                              startTime: item.fechaInicio,
                                              endTime: item.fechaFin,
                                              location: 'IES Luis Vives',
                                              details: 'Reserva gestionada por RESERVIVES. ${item.observaciones ?? ""}',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => _buildSkeleton(context, isWeb),
                    error: (error, _) => Center(
                      child: RvApiErrorState(
                        onRetry: () => ref.invalidate(activityHistoryProvider),
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

  Future<void> _handleCancel(BuildContext context, WidgetRef ref, dynamic item, bool isServicio) async {
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
        ? await ref.read(reservarServicioProvider.notifier).cancelarReservaServicio(item.id)
        : await ref.read(crearReservaProvider.notifier).cancelarReserva(item.id);

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
        toFriendlyErrorMessage(error, fallback: context.tr('booking.error')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APROBADA': return AppColors.success;
      case 'RECHAZADA':
      case 'CANCELADA': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  Widget _buildSkeleton(BuildContext context, bool isWeb) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 20),
      itemCount: 3,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: RvSkeleton(height: 160, borderRadius: AppRadii.m),
      ),
    );
  }
}