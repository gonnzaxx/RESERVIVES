import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/servicio_provider.dart';
import 'package:reservives/providers/tramos_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';

Future<void> showServiceBookingSheet(
    BuildContext context,
    ServicioInstituto servicio,
    ) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ServiceBookingSheet(servicio: servicio),
  );
}

class ServiceBookingSheet extends ConsumerStatefulWidget {
  final ServicioInstituto servicio;

  const ServiceBookingSheet({super.key, required this.servicio});

  @override
  ConsumerState<ServiceBookingSheet> createState() => _ServiceBookingSheetState();
}

class _ServiceBookingSheetState extends ConsumerState<ServiceBookingSheet> {
  late DateTime _selectedDate;
  String? _selectedTramoId;
  bool _isSubmitting = false;
  late final TextEditingController _obsCtrl;

  @override
  void initState() {
    super.initState();
    _selectedDate = getInitialDate(DateTime.now());
    _obsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final maxDate = DateTime.now().add(Duration(days: widget.servicio.antelacionDias));
    final exceedsMaxWindow = _selectedDate.isAfter(maxDate);

    final label = user?.isAlumno == true
        ? 'Confirmar · ${widget.servicio.precioTokens} tokens'
        : context.tr('booking.confirm');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: AbsorbPointer(
              absorbing: _isSubmitting,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 46, height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(widget.servicio.nombre,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona el día y tramo horario para tu reserva.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 24),

                  SheetSelector(
                    icon: Icons.calendar_today_rounded,
                    label: context.tr('services.date'),
                    value: DateFormat('EEEE d MMM', 'es').format(_selectedDate),
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: getInitialDate(_selectedDate.isBefore(now) ? now : _selectedDate),
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: maxDate,
                        selectableDayPredicate: (date) => !_isWeekend(date),
                      );
                      if (date != null && mounted) {
                        setState(() {
                          _selectedDate = date;
                          _selectedTramoId = null;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 32),
                  Text('Tramos disponibles',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  _TramoServiceSelector(
                    servicioId: widget.servicio.id,
                    selectedDate: _selectedDate,
                    selectedTramoId: _selectedTramoId,
                    onTramoSelected: (id) => setState(() => _selectedTramoId = id),
                  ),

                  const SizedBox(height: 24),
                  if (_isWeekend(_selectedDate)) ...[
                    const InfoBanner(icon: Icons.event_busy_rounded, text: 'Fines de semana no permitidos.', color: AppColors.error),
                    const SizedBox(height: 12),
                  ],
                  if (exceedsMaxWindow) ...[
                    InfoBanner(
                      icon: Icons.calendar_month_rounded,
                      text: 'Máximo ${widget.servicio.antelacionDias} días de antelación.',
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      hintText: 'Añade detalles si lo necesitas',
                    ),
                  ),
                  const SizedBox(height: 32),

                  RvPrimaryButton(
                    onTap: _isSubmitting || _isWeekend(_selectedDate) || exceedsMaxWindow || _selectedTramoId == null
                        ? null
                        : () async {
                      setState(() => _isSubmitting = true);
                      final success = await ref.read(reservarServicioProvider.notifier).reservar(
                        widget.servicio.id,
                        _selectedDate,
                        _selectedTramoId!,
                        _obsCtrl.text.isEmpty ? null : _obsCtrl.text,
                      );

                      if (!mounted) return;
                      if (success) {
                        Navigator.of(context).pop();
                        RvAlerts.success(context, context.tr('services.application.success'));
                      } else {
                        final error = ref.read(reservarServicioProvider).error;
                        RvAlerts.error(context, toFriendlyErrorMessage(error, fallback: context.tr('services.error.booking')));
                      }
                      if (mounted) setState(() => _isSubmitting = false);
                    },
                    isLoading: _isSubmitting,
                    label: label,
                  ),
                  const SizedBox(height: 40), // Espacio extra para el teclado/scroll
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TramoServiceSelector extends ConsumerWidget {
  final String servicioId;
  final DateTime selectedDate;
  final String? selectedTramoId;
  final ValueChanged<String> onTramoSelected;

  const _TramoServiceSelector({
    required this.servicioId,
    required this.selectedDate,
    required this.selectedTramoId,
    required this.onTramoSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponibilidadAsync = ref.watch(
      disponibilidadServicioProvider((servicioId: servicioId, fecha: selectedDate)),
    );

    return disponibilidadAsync.when(
      data: (tramos) {
        // 1. Filtramos los tramos permitidos
        final tramosVisibles = tramos.where((t) => t.permitido).toList();

        if (tramosVisibles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No hay tramos disponibles para este día.',
                  style: TextStyle(color: Theme.of(context).disabledColor)),
            ),
          );
        }

        // 2. ORDENAMOS cronológicamente por la hora de inicio del tramo
        tramosVisibles.sort((a, b) => a.tramo.horaInicio.compareTo(b.tramo.horaInicio));

        // 3. SEPARACIÓN POR TURNOS (Lógica de mañana y tarde)
        final manana = tramosVisibles.where((t) => t.tramo.turno == 'MAÑANA').toList();
        final tarde = tramosVisibles.where((t) => t.tramo.turno == 'TARDE').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manana.isNotEmpty) ...[
              _buildTurnoHeader(context, 'Turno Mañana', Icons.wb_sunny_outlined),
              const SizedBox(height: 12),
              _buildGrid(manana),
            ],
            if (tarde.isNotEmpty) ...[
              if (manana.isNotEmpty) const SizedBox(height: 24),
              _buildTurnoHeader(context, 'Turno Tarde', Icons.nights_stay_outlined),
              const SizedBox(height: 12),
              _buildGrid(tarde),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(disponibilidadServicioProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Error al cargar tramos'),
        ),
      ),
    );
  }

  // Métodos auxiliares _buildTurnoHeader y _buildGrid (se mantienen igual)...
  Widget _buildTurnoHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)
        ),
      ],
    );
  }

  Widget _buildGrid(List<TramoDisponibilidad> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
          itemBuilder: (context, index) {
            final t = items[index];
            return _TramoMiniChip(
              disponibilidad: t,
              isSelected: selectedTramoId == t.tramo.id,
              onTap: t.disponible ? () => onTramoSelected(t.tramo.id) : null,
            );
          },
        );
      },
    );
  }
}

class _TramoMiniChip extends StatelessWidget {
  final TramoDisponibilidad disponibilidad;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TramoMiniChip({
    required this.disponibilidad,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEnabled = onTap != null;

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      bgColor = theme.colorScheme.primary;
      textColor = Colors.white;
      borderColor = theme.colorScheme.primary;
    } else if (!isEnabled) {
      bgColor = theme.dividerColor.withOpacity(0.05);
      textColor = theme.disabledColor.withOpacity(0.4);
      borderColor = theme.dividerColor.withOpacity(0.1);
    } else {
      bgColor = theme.cardColor;
      textColor = theme.textTheme.bodyMedium!.color!;
      borderColor = theme.dividerColor.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              disponibilidad.tramo.rangoHorario,
              style: TextStyle(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 14
              ),
            ),
            const SizedBox(height: 2),
            _buildStatusText(theme, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(ThemeData theme, Color color) {
    final style = TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.w500);
    if (disponibilidad.reservado) return Text('Ocupado', style: style);
    if (disponibilidad.estado == EstadoTramo.horarioPasado) return Text('Pasado', style: style);
    if (isSelected) return const Text('Seleccionado', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold));
    return Text(disponibilidad.tramo.nombre, style: style);
  }
}