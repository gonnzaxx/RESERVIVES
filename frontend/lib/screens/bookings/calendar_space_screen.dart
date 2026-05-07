library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/calendario_provider.dart';
import 'package:reservives/providers/spaces_provider.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';

const _kSlotHeight = 44.0;
const _kSlotGap = 6.0;
const _kDayColWidth = 88.0;
const _kTeal = Color(0xFF2FA888);

// Pantalla principal

class CalendarSpaceScreen extends ConsumerStatefulWidget {
  final String espacioId;

  const CalendarSpaceScreen({super.key, required this.espacioId});

  @override
  ConsumerState<CalendarSpaceScreen> createState() =>
      _CalendarSpaceScreenState();
}

class _CalendarSpaceScreenState extends ConsumerState<CalendarSpaceScreen> {
  late DateTime _semanaInicio;
  TramoDisponibilidad? _selectedTramo;
  DateTime? _selectedFecha;

  @override
  void initState() {
    super.initState();
    _semanaInicio = _lunesDe(DateTime.now());
  }

  DateTime _lunesDe(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1)).copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );

  bool get _puedeRetroceder {
    final prevLunes = _semanaInicio.subtract(const Duration(days: 7));
    final hoy = DateTime.now();
    return prevLunes.isAfter(
      DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1)),
    );
  }

  void _semanaAnterior() {
    if (!_puedeRetroceder) return;
    setState(() {
      _semanaInicio = _semanaInicio.subtract(const Duration(days: 7));
      _clearSelection();
    });
  }

  void _semanaSiguiente() {
    setState(() {
      _semanaInicio = _semanaInicio.add(const Duration(days: 7));
      _clearSelection();
    });
  }

  void _clearSelection() {
    _selectedTramo = null;
    _selectedFecha = null;
  }

  void _onSlotTap(TramoDisponibilidad t, DateTime fecha) {
    setState(() {
      if (_selectedTramo == t && _selectedFecha == fecha) {
        _clearSelection();
      } else {
        _selectedTramo = t;
        _selectedFecha = fecha;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    final espacioAsync = ref.watch(espacioDetalleProvider(widget.espacioId));
    final semanaFin = _semanaInicio.add(const Duration(days: 6));
    final calendarioAsync = ref.watch(
      calendarioDisponibilidadProvider((
      espacioId: widget.espacioId,
      fechaInicio: _semanaInicio,
      fechaFin: semanaFin,
      )),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, isWeb ? 24 : 10, 20, 0),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.goNamed('servicios');
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: espacioAsync.when(
                          data: (e) => Text(
                            e.nombre,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          loading: () => const RvSkeleton(width: 180, height: 24),
                          error: (_, __) => Text(context.tr('calendar.fallbackTitle')),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _WeekNavigator(
                    semanaInicio: _semanaInicio,
                    semanaFin: semanaFin,
                    puedeRetroceder: _puedeRetroceder,
                    onPrev: _semanaAnterior,
                    onNext: _semanaSiguiente,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _Legend(),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _selectedTramo != null && _selectedFecha != null
                      ? _SelectionBanner(
                    tramo: _selectedTramo!,
                    fecha: _selectedFecha!,
                    espacioId: widget.espacioId,
                    onClear: () => setState(_clearSelection),
                  )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 12),
                Expanded(
                  child: calendarioAsync.when(
                    data: (dias) => _CalendarGrid(
                      dias: dias,
                      espacioId: widget.espacioId,
                      selectedTramo: _selectedTramo,
                      selectedFecha: _selectedFecha,
                      onSlotTap: _onSlotTap,
                    ),
                    loading: () =>
                    const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: RvApiErrorState(
                        onRetry: () =>
                            ref.invalidate(calendarioDisponibilidadProvider),
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
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 18),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  final DateTime semanaInicio;
  final DateTime semanaFin;
  final bool puedeRetroceder;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekNavigator({
    required this.semanaInicio,
    required this.semanaFin,
    required this.puedeRetroceder,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        '${DateFormat('d MMM', 'es').format(semanaInicio)} – '
        '${DateFormat('d MMM yyyy', 'es').format(semanaFin)}';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            enabled: puedeRetroceder,
            onTap: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _NavBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20,
              color: Theme.of(context).iconTheme.color),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: _kTeal, label: context.tr('calendar.legend.available')),
        const SizedBox(width: 14),
        _LegendItem(color: AppColors.error, label: context.tr('calendar.legend.busy')),
        const SizedBox(width: 14),
        _LegendItem(color: Colors.grey, label: context.tr('calendar.legend.notAllowed')),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

class _SelectionBanner extends StatelessWidget {
  final TramoDisponibilidad tramo;
  final DateTime fecha;
  final String espacioId;
  final VoidCallback onClear;

  const _SelectionBanner({
    required this.tramo,
    required this.fecha,
    required this.espacioId,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        '${DateFormat('EEEE d MMM', 'es').format(fecha)}, ${tramo.tramo.horaInicio}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _kTeal.withValues(alpha: 0.08),
          border: Border.all(color: _kTeal.withValues(alpha: 0.35), width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('calendar.selection.label'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _kTeal,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close_rounded, size: 14),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => context.pushNamed(
                'nueva-reserva',
                queryParameters: {
                  'espacioId': espacioId,
                  'fecha': fecha.toIso8601String(),
                  'tramo': tramo.tramo.id,
                },
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kTeal,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(context.tr('calendar.selection.book')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<CalendarioDia> dias;
  final String espacioId;
  final TramoDisponibilidad? selectedTramo;
  final DateTime? selectedFecha;
  final void Function(TramoDisponibilidad, DateTime) onSlotTap;

  const _CalendarGrid({
    required this.dias,
    required this.espacioId,
    required this.selectedTramo,
    required this.selectedFecha,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final diasHabil = dias.where((d) => !d.esFinDeSemana).toList();

    if (diasHabil.isEmpty) {
      return Center(child: Text(context.tr('calendar.noWorkdays')));
    }

    final tramosMap = <String, TramoHorario>{};
    for (final d in diasHabil) {
      for (final t in d.tramos) {
        tramosMap.putIfAbsent(t.tramo.horaInicio, () => t.tramo);
      }
    }
    final tramosOrdenados = tramosMap.values.toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    const kPad = 16.0;
    const kGap = 6.0;
    const kHeaderH = 56.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW =
            constraints.maxWidth - kPad * 2;
        final nDias = diasHabil.length;
        final dayW = (availableW - kGap * (nDias - 1)) / nDias;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, kPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(nDias, (i) {
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : kGap),
                      child: _DayHeader(
                        dia: diasHabil[i],
                        width: dayW,
                        height: kHeaderH,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: kGap),



              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(nDias, (i) {
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : kGap),
                      child: SizedBox(
                        width: dayW,
                        child: _DaySlots(
                          dia: diasHabil[i],
                          tramosOrdenados: tramosOrdenados,
                          selectedTramo: selectedTramo,
                          selectedFecha: selectedFecha,
                          onSlotTap: onSlotTap,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final CalendarioDia dia;
  final double width;
  final double height;

  const _DayHeader({required this.dia, required this.width, this.height = 56});

  bool get _isToday {
    final n = DateTime.now();
    return dia.fecha.year == n.year &&
        dia.fecha.month == n.month &&
        dia.fecha.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _isToday ? _kTeal : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: _isToday
            ? null
            : Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            DateFormat('EEE', 'es').format(dia.fecha).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: _isToday
                  ? Colors.white.withValues(alpha: 0.75)
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            dia.fecha.day.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: _isToday
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySlots extends StatelessWidget {
  final CalendarioDia dia;
  final List<TramoHorario> tramosOrdenados;
  final TramoDisponibilidad? selectedTramo;
  final DateTime? selectedFecha;
  final void Function(TramoDisponibilidad, DateTime) onSlotTap;

  const _DaySlots({
    required this.dia,
    required this.tramosOrdenados,
    required this.selectedTramo,
    required this.selectedFecha,
    required this.onSlotTap,
  });

  bool get _isPast {
    final hoy = DateTime.now();
    return dia.fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  @override
  Widget build(BuildContext context) {
    final mapaTramos = {for (final t in dia.tramos) t.tramo.id: t};

    return SizedBox(
      width: _kDayColWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: tramosOrdenados.map((tramo) {
          final disponibilidad = mapaTramos[tramo.id];

          if (disponibilidad == null || !disponibilidad.permitido) {
            return _SlotCell.blocked(height: _kSlotHeight, gap: _kSlotGap);
          }

          final isSelected = selectedTramo == disponibilidad &&
              selectedFecha?.day == dia.fecha.day &&
              selectedFecha?.month == dia.fecha.month &&
              selectedFecha?.year == dia.fecha.year;

          return _SlotCell(
            disponibilidad: disponibilidad,
            isPast: _isPast,
            isSelected: isSelected,
            onTap: disponibilidad.disponible && !_isPast
                ? () => onSlotTap(disponibilidad, dia.fecha)
                : null,
            height: _kSlotHeight,
            gap: _kSlotGap,
          );
        }).toList(),
      ),
    );
  }
}

// Celda de slot

enum _SlotState { free, busy, past, blocked }

class _SlotCell extends StatelessWidget {
  final TramoDisponibilidad? disponibilidad;
  final bool isPast;
  final bool isSelected;
  final VoidCallback? onTap;
  final double height;
  final double gap;
  final _SlotState _state;

  const _SlotCell({
    required this.disponibilidad,
    required this.isPast,
    required this.isSelected,
    required this.onTap,
    required this.height,
    required this.gap,
  }) : _state = _SlotState.free;

  const _SlotCell.blocked({required this.height, required this.gap})
      : disponibilidad = null,
        isPast = false,
        isSelected = false,
        onTap = null,
        _state = _SlotState.blocked;

  _SlotState get _resolvedState {
    if (_state == _SlotState.blocked) return _SlotState.blocked;
    if (isPast) return _SlotState.past;
    if (disponibilidad?.reservado == true) return _SlotState.busy;
    if (disponibilidad?.disponible == true) return _SlotState.free;
    return _SlotState.blocked;
  }

  @override
  Widget build(BuildContext context) {
    final state = _resolvedState;

    final Color bg;
    final Color textColor;
    final Border? border;
    final BorderStyle borderStyle;

    switch (state) {
      case _SlotState.free:
        bg = _kTeal.withValues(alpha: isSelected ? 0.2 : 0.1);
        textColor = _kTeal;
        border = Border.all(
          color: isSelected ? _kTeal : _kTeal.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 0.5,
        );
        borderStyle = BorderStyle.solid;
        break;
      case _SlotState.busy:
        bg = AppColors.error.withValues(alpha: 0.07);
        textColor = AppColors.error.withValues(alpha: 0.8);
        border = Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 0.5,
        );
        borderStyle = BorderStyle.solid;
        break;
      case _SlotState.past:
        bg = Theme.of(context).dividerColor.withValues(alpha: 0.06);
        textColor = Theme.of(context).disabledColor;
        border = Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          width: 0.5,
        );
        borderStyle = BorderStyle.solid;
        break;
      case _SlotState.blocked:
        bg = Colors.transparent;
        textColor = Theme.of(context).disabledColor;
        border = Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 0.5,
        );
        borderStyle = BorderStyle.solid;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: gap),
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Center(
          child: Text(
            disponibilidad?.tramo.horaInicio ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}