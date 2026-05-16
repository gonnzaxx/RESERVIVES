// Pantalla de reserva recurrente para un espacio.
// La solicitud queda pendiente de aprobación hasta que un administrador la revise.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/providers/spaces_provider.dart';
import 'package:reservives/providers/time_slots_provider.dart';
import 'package:reservives/providers/reservas_recurrentes_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';

import 'package:reservives/models/tramo_horario.dart';

class RecurringBookingScreen extends ConsumerStatefulWidget {
  final String espacioId;

  const RecurringBookingScreen({super.key, required this.espacioId});

  @override
  ConsumerState<RecurringBookingScreen> createState() =>
      _RecurringBookingScreenState();
}

enum PlanDuracion {
  dias15('DIAS_15', 'recurring.plan.dias15'),
  mes1('MES_1', 'recurring.plan.mes1'),
  trimestre3('TRIMESTRE_3', 'recurring.plan.trimestre3');

  final String apiValue;
  final String trKey;
  const PlanDuracion(this.apiValue, this.trKey);
}

class _RecurringBookingScreenState
    extends ConsumerState<RecurringBookingScreen> {
  late DateTime _fechaInicio;
  String? _selectedTramoId;
  PlanDuracion _planDuracion = PlanDuracion.trimestre3;
  final TextEditingController _obsCtrl = TextEditingController();

  // Inicializa la fecha de inicio en el próximo día laborable
  @override
  void initState() {
    super.initState();
    _fechaInicio = _nextWeekday(DateTime.now());
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  // Devuelve el siguiente día laborable a partir de la fecha dada (salta fines de semana)
  DateTime _nextWeekday(DateTime from) {
    DateTime d = from.add(const Duration(days: 1));
    while (d.weekday >= 6) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // Devuelve true si el día es fin de semana
  bool _isWeekend(DateTime d) => d.weekday == 6 || d.weekday == 7;

  // Devuelve el texto explicativo del plan de duración seleccionado
  String _buildPlanExplanation(BuildContext context) {
    switch (_planDuracion) {
      case PlanDuracion.dias15:
        return context.tr('recurring.plan.explanation.dias15');
      case PlanDuracion.mes1:
        return context.tr('recurring.plan.explanation.mes1');
      case PlanDuracion.trimestre3:
        return context.tr('recurring.plan.explanation.trimestre3');
    }
  }

  // Valida los campos y envía la solicitud de reserva recurrente
  Future<void> _submit() async {
    if (_selectedTramoId == null) {
      HapticFeedback.heavyImpact();
      RvAlerts.error(context, context.tr('recurring.error.selectSlot'));
      return;
    }

    final success = await ref
        .read(crearReservaRecurrenteProvider.notifier)
        .crear(
          espacioId: widget.espacioId,
          tramoId: _selectedTramoId!,
          duracionPlan: _planDuracion.apiValue,
          fechaInicio: _fechaInicio,
          observaciones: _obsCtrl.text.isEmpty ? null : _obsCtrl.text,
        );

    if (!mounted) return;

    if (success) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _SuccessSheet(
          planDuracion: _planDuracion,
          onClose: () => Navigator.pop(context),
        ),
      );
      if (mounted) context.goNamed('espacios');
    } else {
      final error = ref.read(crearReservaRecurrenteProvider).error;
      RvAlerts.error(
        context,
        toFriendlyErrorMessage(error, fallback: context.tr('recurring.error.createFailed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = AppConstants.isWideScreen(context);
    final espacioAsync = ref.watch(espacioDetalleProvider(widget.espacioId));
    final bookingState = ref.watch(crearReservaRecurrenteProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: espacioAsync.when(
              data: (espacio) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isWeb ? 24 : 10, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RvGhostIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.goNamed('espacios'),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('recurring.title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadii.l),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RvBadge(
                            label: espacio.tipo.value,
                            icon: Icons.repeat_rounded,
                            color: AppColors.accentPurple,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            espacio.nombre,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(context.tr('recurring.plan.title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _PlanDuracionPicker(
                      selected: _planDuracion,
                      onChanged: (t) => setState(() => _planDuracion = t),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _buildPlanExplanation(context),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(context.tr('recurring.firstBooking.title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _DateField(
                      value: _fechaInicio,
                      label: context.tr('recurring.startDate.label'),
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fechaInicio,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          selectableDayPredicate: (d) => !_isWeekend(d),
                        );
                        if (d != null) {
                          setState(() {
                            _fechaInicio = d;
                            _selectedTramoId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(context.tr('recurring.timeSlot.title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _TramoPickerSimple(
                      espacioId: widget.espacioId,
                      fecha: _fechaInicio,
                      selected: _selectedTramoId,
                      onSelected: (id) => setState(() => _selectedTramoId = id),
                    ),
                    const SizedBox(height: 24),

                    Text(context.tr('recurring.observations.title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.soft(context),
                      ),
                      child: TextField(
                        controller: _obsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: context.tr('recurring.observations.hint'),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('recurring.pendingWarning'),
                              style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: RvPrimaryButton(
                        onTap: bookingState.isLoading ? null : _submit,
                        label: bookingState.isLoading
                            ? context.tr('recurring.submitting')
                            : context.tr('recurring.submit'),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: RvApiErrorState(
                  onRetry: () =>
                      ref.invalidate(espacioDetalleProvider(widget.espacioId)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanDuracionPicker extends StatelessWidget {
  final PlanDuracion selected;
  final ValueChanged<PlanDuracion> onChanged;

  const _PlanDuracionPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PlanDuracion.values.map((t) {
        final isSelected = t == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  context.tr(t.trKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateField(
      {required this.value,
      required this.label,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft(context),
      ),
      child: InkWell(
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
                    Text(
                      value != null
                          ? DateFormat('EEEE d MMMM yyyy', 'es').format(value!)
                          : context.tr('recurring.startDate.placeholder'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: value == null
                            ? Theme.of(context).disabledColor
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TramoPickerSimple extends ConsumerWidget {
  final String espacioId;
  final DateTime fecha;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TramoPickerSimple({
    required this.espacioId,
    required this.fecha,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      disponibilidadEspacioProvider((espacioId: espacioId, fecha: fecha)),
    );

    return async.when(
      data: (tramos) {
        final disponibles =
        tramos.where((t) => t.permitido && !t.reservado && t.estado != EstadoTramo.horarioPasado).toList()
          ..sort(
                  (a, b) => a.tramo.horaInicio.compareTo(b.tramo.horaInicio));

        if (disponibles.isEmpty) {
          return _EmptyState();
        }

        return _TramoGrid(
          tramos: disponibles,
          selected: selected,
          onSelected: onSelected,
        );
      },
      loading: () => const _LoadingState(),
      error: (_, __) => RvApiErrorState(
        onRetry: () => ref.invalidate(disponibilidadEspacioProvider),
      ),
    );
  }
}

// Empty state

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: Theme.of(context).disabledColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('recurring.noAvailability.title'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('recurring.noAvailability.subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).disabledColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Loading state

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: List.generate(2, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 12 : 0),
            child: Row(
              children: List.generate(2, (col) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: col == 0 ? 0 : 12),
                    child: RvSkeleton(height: 72, borderRadius: 16),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

// Grid de tramos

class _TramoGrid extends StatelessWidget {
  final List<TramoDisponibilidad> tramos;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TramoGrid({
    required this.tramos,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWide ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 72,
      ),
      itemCount: tramos.length,
      itemBuilder: (context, index) {
        final d = tramos[index];
        final isSelected = selected == d.tramo.id;
        return _TramoCard(
          tramo: d,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            onSelected(d.tramo.id);
          },
        );
      },
    );
  }
}

// Tarjeta de tramo

class _TramoCard extends StatelessWidget {
  final TramoDisponibilidad tramo;
  final bool isSelected;
  final VoidCallback onTap;

  const _TramoCard({
    required this.tramo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores según estado
    final Color bgColor;
    final Color borderColor;
    final Color labelColor;
    final Color badgeColor;
    final Color badgeText;

    if (isSelected) {
      bgColor = scheme.primary;
      borderColor = scheme.primary;
      labelColor = Colors.white;
      badgeColor = Colors.white.withValues(alpha: 0.18);
      badgeText = Colors.white;
    } else {
      bgColor = Theme.of(context).cardColor;
      borderColor = Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.15 : 0.1);
      labelColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
      badgeColor = const Color(0xFF2FA888).withValues(alpha: isDark ? 0.15 : 0.1);
      badgeText = const Color(0xFF2FA888);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icono de reloj
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.15)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(width: 10),

              // Horario + badge
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tramo.tramo.rangoHorario,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                        color: labelColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.tr('recurring.slot.available'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Check animado al seleccionar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isSelected
                    ? Container(
                  key: const ValueKey('check'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                )
                    : const SizedBox(key: ValueKey('empty'), width: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final PlanDuracion planDuracion;
  final VoidCallback onClose;

  const _SuccessSheet({required this.planDuracion, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding:
          EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RvSheetHeader(onClose: onClose),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                size: 54, color: AppColors.warning),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('recurring.success.title'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('recurring.success.body'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: RvPrimaryButton(onTap: onClose, label: context.tr('generic.understood')),
          ),
        ],
      ),
    );
  }
}
