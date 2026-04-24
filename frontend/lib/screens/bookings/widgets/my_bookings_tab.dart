import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/navigation_provider.dart';
import 'package:reservives/providers/reservas_provider.dart';
import 'package:reservives/providers/servicio_provider.dart';
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
      onRefresh: () async {
        ref.invalidate(activityHistoryProvider);
      },
      child: reservasAsync.when(
        data: (reservas) {
          if (reservas.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                RvEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: context.tr('services.bookings.emptyTitle'),
                  subtitle: context.tr('services.bookings.emptySubtitle'),
                  buttonLabel: context.tr('emptyState.bookNow'),
                  onButtonPressed: () {
                    ref.read(servicesTabIndexProvider.notifier).setIndex(0);
                  },
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: reservas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final reserva = reservas[index];
              final color = _statusColor(reserva.estado);

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadii.m),
                  boxShadow: AppShadows.soft(context),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reserva.nombreEspacio ?? 'Reserva',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                RvBadge(
                                  label: reserva.estado.value,
                                  color: color,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reserva.tipoEspacio == 'SERVICIO'
                                  ? 'Servicio del instituto'
                                  : (reserva.tipoEspacio ?? 'Espacio'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${dateFormat.format(reserva.fechaInicio)} · ${timeFormat.format(reserva.fechaInicio)} - ${timeFormat.format(reserva.fechaFin)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                            if (reserva.isActiva) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_rounded),
                                  label: const Text('Cancelar reserva'),
                                  onPressed: () =>
                                      _confirmCancel(context, ref, reserva),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => Center(
          child: RvApiErrorState(
            onRetry: () => ref.invalidate(activityHistoryProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context,
      WidgetRef ref,
      Reserva reserva,
      ) async {

    final confirm = await RvAlerts.confirm(
      context,
      title: 'Cancelar reserva',
      content: '¿Estás seguro de que quieres cancelar esta reserva? Esta acción no se puede deshacer.',
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'Volver',
      isDestructive: true,
    );

    if (confirm != true) return;

    final isServicio = reserva.tipoEspacio == 'SERVICIO';
    RvAlerts.info(context, 'Cancelando reserva...');
    final success = isServicio
        ? await ref
        .read(reservarServicioProvider.notifier)
        .cancelarReservaServicio(reserva.id)
        : await ref
        .read(crearReservaProvider.notifier)
        .cancelarReserva(reserva.id);

    if (!context.mounted) return;

    if (success) {
      RvAlerts.success(context, 'Reserva cancelada correctamente');
      return;
    }

    final error = isServicio
        ? ref.read(reservarServicioProvider).error
        : ref.read(crearReservaProvider).error;
    RvAlerts.error(context, toFriendlyErrorMessage(error));
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
}
