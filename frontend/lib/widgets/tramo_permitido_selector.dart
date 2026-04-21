/// RESERVIVES - Widget de Configuración de Tramos Horarios.
///
/// Widget reutilizable (backoffice) para configurar qué tramos horarios
/// están habilitados para un espacio o servicio concreto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/tramos_provider.dart';
import 'package:reservives/services/api_client.dart';

class TramoPermitidoSelector extends ConsumerStatefulWidget {

  final String resourceId;
  final bool isServicio;

  final ValueChanged<List<String>>? onChanged;

  const TramoPermitidoSelector({
    super.key,
    required this.resourceId,
    required this.isServicio,
    this.onChanged,
  });

  @override
  ConsumerState<TramoPermitidoSelector> createState() => TramoPermitidoSelectorState();
}

class TramoPermitidoSelectorState extends ConsumerState<TramoPermitidoSelector> {
  Set<String> _seleccionados = {};
  bool _todosPermitidos = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final api = ref.read(apiClientProvider);
      final endpoint = widget.isServicio
          ? '/tramos/servicio/${widget.resourceId}/tramos-permitidos'
          : '/tramos/espacio/${widget.resourceId}/tramos-permitidos';
      final response = await api.get(endpoint);
      final ids = (response as List).map((e) => e.toString()).toList();
      if (!mounted) return;
      setState(() {
        if (ids.isEmpty) {
          _todosPermitidos = true;
          _seleccionados = {};
        } else {
          _todosPermitidos = false;
          _seleccionados = ids.toSet();
        }
      });
    } catch (_) {
      // Si falla la carga, dejar en "todos permitidos" por defecto
    }
  }

  Future<void> guardar() async {
    try {
      final api = ref.read(apiClientProvider);
      final endpoint = widget.isServicio
          ? '/tramos/servicio/${widget.resourceId}/tramos-permitidos'
          : '/tramos/espacio/${widget.resourceId}/tramos-permitidos';
      final ids = _todosPermitidos ? <String>[] : _seleccionados.toList();
      await api.putJson(endpoint, body: ids);
      widget.onChanged?.call(ids);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tramosAsync = ref.watch(tramosProvider);

    return tramosAsync.when(
      data: (tramos) => _buildContent(context, tramos),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('No se pudieron cargar los tramos.'),
    );
  }

  Widget _buildContent(BuildContext context, List<TramoHorario> tramos) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tramos horarios', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    _todosPermitidos ? 'Todos los tramos disponibles' : '${_seleccionados.length} tramos seleccionados',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_todosPermitidos ? 'Todos' : 'Personalizado', style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: !_todosPermitidos,
                  onChanged: (v) => setState(() {
                    _todosPermitidos = !v;
                    if (_todosPermitidos) _seleccionados.clear();
                  }),
                ),
              ],
            ),
          ],
        ),

        // Selector de tramos individuales (solo visible en modo personalizado)
        if (!_todosPermitidos) ...[
          const SizedBox(height: 12),
          _buildGrupoTramos(context, tramos, 'MAÑANA'),
          const SizedBox(height: 12),
          _buildGrupoTramos(context, tramos, 'TARDE'),
        ],
      ],
    );
  }

  Widget _buildGrupoTramos(BuildContext context, List<TramoHorario> tramos, String turno) {
    final tramosGrupo = tramos.where((t) => t.turno == turno).toList();
    if (tramosGrupo.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              turno == 'MAÑANA' ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Turno $turno',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tramosGrupo.map((t) {
            final isSelected = _seleccionados.contains(t.id);
            return FilterChip(
              label: Text(t.rangoHorario, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              showCheckmark: true,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _seleccionados.add(t.id);
                  } else {
                    _seleccionados.remove(t.id);
                  }
                  widget.onChanged?.call(_seleccionados.toList());
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
