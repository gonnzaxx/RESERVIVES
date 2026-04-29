import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

class ReservaDetalleScreen extends ConsumerWidget {
  const ReservaDetalleScreen({
    super.key,
    required this.reservaId,
    this.reservaInicial,
    this.tipoEspacio,
  });

  final String reservaId;
  final Reserva? reservaInicial;
  final String? tipoEspacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', locale);

    if (reservaInicial != null) {
      return _ReservaDetalleBody(
        reserva: reservaInicial!,
        dateFormat: dateFormat,
      );
    }

    return FutureBuilder<Reserva>(
      future: _loadReserva(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: RvLogoLoader()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _CustomHeader(title: context.tr('generic.error')),
                  Expanded(
                    child: Center(
                      child: RvApiErrorState(
                        title: context.tr('error.data_load_failed_title'),
                        subtitle: context.tr('error.retry_default_subtitle'),
                        onRetry: () => (context as Element).markNeedsBuild(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _ReservaDetalleBody(
          reserva: snapshot.data!,
          dateFormat: dateFormat,
        );
      },
    );
  }

  Future<Reserva> _loadReserva(WidgetRef ref) async {
    final apiClient = ref.read(apiClientProvider);

    if ((tipoEspacio ?? '').toUpperCase() == 'SERVICIO') {
      final response = await apiClient.get('/servicios/reservas/detalle/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }

    if ((tipoEspacio ?? '').toUpperCase() == 'ESPACIO') {
      final response = await apiClient.get('/reservas-espacios/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }

    try {
      final response = await apiClient.get('/reservas-espacios/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      final response = await apiClient.get('/servicios/reservas/detalle/$reservaId');
      return Reserva.fromJson(response as Map<String, dynamic>);
    }
  }
}

class _ReservaDetalleBody extends StatelessWidget {
  const _ReservaDetalleBody({
    required this.reserva,
    required this.dateFormat,
  });

  final Reserva reserva;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                _CustomHeader(
                  eyebrow: context.tr('booking.detail.eyebrow'),
                  title: reserva.nombreEspacio ?? context.tr('booking.detail.defaultTitle'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    children: [
                      RvSurfaceCard(
                        child: Column(
                          children: [
                            _DetailItem(
                              icon: Icons.category_rounded,
                              label: context.tr('booking.detail.resourceType'),
                              value: reserva.tipoEspacio ?? context.tr('admin.bookings.unknown'),
                            ),
                            const _Divider(),
                            _DetailItem(
                              icon: Icons.event_available_rounded,
                              label: context.tr('booking.detail.startTime'),
                              value: dateFormat.format(reserva.fechaInicio),
                            ),
                            const _Divider(),
                            _DetailItem(
                              icon: Icons.event_busy_rounded,
                              label: context.tr('booking.detail.endTime'),
                              value: dateFormat.format(reserva.fechaFin),
                            ),
                            const _Divider(),
                            _DetailItem(
                              icon: Icons.info_outline_rounded,
                              label: context.tr('booking.detail.status'),
                              value: _estadoLabel(context, reserva.estado),
                              trailing: RvBadge(
                                label: _estadoLabel(context, reserva.estado),
                                color: _estadoColor(reserva.estado),
                              ),
                            ),
                            if ((reserva.nombreUsuario ?? '').isNotEmpty) ...[
                              const _Divider(),
                              _DetailItem(
                                icon: Icons.person_outline_rounded,
                                label: context.tr('booking.detail.reservedBy'),
                                value: reserva.nombreUsuario!,
                              ),
                            ],
                            const _Divider(),
                            _DetailItem(
                              icon: Icons.toll_rounded,
                              label: context.tr('booking.detail.cost'),
                              value: '${reserva.tokensConsumidos} ${context.tr('home.tokens')}',
                            ),
                            if ((reserva.observaciones ?? '').trim().isNotEmpty) ...[
                              const _Divider(),
                              _DetailItem(
                                icon: Icons.notes_rounded,
                                label: context.tr('booking.notes'),
                                value: reserva.observaciones!,
                              ),
                            ],
                          ],
                        ),
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

  String _estadoLabel(BuildContext context, EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.pendiente: return context.tr('detail.booking.state.pending');
      case EstadoReserva.aprobada: return context.tr('admin.bookings.approved');
      case EstadoReserva.rechazada: return context.tr('admin.bookings.rejected');
      case EstadoReserva.cancelada: return context.tr('activity.status.finished');
    }
  }

  Color _estadoColor(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.pendiente: return Colors.orange;
      case EstadoReserva.aprobada: return Colors.green;
      case EstadoReserva.rechazada: return Colors.red;
      case EstadoReserva.cancelada: return Colors.grey;
    }
  }
}

class _CustomHeader extends StatelessWidget {
  final String title;
  final String eyebrow;

  const _CustomHeader({required this.title, this.eyebrow = ''});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RvPageHeader(
              eyebrow: eyebrow,
              title: title,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
      ),
    );
  }
}