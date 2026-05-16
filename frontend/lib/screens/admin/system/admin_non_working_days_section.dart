import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';

class AdminNonWorkingDaysSection extends StatefulWidget {
  final String initialJson;
  final ValueChanged<String> onChanged;

  const AdminNonWorkingDaysSection({
    super.key,
    required this.initialJson,
    required this.onChanged,
  });

  @override
  State<AdminNonWorkingDaysSection> createState() =>
      _AdminNonWorkingDaysSectionState();
}

class _AdminNonWorkingDaysSectionState
    extends State<AdminNonWorkingDaysSection> {
  final List<DateTime> _dates = [];
  final Set<String> _months = {};
  int _year = DateTime.now().year;

  static final _dateFormat = DateFormat('d MMM yy', 'es');
  static final _monthFormat = DateFormat('MMM', 'es');

  @override
  void initState() {
    super.initState();
    _parseJson(widget.initialJson);
  }

  @override
  void didUpdateWidget(AdminNonWorkingDaysSection old) {
    super.didUpdateWidget(old);
    if (old.initialJson != widget.initialJson && _dates.isEmpty && _months.isEmpty) {
      _parseJson(widget.initialJson);
    }
  }

  void _parseJson(String raw) {
    if (raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final dates = (data['dates'] as List?)?.map((s) => DateTime.parse(s as String)).toList() ?? [];
      final months = Set<String>.from((data['months'] as List?)?.map((s) => s.toString()) ?? []);
      setState(() {
        _dates..clear()..addAll(dates);
        _months..clear()..addAll(months);
      });
    } catch (_) {}
  }

  void _notify() {
    final sorted = List<DateTime>.from(_dates)..sort();
    final sortedMonths = _months.toList()..sort();
    widget.onChanged(jsonEncode({
      'dates': sorted.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList(),
      'months': sortedMonths,
    }));
  }

  Future<void> _addDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    if (_dates.any((x) => _sameDay(x, d))) return;
    setState(() => _dates.add(d));
    _notify();
  }

  void _removeDate(DateTime date) {
    setState(() => _dates.removeWhere((d) => _sameDay(d, date)));
    _notify();
  }

  void _toggleMonth(String key) {
    setState(() => _months.contains(key) ? _months.remove(key) : _months.add(key));
    _notify();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthKey(int y, int m) => '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return RvSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_rounded, size: 18, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('admin.settings.nonWorkingDays.title'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('admin.settings.nonWorkingDays.subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 16),
          _buildDatesRow(theme, primary),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildMonthsBlock(theme, primary),
        ],
      ),
    );
  }

  Widget _buildDatesRow(ThemeData theme, Color primary) {
    final sorted = List<DateTime>.from(_dates)..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('admin.settings.nonWorkingDays.specificDates'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: _addDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 15, color: primary),
                  const SizedBox(width: 3),
                  Text(
                    context.tr('admin.settings.nonWorkingDays.addDate'),
                    style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text(
            context.tr('admin.settings.nonWorkingDays.noDates'),
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sorted
                .map((d) => _chip(
                      label: _dateFormat.format(d),
                      onDelete: () => _removeDate(d),
                      color: primary,
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildMonthsBlock(ThemeData theme, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('admin.settings.nonWorkingDays.fullMonths'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _year--),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left_rounded, size: 18)),
            ),
            SizedBox(
              width: 42,
              child: Text('$_year', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            InkWell(
              onTap: () => setState(() => _year++),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_right_rounded, size: 18)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Grid adaptativo: 6 columnas normalmente, 4 en espacios muy estrechos
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth > 240 ? 6 : 4;
          final gap = 5.0;
          final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;
          final cellH = (cellW / 2.2).clamp(22.0, 32.0);
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(12, (i) {
              final month = i + 1;
              final key = _monthKey(_year, month);
              final selected = _months.contains(key);
              final label = _monthFormat.format(DateTime(_year, month)).toUpperCase();
              return _MonthCell(
                label: label,
                selected: selected,
                color: primary,
                width: cellW,
                height: cellH,
                onTap: () => _toggleMonth(key),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _chip({required String label, required VoidCallback onDelete, required Color color}) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      deleteIcon: Icon(Icons.close_rounded, size: 13, color: color),
      onDeleted: onDelete,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _MonthCell({
    required this.label,
    required this.selected,
    required this.color,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
