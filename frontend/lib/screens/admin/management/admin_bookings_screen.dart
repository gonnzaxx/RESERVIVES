import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/models/reserva_recurrente.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/reservas_recurrentes_provider.dart';
import 'package:reservives/screens/admin/general/admin_dashboard.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

// Provider que unifica reservas de espacios y servicios pendientes de aprobación
final pendingBookingsProvider = FutureProvider.autoDispose<List<Reserva>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  // Carga por separado las reservas de espacios y de servicios
  final espacios = await apiClient.get('/reservas-espacios/?estado=PENDIENTE');
  final servicios = await apiClient.get('/servicios/reservas/todas?estado=PENDIENTE');

  final all = [
    ...(espacios as List).map((json) => Reserva.fromJson(json as Map<String, dynamic>)),
    ...(servicios as List).map((json) => Reserva.fromJson(json as Map<String, dynamic>)),
  ];

  // Ordena de más reciente a más antiguo
  all.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
  return all;
});

class AdminBookingsScreen extends ConsumerWidget {
  const AdminBookingsScreen({super.key});

  // Aprueba o rechaza una reserva detectando automáticamente si es de espacio o servicio
  Future<void> _updateReserva(BuildContext context, WidgetRef ref, Reserva reserva, String action, {String? motivo}) async {
    final isServicio = reserva.tipoEspacio == 'SERVICIO';

    // Endpoint diferente según si es una reserva de espacio o de servicio
    final endpoint = isServicio
        ? '/servicios/reservas/${reserva.id}/$action'
        : '/reservas-espacios/${reserva.id}/$action';

    try {
      final body = (action == 'rechazar' && motivo != null && motivo.isNotEmpty) ? {'motivo_rechazo': motivo} : null;
      await ref.read(apiClientProvider).post(endpoint, body: body);
      ref.invalidate(pendingBookingsProvider);
      ref.invalidate(adminPendingApprovalsCountProvider);
      ref.invalidate(adminDashboardKpisProvider);
      notifyAdminCountersChanged(ref);

      if (context.mounted) {
        if (action == 'aprobar') {
          RvAlerts.success(context, context.tr('admin.bookings.approved'));
        } else {
          RvAlerts.error(context, context.tr('admin.bookings.rejected'));
        }
      }
    } catch (error) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error));
    }
  }

  // Aprueba una reserva recurrente pendiente
  Future<void> _approveRecurring(
      BuildContext context,
      WidgetRef ref,
      ReservaRecurrente reserva,
      ) async {
    final ok =
    await ref.read(adminReservaRecurrenteProvider.notifier).aprobar(reserva.id);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(reservasRecurrentesPendientesProvider);
      ref.invalidate(adminPendingApprovalsCountProvider);
      notifyAdminCountersChanged(ref);
      RvAlerts.success(context, context.tr('admin.recurrent.booking.aprove'));
    } else {
      RvAlerts.error(context, context.tr('admin.recurrent.booking.error'));
    }
  }

  // Rechaza una reserva recurrente con motivo opcional
  Future<void> _rejectRecurring(BuildContext context, WidgetRef ref, ReservaRecurrente reserva) async {
    await _showRejectDialog(
      context,
      ref,
      title: context.tr('admin.recurrent.booking.reject'),
      onConfirm: (motivo) async {
        final ok = await ref.read(adminReservaRecurrenteProvider.notifier).rechazar(
          reserva.id,
          motivo: motivo.isEmpty ? null : motivo,
        );
        if (!context.mounted) return;
        if (ok) {
          ref.invalidate(reservasRecurrentesPendientesProvider);
          ref.invalidate(adminPendingApprovalsCountProvider);
          notifyAdminCountersChanged(ref);
          RvAlerts.success(context, context.tr('admin.recurrent.booking.reject'));
        }
      },
    );
  }

  // Muestra un diálogo para introducir el motivo del rechazo
  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, {required String title, required Function(String motivo) onConfirm}) async {
    final motivoCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: RvSurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: context.tr('admin.bookings.rejectHint'),
                    filled: true,
                    fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(context.tr('generic.cancel')))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RvPrimaryButton(
                        backgroundColor: AppColors.error,
                        onTap: () => Navigator.pop(dialogCtx, true),
                        label: context.tr('admin.bookings.rejectConfirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await onConfirm(motivoCtrl.text.trim());
    }
    motivoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pendingBookingsProvider);
    final recurrentAsync = ref.watch(reservasRecurrentesPendientesProvider);
    final currentUser = ref.watch(authProvider).user;
    final isControl = currentUser?.rol == RolUsuario.control;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    if (width > 1200) {
      crossAxisCount = 3;
    } else if (width > 800) {
      crossAxisCount = 2;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin.bookings.eyebrow').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('admin.bookings.title'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RvGhostIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref.invalidate(pendingBookingsProvider),
                  ),
                ],
              ),
            ),

            Expanded(
              child: bookingsAsync.when(
                data: (bookings) {
                  final recurrent = recurrentAsync.when(
                    data: (items) => items,
                    loading: () => <ReservaRecurrente>[],
                    error: (_, __) => <ReservaRecurrente>[],
                  );
                  if (bookings.isEmpty && recurrent.isEmpty) {
                    return Center(
                      child: RvEmptyState(
                        icon: Icons.done_all_rounded,
                        title: context.tr('admin.bookings.emptyTitle'),
                        subtitle: context.tr('admin.bookings.emptySubtitle'),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recurrent.isNotEmpty) ...[
                          Text(
                            context.tr('admin.bookings.text.recurrent'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 300,
                            ),
                            itemCount: recurrent.length,
                            itemBuilder: (context, index) => _RecurringBookingAdminCard(
                              reserva: recurrent[index],
                              onApprove: isControl ? null : () => _approveRecurring(context, ref, recurrent[index]),
                              onReject: isControl ? null : () => _rejectRecurring(context, ref, recurrent[index]),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (bookings.isNotEmpty) ...[
                          Text(
                            context.tr('admin.bookings.text.puntual'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 270,
                            ),
                            itemCount: bookings.length,
                            itemBuilder: (context, index) => _BookingAdminCard(
                              reserva: bookings[index],
                              onApprove: isControl ? null : () => _updateReserva(context, ref, bookings[index], 'aprobar'),
                              onReject: isControl ? null : () => _showRejectDialog(
                                context,
                                ref,
                                title: context.tr('admin.bookings.rejectTitle'),
                                onConfirm: (motivo) => _updateReserva(context, ref, bookings[index], 'rechazar', motivo: motivo),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 340,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => const RvSkeleton(width: double.infinity, height: 340, borderRadius: 24),
                ),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(pendingBookingsProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingAdminCard extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _BookingAdminCard({required this.reserva, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isServicio = reserva.tipoEspacio == 'SERVICIO';
    final formatDay = DateFormat('EEEE d MMMM', 'es');
    final formatHour = DateFormat('HH:mm');

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isServicio ? AppColors.accentPurple : AppColors.primaryBlue).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isServicio ? Icons.build_circle_rounded : Icons.place_rounded,
                          color: isServicio ? AppColors.accentPurple : AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reserva.nombreEspacio ?? 'Reserva',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 12, color: theme.hintColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    reserva.nombreUsuario ?? 'Usuario',
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if ((reserva.emailUsuario ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.alternate_email_rounded, size: 12, color: theme.hintColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      reserva.emailUsuario!,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text(formatDay.format(reserva.fechaInicio), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text('${formatHour.format(reserva.fechaInicio)} - ${formatHour.format(reserva.fechaFin)}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (reserva.observaciones != null && reserva.observaciones!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      reserva.observaciones!,
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onApprove != null || onReject != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: Text(context.tr('admin.bookings.reject')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RvPrimaryButton(
                      backgroundColor: AppColors.success,
                      onTap: onApprove,
                      label: context.tr('admin.booking.approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecurringBookingAdminCard extends StatelessWidget {
  final ReservaRecurrente reserva;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RecurringBookingAdminCard({
    required this.reserva,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatDay = DateFormat('d MMM yyyy', 'es');

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.repeat_rounded,
                          color: AppColors.accentPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reserva.nombreEspacio ?? 'Reserva Recurrente',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 12, color: theme.hintColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    reserva.nombreUsuario ?? 'Usuario',
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if ((reserva.emailUsuario ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.alternate_email_rounded, size: 12, color: theme.hintColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      reserva.emailUsuario!,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_repeat_rounded, size: 14, color: AppColors.accentPurple),
                            const SizedBox(width: 8),
                            Text(
                              reserva.tipoRecurrencia.label,
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.accentPurple),
                            const SizedBox(width: 8),
                            Text(
                              '${formatDay.format(reserva.fechaInicio)} - ${formatDay.format(reserva.fechaFinRecurrencia)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if ((reserva.observaciones ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      reserva.observaciones!,
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onApprove != null || onReject != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: Text(context.tr('admin.bookings.reject')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RvPrimaryButton(
                      backgroundColor: AppColors.success,
                      onTap: onApprove,
                      label: context.tr('admin.bookings.approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
