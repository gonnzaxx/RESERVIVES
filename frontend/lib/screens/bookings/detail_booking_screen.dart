import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/core/utils/calendar_utils.dart';

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

  // Carga los datos de la reserva desde la API según su tipo (espacio o servicio)
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

class _ReservaDetalleBody extends ConsumerStatefulWidget {
  const _ReservaDetalleBody({
    required this.reserva,
    required this.dateFormat,
  });

  final Reserva reserva;
  final DateFormat dateFormat;

  @override
  ConsumerState<_ReservaDetalleBody> createState() => _ReservaDetalleBodyState();
}

class _ReservaDetalleBodyState extends ConsumerState<_ReservaDetalleBody> {
  bool _cancelling = false;
  late Reserva _reserva;

  @override
  void initState() {
    super.initState();
    _reserva = widget.reserva;
  }

  // Pide confirmación y cancela la reserva si el usuario acepta
  Future<void> _cancelar() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CancelConfirmSheet(
        title: context.tr('booking.cancel.title'),
        message: context.tr('booking.cancel.confirm'),
        confirmLabel: context.tr('booking.cancel.action'),
        cancelLabel: context.tr('common.cancel'),
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final isServicio = (_reserva.tipoEspacio ?? '').toUpperCase() == 'SERVICIO';
      final endpoint = isServicio
          ? '/servicios/reservas/${_reserva.id}/cancelar'
          : '/reservas-espacios/${_reserva.id}/cancelar';
      await apiClient.post(endpoint);
      if (!mounted) return;
      ref.invalidate(misReservasProvider);
      ref.invalidate(misReservasServiciosProvider);
      setState(() => _reserva = _reserva.copyWith(estado: EstadoReserva.cancelada));
      RvAlerts.success(context, context.tr('booking.cancel.success'));
    } catch (e) {
      if (!mounted) return;
      RvAlerts.error(context, toFriendlyErrorMessage(e, fallback: context.tr('booking.cancel.error')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // Abre Google Calendar con los datos de la reserva prellenados
  void _addToCalendar() {
    CalendarUtils.addToCalendar(
      title: _reserva.nombreEspacio ?? 'Reserva',
      startTime: _reserva.fechaInicio,
      endTime: _reserva.fechaFin,
      location: 'IES Luis Vives',
      details: 'Reserva gestionada por RESERVIVES.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPast = _reserva.isPasada;
    final estado = _reserva.estado;
    final user = ref.watch(authProvider).user;
    final isOwner = user?.id == _reserva.usuarioId;
    final canCancel = isOwner && !isPast && !_reserva.isCancelada && !_reserva.isRechazada;
    final canCalendar = _reserva.isAprobada && !isPast;

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
                  title: _reserva.nombreEspacio ??
                      context.tr('booking.detail.defaultTitle'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                    children: [
                      _StatusBanner(
                        estado: estado,
                        label: isPast && !_reserva.isCancelada && !_reserva.isRechazada
                            ? context.tr('activity.status.finished')
                            : _estadoLabel(context, estado),
                        color: isPast && !_reserva.isCancelada && !_reserva.isRechazada
                            ? AppColors.lightTextSecondary
                            : _estadoColor(estado),
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
                            value: _reserva.tipoEspacio ??
                                context.tr('admin.bookings.unknown'),
                          ),
                          _Item(
                            icon: Icons.event_available_rounded,
                            label: context.tr('booking.detail.startTime'),
                            value: widget.dateFormat.format(_reserva.fechaInicio),
                            accent: AppColors.success,
                          ),
                          _Item(
                            icon: Icons.event_busy_rounded,
                            label: context.tr('booking.detail.endTime'),
                            value: widget.dateFormat.format(_reserva.fechaFin),
                            accent: AppColors.error,
                          ),
                          if ((_reserva.nombreUsuario ?? '').isNotEmpty)
                            _Item(
                              icon: Icons.person_outline_rounded,
                              label: context.tr('booking.detail.reservedBy'),
                              value: _reserva.nombreUsuario!,
                            ),
                          _Item(
                            icon: Icons.toll_rounded,
                            label: context.tr('booking.detail.cost'),
                            value:
                            '${_reserva.tokensConsumidos} ${context.tr('home.tokens')}',
                            accent: AppColors.warning,
                          ),
                          if ((_reserva.observaciones ?? '').trim().isNotEmpty)
                            _Item(
                              icon: Icons.notes_rounded,
                              label: context.tr('booking.notes'),
                              value: _reserva.observaciones!,
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

                      if (canCalendar || canCancel) ...[
                        const SizedBox(height: 24),
                        _ActionButtons(
                          canCancel: canCancel,
                          canCalendar: canCalendar,
                          cancelling: _cancelling,
                          onCancel: _cancelar,
                          onCalendar: _addToCalendar,
                        )
                            .animate()
                            .fadeIn(delay: 160.ms, duration: 300.ms)
                            .slideY(begin: 0.04, delay: 160.ms, curve: Curves.easeOutCubic),
                      ],
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

  // Devuelve el texto localizado para el estado de la reserva
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

  // Devuelve el color asociado al estado de la reserva
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

class _ActionButtons extends StatelessWidget {
  final bool canCancel;
  final bool canCalendar;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onCalendar;

  const _ActionButtons({
    required this.canCancel,
    required this.canCalendar,
    required this.cancelling,
    required this.onCancel,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        if (canCalendar)
          _ActionTile(
            icon: Icons.edit_calendar_rounded,
            label: context.tr('booking.detail.addToCalendar'),
            iconColor: theme.colorScheme.primary,
            isDark: isDark,
            onTap: onCalendar,
          ),
        if (canCalendar && canCancel) const SizedBox(height: 10),
        if (canCancel)
          _ActionTile(
            label: context.tr('booking.cancel.action'),
            iconColor: AppColors.error,
            isDark: isDark,
            isDestructive: true,
            isLoading: cancelling,
            onTap: cancelling ? null : onCancel,
          ),
      ],
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData? icon;
  final String label;
  final Color iconColor;
  final bool isDark;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionTile({
    this.icon,
    required this.label,
    required this.iconColor,
    required this.isDark,
    this.isDestructive = false,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isDestructive ? AppColors.error : widget.iconColor;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
        setState(() => _pressed = false);
        widget.onTap!();
      }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: widget.isDark ? 0.10 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _CancelConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_rounded,
              size: 32,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                cancelLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  // Icono asociado al estado de la reserva
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
    final isWeb = AppConstants.isWideScreen(context);
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