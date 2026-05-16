import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/spaces_provider.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/bookings_live_updates_provider.dart';
import 'package:reservives/providers/time_slots_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/lista_espera_provider.dart';


class BookingScreen extends ConsumerStatefulWidget {
  final String espacioId;
  const BookingScreen({super.key, required this.espacioId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late DateTime _selectedDate;
  String? _selectedTramoId;
  final TextEditingController _observacionesCtrl = TextEditingController();
  late ConfettiController _confettiController;
  int _shakeTrigger = 0;

  // Inicializa la fecha, el confeti y conecta el WebSocket de disponibilidad
  @override
  void initState() {
    super.initState();
    _selectedDate = getInitialDate(DateTime.now());
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    Future.microtask(
            () => ref.read(bookingsWebSocketProvider).connect());
  }

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // Devuelve true si el día es sábado o domingo
  bool _isWeekend(DateTime d) => d.weekday == 6 || d.weekday == 7;

  // Ejecuta la reserva: valida el tramo, muestra carga y gestiona éxito o error
  Future<void> _onBook() async {
    if (_selectedTramoId == null) {
      HapticFeedback.heavyImpact();
      setState(() => _shakeTrigger++);
      return;
    }

    _showLoadingOverlay();

    final sw = Stopwatch()..start();
    final success =
    await ref.read(crearReservaProvider.notifier).crearReserva(
      widget.espacioId,
      _selectedDate,
      _selectedTramoId!,
      _observacionesCtrl.text.isEmpty
          ? null
          : _observacionesCtrl.text,
    );

    final elapsed = sw.elapsed;
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      ref.invalidate(misReservasProvider);
      ref.invalidate(activityHistoryProvider);
      _confettiController.play();

      final reserva = ref.read(crearReservaProvider).value;
      if (reserva == null) {
        context.goNamed('espacios');
        return;
      }

      await _showSuccessSheet(reserva);

      if (!mounted) return;
      context.pushNamed(
        'reserva_detalle',
        pathParameters: {'reservaId': reserva.id},
        extra: reserva,
        queryParameters: {'tipo': 'ESPACIO'},
      );
      return;
    }

    final error = ref.read(crearReservaProvider).error;
    final raw = error?.toString() ?? '';
    final msg = raw.replaceFirst(RegExp(r'^[A-Za-z]*Exception:\s*'), '').replaceFirst(RegExp(r'\s*\(\d+\)$'), '');
    RvAlerts.error(context, msg.isNotEmpty ? msg : context.tr('booking.error'));
  }

  // Muestra el bottom sheet de confirmación tras crear la reserva
  Future<void> _showSuccessSheet(dynamic reserva) async {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final isPending = reserva.isPendiente;
    final color =
    isPending ? AppColors.warning : AppColors.success;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            24,
            14,
            24,
            MediaQuery.of(ctx).padding.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RvSheetHeader(onClose: () => Navigator.pop(ctx)),
            const SizedBox(height: 12),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_rounded,
                size: 36,
                color: color,
              ),
            )
                .animate()
                .scale(
                duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              isPending
                  ? context.tr(
                  'booking.confirm.application.pending')
                  : context.tr('booking.confirm.application'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPending
                  ? 'Tu solicitud para "${reserva.nombreEspacio}" está pendiente de revisión.'
                  : 'Reserva confirmada en "${reserva.nombreEspacio}". ¡Que lo disfrutes!',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                  height: 1.6,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            RvPrimaryButton(
              onTap: () => Navigator.pop(ctx),
              label: context.tr('generic.understood'),
            ),
          ],
        ),
      ),
    );
  }

  // Muestra un overlay de carga que bloquea la interacción mientras se procesa la reserva
  void _showLoadingOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final isDark =
            Theme.of(context).brightness == Brightness.dark;
        return FadeTransition(
          opacity: anim1,
          child: PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 40),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.20),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RvLogoLoader(size: 64),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('booking.processing'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estamos confirmando tu plaza…',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scale(
                    curve: Curves.easeOutBack,
                    duration: 380.ms)
                    .fadeIn(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = AppConstants.isWideScreen(context);
    final espacioAsync =
    ref.watch(espacioDetalleProvider(widget.espacioId));
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: AppConstants.webMaxWidth),
                child: espacioAsync.when(
                  data: (espacio) {
                    final usesTokens = user?.usesTokens ?? true;
                    final costo = espacio.precioTokens;
                    final costoEfectivo =
                    usesTokens ? costo : 0;
                    final tieneTokens = usesTokens
                        ? (user?.tokens ?? 0) >= costoEfectivo
                        : true;
                    final effectiveLastDate = DateTime.now()
                        .add(Duration(days: espacio.antelacionDias));
                    final exceedsMaxWindow =
                    _selectedDate.isAfter(effectiveLastDate);

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          20, isWeb ? 20 : 10, 20, 40),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RvGhostIconButton(
                                icon: Icons
                                    .arrow_back_ios_new_rounded,
                                onTap: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context
                                        .goNamed('servicios');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('spaces.title')
                                          .toUpperCase(),
                                      style: theme.textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        letterSpacing: 0.9,
                                        fontWeight:
                                        FontWeight.w700,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr('booking.title'),
                                      style: theme.textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                        fontWeight:
                                        FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              RvGhostIconButton(
                                icon: Icons
                                    .calendar_month_rounded,
                                onTap: () => context.push(
                                    '/calendario/${widget.espacioId}'),
                              ),
                              if (user?.rol !=
                                  RolUsuario.alumno) ...[
                                const SizedBox(width: 4),
                                RvGhostIconButton(
                                  icon: Icons.repeat_rounded,
                                  onTap: () => context.push(
                                      '/reserva-recurrente/${widget.espacioId}'),
                                ),
                              ],
                            ],
                          ).animate().fadeIn(duration: 300.ms),

                          const SizedBox(height: 20),

                          _InfoCard(
                            espacio: espacio,
                            usesTokens: usesTokens,
                            costo: costo,
                            isDark: isDark,
                            theme: theme,
                          )
                              .animate()
                              .fadeIn(
                              delay: 80.ms, duration: 300.ms)
                              .slideY(
                            begin: 0.04,
                            delay: 80.ms,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          ),

                          const SizedBox(height: 24),

                          _SectionLabel(
                              label:
                              context.tr('booking.date'),
                              theme: theme),
                          const SizedBox(height: 10),
                          _DateField(
                            selectedDate: _selectedDate,
                            effectiveLastDate: effectiveLastDate,
                            isDark: isDark,
                            theme: theme,
                            isWeekend: _isWeekend,
                            onDateSelected: (d) => setState(() {
                              _selectedDate = d;
                              _selectedTramoId = null;
                            }),
                          )
                              .animate()
                              .fadeIn(
                              delay: 120.ms, duration: 300.ms),

                          const SizedBox(height: 24),

                          _SectionLabel(
                              label: context.tr(
                                  'bookings.time.slot.text'),
                              theme: theme),
                          const SizedBox(height: 10),
                          _TramoSelector(
                            espacioId: widget.espacioId,
                            selectedDate: _selectedDate,
                            selectedTramoId: _selectedTramoId,
                            isDark: isDark,
                            theme: theme,
                            onTramoSelected: (id) => setState(
                                    () => _selectedTramoId = id),
                          )
                              .animate()
                              .fadeIn(
                              delay: 160.ms, duration: 300.ms),

                          const SizedBox(height: 24),

                          _SectionLabel(
                              label:
                              context.tr('booking.notes'),
                              theme: theme),
                          const SizedBox(height: 10),
                          _NotesField(
                            controller: _observacionesCtrl,
                            isDark: isDark,
                            theme: theme,
                            hint: context
                                .tr('booking.notesHint'),
                          )
                              .animate()
                              .fadeIn(
                              delay: 180.ms, duration: 300.ms),

                          const SizedBox(height: 20),

                          _Banners(
                            tieneTokens: tieneTokens,
                            isWeekend: _isWeekend(_selectedDate),
                            exceedsMaxWindow: exceedsMaxWindow,
                            requiereAut:
                            espacio.requiereAutorizacion,
                          ),

                          const SizedBox(height: 16),

                          Align(
                            alignment: isWeb
                                ? Alignment.centerRight
                                : Alignment.center,
                            child: _ConfirmButton(
                              isWeb: isWeb,
                              isDisabled: !tieneTokens ||
                                  _isWeekend(_selectedDate) ||
                                  exceedsMaxWindow,
                              shakeTrigger: _shakeTrigger,
                              label: context.tr('booking.confirm'),
                              onTap: _onBook,
                              onShake: () => setState(
                                      () => _shakeTrigger++),
                              theme: theme,
                            ),
                          ).animate().fadeIn(
                              delay: 200.ms, duration: 300.ms),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      _BookingSkeleton(isWeb: isWeb, isDark: isDark),
                  error: (_, __) => Center(
                    child: RvApiErrorState(
                      onRetry: () => ref.invalidate(
                          espacioDetalleProvider(
                              widget.espacioId)),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality:
                BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppColors.primaryBlue,
                  AppColors.accentPurple,
                  AppColors.success,
                  Colors.yellow,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final dynamic espacio;
  final bool usesTokens;
  final int costo;
  final bool isDark;
  final ThemeData theme;

  const _InfoCard({
    required this.espacio,
    required this.usesTokens,
    required this.costo,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkHeroGradient
            : AppColors.lightHeroGradient,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RvBadge(
                label: espacio.tipo.value,
                icon: Icons.place_rounded,
                color: AppColors.accentPurple,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Text(
                  usesTokens
                      ? '$costo ${context.tr('booking.tokens')}'
                      : context.tr('booking.freeForTeachers'),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            espacio.nombre,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime effectiveLastDate;
  final bool isDark;
  final ThemeData theme;
  final bool Function(DateTime) isWeekend;
  final ValueChanged<DateTime> onDateSelected;

  const _DateField({
    required this.selectedDate,
    required this.effectiveLastDate,
    required this.isDark,
    required this.theme,
    required this.isWeekend,
    required this.onDateSelected,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: widget.selectedDate,
            firstDate: DateTime.now(),
            lastDate: widget.effectiveLastDate,
            selectableDayPredicate: (d) => !widget.isWeekend(d),
          );
          if (date != null) widget.onDateSelected(date);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkCard
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(
              color: _hovered
                  ? primary.withValues(alpha: 0.30)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
              width: 1.5,
            ),
            boxShadow: AppShadows.soft(context),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.calendar_today_rounded,
                    size: 18, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('bookings.date.text'),
                      style: widget.theme.textTheme.labelSmall
                          ?.copyWith(
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE d MMMM', 'es')
                          .format(widget.selectedDate),
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _hovered
                    ? primary
                    : widget.theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ThemeData theme;
  final String hint;

  const _NotesField({
    required this.controller,
    required this.isDark,
    required this.theme,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.m),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }
}

class _Banners extends StatelessWidget {
  final bool tieneTokens;
  final bool isWeekend;
  final bool exceedsMaxWindow;
  final bool requiereAut;

  const _Banners({
    required this.tieneTokens,
    required this.isWeekend,
    required this.exceedsMaxWindow,
    required this.requiereAut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!tieneTokens)
          _BannerTile(
            icon: Icons.error_outline_rounded,
            text: context.tr('booking.notEnoughTokens'),
            color: AppColors.error,
          ),
        if (isWeekend)
          _BannerTile(
            icon: Icons.event_busy_rounded,
            text: context.tr('booking.weekendNotAllowed'),
            color: AppColors.error,
          ),
        if (exceedsMaxWindow)
          _BannerTile(
            icon: Icons.calendar_month_rounded,
            text: context.tr('booking.maxWeekError'),
            color: AppColors.warning,
          ),
        if (tieneTokens && requiereAut)
          _BannerTile(
            icon: Icons.hourglass_top_rounded,
            text: context.tr('booking.pendingApproval'),
            color: AppColors.warning,
          ),
      ],
    );
  }
}

class _BannerTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _BannerTile({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.m),
          border: Border.all(
            color: color.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                    color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatefulWidget {
  final bool isWeb;
  final bool isDisabled;
  final int shakeTrigger;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onShake;
  final ThemeData theme;

  const _ConfirmButton({
    required this.isWeb,
    required this.isDisabled,
    required this.shakeTrigger,
    required this.label,
    required this.onTap,
    required this.onShake,
    required this.theme,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.isDisabled) {
          HapticFeedback.heavyImpact();
          widget.onShake();
        } else {
          HapticFeedback.lightImpact();
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.isWeb ? 240 : double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? (widget.theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06))
                : primary,
            borderRadius: BorderRadius.circular(AppRadii.m),
            boxShadow: widget.isDisabled
                ? null
                : [
              BoxShadow(
                color: primary.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: widget.isDisabled
                    ? widget.theme.hintColor
                    : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    ).animate(target: widget.shakeTrigger.toDouble()).shake(
      duration: 380.ms,
      hz: 6,
    );
  }
}

class _TramoSelector extends ConsumerWidget {
  final String espacioId;
  final DateTime selectedDate;
  final String? selectedTramoId;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<String> onTramoSelected;

  const _TramoSelector({
    required this.espacioId,
    required this.selectedDate,
    required this.selectedTramoId,
    required this.isDark,
    required this.theme,
    required this.onTramoSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponibilidadAsync = ref.watch(
      disponibilidadEspacioProvider(
          (espacioId: espacioId, fecha: selectedDate)),
    );

    return disponibilidadAsync.when(
      data: (tramos) {
        final visibles =
        tramos.where((t) => t.permitido).toList()
          ..sort((a, b) => a.tramo.horaInicio
              .compareTo(b.tramo.horaInicio));

        if (visibles.isEmpty) {
          return _TramoEmpty(
              isDark: isDark,
              theme: theme,
              isError: false);
        }

        final manana = visibles
            .where((t) => t.tramo.turno == 'MAÑANA')
            .toList();
        final tarde = visibles
            .where((t) => t.tramo.turno == 'TARDE')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manana.isNotEmpty) ...[
              _TurnoHeader(
                label: context.tr('bookings.morning.shift'),
                icon: Icons.wb_sunny_outlined,
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _TramoGrid(
                items: manana,
                selectedTramoId: selectedTramoId,
                espacioId: espacioId,
                fecha: selectedDate,
                isDark: isDark,
                theme: theme,
                onSelect: onTramoSelected,
              ),
            ],
            if (tarde.isNotEmpty) ...[
              const SizedBox(height: 20),
              _TurnoHeader(
                label: context.tr('bookings.afternoon.shift'),
                icon: Icons.nights_stay_outlined,
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _TramoGrid(
                items: tarde,
                selectedTramoId: selectedTramoId,
                espacioId: espacioId,
                fecha: selectedDate,
                isDark: isDark,
                theme: theme,
                onSelect: onTramoSelected,
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => _TramoEmpty(
        isDark: isDark,
        theme: theme,
        isError: true,
        onRetry: () =>
            ref.invalidate(disponibilidadEspacioProvider),
      ),
    );
  }
}

class _TurnoHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeData theme;
  final bool isDark;

  const _TurnoHeader({
    required this.label,
    required this.icon,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _TramoGrid extends StatelessWidget {
  final List<TramoDisponibilidad> items;
  final String? selectedTramoId;
  final String espacioId;
  final DateTime fecha;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<String> onSelect;

  const _TramoGrid({
    required this.items,
    required this.selectedTramoId,
    required this.espacioId,
    required this.fecha,
    required this.isDark,
    required this.theme,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 500 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 68,
        ),
        itemBuilder: (context, i) => _TramoChip(
          disponibilidad: items[i],
          isSelected: selectedTramoId == items[i].tramo.id,
          espacioId: espacioId,
          fecha: fecha,
          isDark: isDark,
          theme: theme,
          onTap: items[i].disponible
              ? () => onSelect(items[i].tramo.id)
              : null,
        ),
      );
    });
  }
}

class _TramoChip extends ConsumerStatefulWidget {
  final TramoDisponibilidad disponibilidad;
  final bool isSelected;
  final VoidCallback? onTap;
  final String espacioId;
  final DateTime fecha;
  final bool isDark;
  final ThemeData theme;

  const _TramoChip({
    required this.disponibilidad,
    required this.isSelected,
    required this.espacioId,
    required this.fecha,
    required this.isDark,
    required this.theme,
    this.onTap,
  });

  @override
  ConsumerState<_TramoChip> createState() => _TramoChipState();
}

class _TramoChipState extends ConsumerState<_TramoChip> {
  bool _hovered = false;

  // Al tocar un tramo ocupado, muestra el sheet para unirse a la lista de espera
  void _onTapOcupado() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListaEsperaSheet(
        espacioId: widget.espacioId,
        tramoId: widget.disponibilidad.tramo.id,
        fecha: widget.fecha,
        nombreTramo: widget.disponibilidad.tramo.rangoHorario,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;
    final isReservado = widget.disponibilidad.reservado;
    final esPasado =
        widget.disponibilidad.estado == EstadoTramo.horarioPasado;
    final isEnabled = widget.onTap != null;

    Color bgColor;
    Color borderColor;
    if (widget.isSelected) {
      bgColor = primary;
      borderColor = primary;
    } else if (!isEnabled) {
      bgColor = widget.isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02);
      borderColor = widget.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04);
    } else {
      bgColor = _hovered
          ? primary.withValues(alpha: 0.06)
          : (widget.isDark ? AppColors.darkCard : Colors.white);
      borderColor = _hovered
          ? primary.withValues(alpha: 0.25)
          : (widget.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07));
    }

    return MouseRegion(
      cursor: isEnabled || (isReservado && !esPasado)
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: isReservado && !esPasado ? _onTapOcupado : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: widget.isSelected
                ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.disponibilidad.tramo.rangoHorario,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : (isEnabled
                      ? widget.theme.textTheme.bodyLarge?.color
                      : widget.theme.disabledColor),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              _chipSubtitle(widget.theme, primary),
            ],
          ),
        ),
      ),
    ).animate(target: widget.isSelected ? 1 : 0).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.03, 1.03),
      duration: 200.ms,
    );
  }

  // Devuelve el texto secundario del chip según el estado del tramo (ocupado, pasado, seleccionado...)
  Widget _chipSubtitle(ThemeData theme, Color primary) {
    final baseStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: widget.isSelected
          ? Colors.white70
          : theme.disabledColor,
    );

    if (widget.disponibilidad.reservado) {
      return Text(widget.disponibilidad.reservadoPorMi ? 'Ya lo has reservado' : 'Ocupado', style: baseStyle);
    }
    if (widget.disponibilidad.estado == EstadoTramo.horarioPasado) {
      return Text('Pasado', style: baseStyle);
    }
    if (widget.isSelected) {
      return Text(
        'Seleccionado',
        style: baseStyle.copyWith(color: Colors.white),
      );
    }
    return Text(widget.disponibilidad.tramo.nombre,
        style: baseStyle);
  }
}

class _TramoEmpty extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isError;
  final VoidCallback? onRetry;

  const _TramoEmpty({
    required this.isDark,
    required this.theme,
    required this.isError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color =
    isError ? AppColors.error : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.event_busy_rounded,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? 'Error al cargar tramos'
                : 'No hay tramos disponibles',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(
                onPressed: onRetry,
                child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}


class _ListaEsperaSheet extends ConsumerWidget {
  final String espacioId;
  final String tramoId;
  final DateTime fecha;
  final String nombreTramo;

  const _ListaEsperaSheet({
    required this.espacioId,
    required this.tramoId,
    required this.fecha,
    required this.nombreTramo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final countAsync = ref.watch(listaEsperaCountProvider((
    espacioId: espacioId,
    tramoId: tramoId,
    fecha: fecha,
    )));
    final actionState = ref.watch(listaEsperaActionProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RvSheetHeader(onClose: () => Navigator.pop(context)),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.queue_rounded,
                size: 30, color: AppColors.warning),
          ),
          const SizedBox(height: 16),
          Text(
            'Tramo ocupado',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El tramo $nombreTramo está reservado.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          countAsync.when(
            data: (n) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color:
                  AppColors.warning.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Text(
                '$n en espera',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            loading: () => const SizedBox(
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          RvPrimaryButton(
            onTap: actionState.isLoading
                ? null
                : () async {
              final ok = await ref
                  .read(listaEsperaActionProvider.notifier)
                  .unirse(
                espacioId: espacioId,
                tramoId: tramoId,
                fecha: fecha,
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (ok) {
                  RvAlerts.success(
                      context,
                      'Ya estás en lista de espera');
                }
              }
            },
            label: actionState.isLoading
                ? 'Procesando…'
                : 'Unirse a la lista de espera',
            icon: Icons.queue_rounded,
          ),
        ],
      ),
    );
  }
}

class _BookingSkeleton extends StatelessWidget {
  final bool isWeb;
  final bool isDark;

  const _BookingSkeleton(
      {required this.isWeb, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, isWeb ? 20 : 10, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RvSkeleton(width: 200, height: 28, borderRadius: 6),
          const SizedBox(height: 20),
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.l),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const RvSkeleton(width: 80, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          const RvSkeleton(
              width: double.infinity,
              height: 66,
              borderRadius: AppRadii.m),
          const SizedBox(height: 24),
          const RvSkeleton(width: 100, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, __) => const RvSkeleton(
                width: double.infinity,
                height: 68,
                borderRadius: 14),
          ),
        ],
      ),
    );
  }
}