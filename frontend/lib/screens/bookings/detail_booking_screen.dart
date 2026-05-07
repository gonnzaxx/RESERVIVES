import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

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
                  _Header(title: context.tr('generic.error')),
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
      final response =
      await apiClient.get('/servicios/reservas/detalle/$reservaId');
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
      final response =
      await apiClient.get('/servicios/reservas/detalle/$reservaId');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final estado = reserva.estado;

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
                _Header(
                  eyebrow: context.tr('booking.detail.eyebrow'),
                  title: reserva.nombreEspacio ??
                      context.tr('booking.detail.defaultTitle'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                    children: [
                      _StatusBanner(
                        estado: estado,
                        label: _estadoLabel(context, estado),
                        color: _estadoColor(estado),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),

                      const SizedBox(height: 16),

                      _DetailCard(
                        isDark: isDark,
                        theme: theme,
                        items: [
                          _Item(
                            icon: Icons.category_rounded,
                            label: context.tr('booking.detail.resourceType'),
                            value: reserva.tipoEspacio ??
                                context.tr('admin.bookings.unknown'),
                          ),
                          _Item(
                            icon: Icons.event_available_rounded,
                            label: context.tr('booking.detail.startTime'),
                            value: dateFormat.format(reserva.fechaInicio),
                            accent: AppColors.success,
                          ),
                          _Item(
                            icon: Icons.event_busy_rounded,
                            label: context.tr('booking.detail.endTime'),
                            value: dateFormat.format(reserva.fechaFin),
                            accent: AppColors.error,
                          ),
                          if ((reserva.nombreUsuario ?? '').isNotEmpty)
                            _Item(
                              icon: Icons.person_outline_rounded,
                              label: context.tr('booking.detail.reservedBy'),
                              value: reserva.nombreUsuario!,
                            ),
                          _Item(
                            icon: Icons.toll_rounded,
                            label: context.tr('booking.detail.cost'),
                            value:
                            '${reserva.tokensConsumidos} ${context.tr('home.tokens')}',
                            accent: AppColors.warning,
                          ),
                          if ((reserva.observaciones ?? '').trim().isNotEmpty)
                            _Item(
                              icon: Icons.notes_rounded,
                              label: context.tr('booking.notes'),
                              value: reserva.observaciones!,
                              isMultiline: true,
                            ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 300.ms)
                          .slideY(
                        begin: 0.04,
                        delay: 80.ms,
                        curve: Curves.easeOutCubic,
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
      case EstadoReserva.pendiente:
        return context.tr('detail.booking.state.pending');
      case EstadoReserva.aprobada:
        return context.tr('admin.bookings.approved');
      case EstadoReserva.rechazada:
        return context.tr('admin.bookings.rejected');
      case EstadoReserva.cancelada:
        return context.tr('activity.status.finished');
    }
  }

  Color _estadoColor(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.pendiente:
        return AppColors.warning;
      case EstadoReserva.aprobada:
        return AppColors.success;
      case EstadoReserva.rechazada:
        return AppColors.error;
      case EstadoReserva.cancelada:
        return AppColors.lightTextSecondary;
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final EstadoReserva estado;
  final String label;
  final Color color;

  const _StatusBanner({
    required this.estado,
    required this.label,
    required this.color,
  });

  IconData get _icon {
    switch (estado) {
      case EstadoReserva.pendiente:
        return Icons.schedule_rounded;
      case EstadoReserva.aprobada:
        return Icons.check_circle_rounded;
      case EstadoReserva.rechazada:
        return Icons.cancel_rounded;
      case EstadoReserva.cancelada:
        return Icons.block_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('booking.detail.status').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final List<_Item> items;

  const _DetailCard({
    required this.isDark,
    required this.theme,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              _DetailRow(item: items[i], theme: theme, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final bool isMultiline;

  const _Item({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.isMultiline = false,
  });
}

class _DetailRow extends StatelessWidget {
  final _Item item;
  final ThemeData theme;
  final bool isDark;

  const _DetailRow({
    required this.item,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        item.accent ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: item.isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: item.isMultiline ? 1.5 : 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String eyebrow;

  const _Header({required this.title, this.eyebrow = ''});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RvGhostIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow.isNotEmpty) ...[
                  Text(
                    eyebrow.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}