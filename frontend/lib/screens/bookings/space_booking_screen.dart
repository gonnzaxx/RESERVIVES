import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/espacios_provider.dart';
import 'package:reservives/providers/navigation_provider.dart';
import 'package:reservives/providers/reservas_provider.dart';
import 'package:reservives/providers/tramos_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDate = getInitialDate(DateTime.now());
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _onBook() async {
    if (_selectedTramoId == null) {
      HapticFeedback.heavyImpact();
      setState(() => _shakeTrigger++);
      return;
    }

    final success = await ref.read(crearReservaProvider.notifier).crearReserva(
      widget.espacioId,
      _selectedDate,
      _selectedTramoId!,
      _observacionesCtrl.text.isEmpty ? null : _observacionesCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      _confettiController.play();
      final reserva = ref.read(crearReservaProvider).value;
      if (reserva == null) {
        context.goNamed('servicios');
        return;
      }

      final isPending = reserva.isPendiente;

      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isPending ? AppColors.warning : AppColors.success).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                  size: 54,
                  color: isPending ? AppColors.warning : AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPending ? 'Solicitud enviada' : '¡Reserva completada!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isPending
                    ? 'Tu solicitud para "${reserva.nombreEspacio}" está pendiente de revisión por el administrador.'
                    : 'Disfruta de "${reserva.nombreEspacio}". Podrás ver los detalles en tu perfil.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: RvPrimaryButton(
                  onTap: () => Navigator.pop(context),
                  label: context.tr('generic.understood'),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      ref.read(servicesTabIndexProvider.notifier).setIndex(2);
      context.goNamed('servicios');
      return;
    }

    final error = ref.read(crearReservaProvider).error;
    RvAlerts.error(context, toFriendlyErrorMessage(error, fallback: context.tr('booking.error')));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;
    final espacioAsync = ref.watch(espacioDetalleProvider(widget.espacioId));
    final user = ref.watch(authProvider).user;
    final bookingState = ref.watch(crearReservaProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: espacioAsync.when(
                  data: (espacio) {
                    final isAlumno = user?.isAlumno ?? true;
                    final costo = espacio.precioTokens;
                    final costoEfectivo = isAlumno ? costo : 0;
                    final tieneTokens = isAlumno ? (user?.tokens ?? 0) >= costoEfectivo : true;
                    final maxAdvance = _maxBookingDate();
                    final effectiveLastDate = DateTime.now().add(Duration(days: espacio.antelacionDias)).isBefore(maxAdvance)
                        ? DateTime.now().add(Duration(days: espacio.antelacionDias))
                        : maxAdvance;
                    final exceedsMaxWindow = _selectedDate.isAfter(effectiveLastDate);

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, isWeb ? 24 : 10, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RvGhostIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
                              const SizedBox(width: 12),
                              Text(context.tr('booking.title'), style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildInfoCard(espacio, isAlumno, costo),
                          const SizedBox(height: 24),

                          Text(context.tr('booking.date'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildDateSelector(effectiveLastDate),

                          const SizedBox(height: 24),
                          Text('Tramo horario', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _TramoSelector(
                            espacioId: widget.espacioId,
                            selectedDate: _selectedDate,
                            selectedTramoId: _selectedTramoId,
                            onTramoSelected: (id) => setState(() => _selectedTramoId = id),
                          ),

                          const SizedBox(height: 24),
                          Text(context.tr('booking.notes'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildNotesField(),

                          const SizedBox(height: 24),
                          _buildBanners(tieneTokens, exceedsMaxWindow, espacio.requiereAutorizacion),

                          const SizedBox(height: 20),
                          Align(
                            alignment: isWeb ? Alignment.centerRight : Alignment.center,
                            child: _buildProgressBarButton(bookingState.isLoading, tieneTokens, exceedsMaxWindow),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => _buildSkeleton(context, isWeb),
                  error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(espacioDetalleProvider(widget.espacioId)))),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [AppColors.primaryBlue, AppColors.accentPurple, AppColors.success, Colors.yellow],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarButton(bool isLoading, bool tieneTokens, bool exceedsMaxWindow) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    final bool isDisabled = !tieneTokens || _selectedTramoId == null || _isWeekend(_selectedDate) || exceedsMaxWindow;

    return GestureDetector(
      onTap: (isLoading || isDisabled)
          ? () {
        HapticFeedback.heavyImpact();
        setState(() => _shakeTrigger++);
        if (_selectedTramoId == null && !isLoading) RvAlerts.error(context, 'Selecciona un tramo horario.');
      }
          : () async {
        _onBook();
      },
      child: LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = constraints.maxWidth;

            return Container(
              width: isWeb ? 250 : double.infinity,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.shade300 : AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDisabled ? Colors.transparent : AppColors.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: isLoading ? const Duration(milliseconds: 1500) : Duration.zero,
                    curve: Curves.linear,
                    width: isLoading ? buttonWidth : 0,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isDisabled ? Colors.grey.shade400 : AppColors.primaryBlue,
                    ),
                  ),
                  Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isLoading
                            ? Colors.white
                            : (isDisabled ? Colors.grey.shade600 : AppColors.primaryBlue),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      child: Text(
                        isLoading ? 'PROCESANDO...' : context.tr('booking.confirm').toUpperCase(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    ).animate(target: _shakeTrigger.toDouble()).shake(duration: 400.ms, hz: 6);
  }

  Widget _buildInfoCard(dynamic espacio, bool isAlumno, int costo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RvBadge(label: espacio.tipo.value, icon: Icons.place_rounded, color: AppColors.accentPurple),
              const Spacer(),
              Text(
                isAlumno ? '$costo ${context.tr('booking.tokens')}' : context.tr('booking.freeForTeachers'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(espacio.nombre, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.tr('booking.flowSubtitle'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildDateSelector(DateTime lastDate) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft(context),
      ),
      child: _BookingField(
        label: "Fecha de reserva",
        value: DateFormat('EEEE d MMMM', 'es').format(_selectedDate),
        icon: Icons.calendar_today_rounded,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now(),
            lastDate: lastDate,
            selectableDayPredicate: (date) => !_isWeekend(date),
          );
          if (date != null) setState(() { _selectedDate = date; _selectedTramoId = null; });
        },
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft(context),
      ),
      child: TextField(
        controller: _observacionesCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: context.tr('booking.notesHint'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBanners(bool tieneTokens, bool exceedsMaxWindow, bool requiereAut) {
    return Column(
      children: [
        if (!tieneTokens) _InfoBannerWrapper(icon: Icons.error_outline_rounded, text: context.tr('booking.notEnoughTokens'), color: AppColors.error),
        if (_isWeekend(_selectedDate)) _InfoBannerWrapper(icon: Icons.event_busy_rounded, text: context.tr('booking.weekendNotAllowed'), color: AppColors.error),
        if (exceedsMaxWindow) _InfoBannerWrapper(icon: Icons.calendar_month_rounded, text: context.tr('booking.maxWeekError'), color: AppColors.warning),
        if (tieneTokens && requiereAut) _InfoBannerWrapper(icon: Icons.hourglass_top_rounded, text: context.tr('booking.pendingApproval'), color: AppColors.warning),
      ],
    );
  }

  bool _isWeekend(DateTime date) => date.weekday == 6 || date.weekday == 7;
  DateTime _maxBookingDate() => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 7));

  Widget _buildSkeleton(BuildContext context, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RvSkeleton(width: 200, height: 30),
          const SizedBox(height: 20),
          const RvSkeleton(width: double.infinity, height: 150, borderRadius: 20),
          const SizedBox(height: 30),
          GridView.builder(
            shrinkWrap: true,
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 64, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemBuilder: (_, __) => const RvSkeleton(width: double.infinity, height: 64, borderRadius: 16),
          ),
        ],
      ),
    );
  }
}

class _TramoSelector extends ConsumerWidget {
  final String espacioId;
  final DateTime selectedDate;
  final String? selectedTramoId;
  final ValueChanged<String> onTramoSelected;

  const _TramoSelector({
    required this.espacioId,
    required this.selectedDate,
    required this.selectedTramoId,
    required this.onTramoSelected
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponibilidadAsync = ref.watch(disponibilidadEspacioProvider((espacioId: espacioId, fecha: selectedDate)));

    return disponibilidadAsync.when(
      data: (tramos) {
        // 1. Filtramos los permitidos
        final tramosVisibles = tramos.where((t) => t.permitido).toList();

        if (tramosVisibles.isEmpty) return const _TramoEmptyState(mensaje: 'No hay tramos disponibles.');

        // 2. ORDENAMOS cronológicamente por hora de inicio
        tramosVisibles.sort((a, b) => a.tramo.horaInicio.compareTo(b.tramo.horaInicio));

        // 3. Agrupamos por turno una vez ya están ordenados
        final manana = tramosVisibles.where((t) => t.tramo.turno == 'MAÑANA').toList();
        final tarde = tramosVisibles.where((t) => t.tramo.turno == 'TARDE').toList();

        return Column(
          children: [
            if (manana.isNotEmpty) ...[
              _buildHeader('Turno Mañana', Icons.wb_sunny_outlined, context),
              const SizedBox(height: 12),
              _buildGrid(manana)
            ],
            if (tarde.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildHeader('Turno Tarde', Icons.nights_stay_outlined, context),
              const SizedBox(height: 12),
              _buildGrid(tarde)
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _TramoEmptyState(
          mensaje: 'Error al cargar tramos',
          isError: true,
          onRetry: () => ref.invalidate(disponibilidadEspacioProvider)
      ),
    );
  }

  // Los métodos _buildHeader y _buildGrid se mantienen igual...
  Widget _buildHeader(String title, IconData icon, BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildGrid(List<TramoDisponibilidad> items) {
    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth > 500 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 68,
        ),
        itemBuilder: (context, i) => _TramoChip(
          disponibilidad: items[i],
          isSelected: selectedTramoId == items[i].tramo.id,
          onTap: items[i].disponible ? () => onTramoSelected(items[i].tramo.id) : null,
        ),
      );
    });
  }
}

class _TramoChip extends StatelessWidget {
  final TramoDisponibilidad disponibilidad;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TramoChip({required this.disponibilidad, required this.isSelected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReservado = disponibilidad.reservado;
    final esPasado = disponibilidad.estado == EstadoTramo.horarioPasado;
    final bool isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : (isEnabled ? theme.cardColor : theme.dividerColor.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.2), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              disponibilidad.tramo.rangoHorario,
              style: TextStyle(
                  color: isSelected ? Colors.white : (isEnabled ? theme.textTheme.bodyLarge?.color : theme.disabledColor),
                  fontWeight: FontWeight.w900,
                  fontSize: 14
              ),
            ),
            const SizedBox(height: 2),
            _buildSubtitle(theme),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03));
  }

  Widget _buildSubtitle(ThemeData theme) {
    final style = TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : theme.disabledColor, fontWeight: FontWeight.w500);
    if (disponibilidad.reservado) return Text('Ocupado', style: style);
    if (disponibilidad.estado == EstadoTramo.horarioPasado) return Text('Pasado', style: style);
    if (isSelected) return const Text('Seleccionado', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold));
    return Text(disponibilidad.tramo.nombre, style: style);
  }
}

class _TramoEmptyState extends StatelessWidget {
  final String mensaje;
  final bool isError;
  final VoidCallback? onRetry;
  const _TramoEmptyState({required this.mensaje, this.isError = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16)
      ),
      child: Column(children: [
        Icon(isError ? Icons.error_outline : Icons.event_busy, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(mensaje, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]
      ]),
    );
  }
}

class _InfoBannerWrapper extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBannerWrapper({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoBanner(icon: icon, text: text, color: color));
  }
}

class _BookingField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _BookingField({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}