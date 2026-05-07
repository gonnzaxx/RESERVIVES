import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/models/admin_history_item.dart';
import 'package:reservives/providers/admin_history_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/i10n/app_localizations.dart';

class AdminHistorialScreen extends ConsumerWidget {
  const AdminHistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(adminHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: RvPageHeader(
                title: context.tr('admin.record.title'),
                eyebrow: context.tr('admin.record.eyebrow'),
                trailing: Row(
                  children: [
                    _HeaderAction(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(adminHistoryProvider),
                    ),
                    const SizedBox(width: 8),
                    _HeaderAction(
                      icon: Icons.filter_list_off_rounded,
                      onTap: () => ref.read(adminHistoryFiltersProvider.notifier).clear(),
                    ),
                  ],
                ),
              ),
            ),
            const _AdminFilterPanel(),

            const SizedBox(height: 16),

            Expanded(
              child: bookingsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: RvEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        title: context.tr('admin.record.noData'),
                        subtitle: context.tr('admin.record.noDataText'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _AdminHistoryCard(item: items[index]),
                  );
                },
                loading: () => _buildLoadingSkeleton(),
                error: (err, _) => Center(
                  child: RvApiErrorState(
                    onRetry: () => ref.invalidate(adminHistoryProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _LiquidContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RvSkeleton(width: MediaQuery.of(context).size.width * 0.4, height: 20),
                const RvSkeleton(width: 60, height: 18, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 12),
            const RvSkeleton(width: 150, height: 14),
            const SizedBox(height: 8),
            const RvSkeleton(width: 200, height: 12),
            const SizedBox(height: 16),
            const RvSkeleton(width: 180, height: 14),
          ],
        ),
      ),
    );
  }
}

class _AdminFilterPanel extends ConsumerWidget {
  const _AdminFilterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(adminHistoryFiltersProvider);
    final theme = Theme.of(context);
    final dayFormat = DateFormat('dd MMM');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _LiquidContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: 20,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: context.tr('admin.record.searchBar.text'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha:0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                ref.read(adminHistoryFiltersProvider.notifier).setFilters(
                  AdminHistoryFilters(
                    day: filters.day,
                    month: filters.month,
                    year: filters.year,
                    tipo: filters.tipo,
                    estado: filters.estado,
                    usuarioQ: value.trim().isEmpty ? null : value.trim(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: filters.day == null ? context.tr('admin.record.filter.day') : dayFormat.format(filters.day!),
                    icon: Icons.calendar_today_rounded,
                    isActive: filters.day != null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                        initialDate: filters.day ?? DateTime.now(),
                      );
                      if (picked != null) {
                        ref.read(adminHistoryFiltersProvider.notifier).setFilters(
                            AdminHistoryFilters(day: picked, tipo: filters.tipo, estado: filters.estado, usuarioQ: filters.usuarioQ)
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: filters.tipo ?? context.tr('admin.record.filter.type'),
                    icon: Icons.category_rounded,
                    isActive: filters.tipo != null,
                    onTap: () => _showPicker(
                        context,
                        ['ESPACIO', 'SERVICIO'],
                        filters.tipo,
                            (val) {
                          ref.read(adminHistoryFiltersProvider.notifier).setFilters(
                              AdminHistoryFilters(day: filters.day, tipo: val, estado: filters.estado, usuarioQ: filters.usuarioQ)
                          );
                        }
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: filters.estado ?? context.tr('admin.record.filter.state'),
                    icon: Icons.info_outline_rounded,
                    isActive: filters.estado != null,
                    onTap: () => _showPicker(
                        context,
                        ['PENDIENTE', 'APROBADA', 'RECHAZADA', 'CANCELADA'],
                        filters.estado,
                            (val) {
                          ref.read(adminHistoryFiltersProvider.notifier).setFilters(
                              AdminHistoryFilters(day: filters.day, tipo: filters.tipo, estado: val, usuarioQ: filters.usuarioQ)
                          );
                        }
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, List<String> options, String? currentSelection, Function(String) onSelect) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Título de sección
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Seleccionar',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                            letterSpacing: 0.5,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (currentSelection != null)
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Text(
                              'Limpiar',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Opciones
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    child: Column(
                      children: options.map((opt) {
                        final isSelected = opt == currentSelection;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () {
                              onSelect(opt);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 18),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(
                                    isDark ? 0.18 : 0.08)
                                    : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.02)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                      : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05)),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icono de estado
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.hintColor.withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    opt,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.textTheme.bodyLarge?.color,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHistoryCard extends ConsumerWidget {
  final AdminHistoryItem item;
  const _AdminHistoryCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(item.estado);
    final isCancelable = item.estado != 'CANCELADA' && item.estado != 'RECHAZADA';

    return _LiquidContainer(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.nombreRecurso ?? 'Reserva',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _TypeBadge(type: item.tipoReserva),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(item.nombreUsuario ?? 'Anónimo', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (item.emailUsuario != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 2),
                        child: Text(item.emailUsuario!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${DateFormat('dd/MM/yy HH:mm').format(item.fechaInicio)} - ${DateFormat('HH:mm').format(item.fechaFin)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (item.observaciones?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.observaciones!,
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                    if (isCancelable) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _handleCancel(context, ref),
                          icon: const Icon(Icons.block_flipped, size: 16),
                          label: Text(context.tr('admin.record.cancel.booking')),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: theme.colorScheme.error.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          final isValidReason = reasonCtrl.text.trim().length >= 3;
          final theme = Theme.of(dialogCtx);

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: RvSurfaceCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_busy_rounded,
                          color: AppColors.error, size: 32),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      context.tr('admin.record.cancel.booking'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      context.tr('admin.record.cancel.booking.confirm.text'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: context.tr('admin.record.cancel.booking.example'),
                        labelText: context.tr('admin.record.cancel.booking.label'),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                        ),
                        errorText: !isValidReason && reasonCtrl.text.isNotEmpty
                            ? 'Min. 3 caracteres'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(context.tr('admin.record.cancel.booking.back'),
                                style: TextStyle(color: theme.hintColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RvPrimaryButton(
                            backgroundColor: AppColors.error,
                            onTap: isValidReason
                                ? () => Navigator.pop(dialogCtx, true)
                                : null,
                            label: context.tr('admin.record.cancel.booking.short'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (ok == true) {
      try {
        await ref.read(apiClientProvider).post(
          '/admin/bookings/${item.id}/cancel',
          body: {
            'tipo_reserva': item.tipoReserva,
            'motivo': reasonCtrl.text.trim()
          },
        );
        ref.invalidate(adminHistoryProvider);
        if (context.mounted) RvAlerts.success(context, 'Reserva anulada correctamente');
      } catch (e) {
        if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
    reasonCtrl.dispose();
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'APROBADA': return Colors.greenAccent[700]!;
      case 'PENDIENTE': return Colors.orangeAccent;
      case 'RECHAZADA':
      case 'CANCELADA': return Colors.redAccent;
      default: return Colors.grey;
    }
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _LiquidContainer(
        padding: EdgeInsets.zero,
        borderRadius: 12,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 14, color: isActive ? Colors.white : theme.colorScheme.primary),
      label: Text(label),
      backgroundColor: isActive ? theme.colorScheme.primary : Colors.transparent,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : theme.textTheme.bodyMedium?.color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type == 'SERVICIO' ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: type == 'SERVICIO' ? Colors.blue : Colors.purple,
        ),
      ),
    );
  }
}

class _LiquidContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const _LiquidContainer({required this.child, this.borderRadius = 24, this.color, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}