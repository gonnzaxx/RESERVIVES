import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/providers/admin_tramos_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/i10n/app_localizations.dart';

class AdminTramosSection extends ConsumerWidget {
  const AdminTramosSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminTramosProvider);

    return RvSurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ref),
          const SizedBox(height: 20),
          if (state.isLoading)
            const _TramosSkeleton()
          else if (state.error != null)
            RvApiErrorState(onRetry: () => ref.read(adminTramosProvider.notifier).loadTramos())
          else if (state.tramos.isEmpty)
              RvEmptyState(
                icon: Icons.schedule_outlined,
                title: context.tr('admin.configuration.slots.emptyTitle'),
                subtitle: context.tr('admin.configuration.slots.emptySubtitle'),
              )
            else
              _buildLista(context, ref, state.tramos),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(context.tr('admin.configuration.slots.title'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              overflow: TextOverflow.ellipsis),
        ),
        RvGhostIconButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.read(adminTramosProvider.notifier).loadTramos(),
        ),
        const SizedBox(width: 4),
        RvGhostIconButton(
          icon: Icons.add_rounded,
          onTap: () => _showTramoDialog(context, ref, null),
        ),
      ],
    );
  }

  Widget _buildLista(BuildContext context, WidgetRef ref, List<TramoHorario> tramos) {
    final manana = tramos.where((t) => t.turno == 'MAÑANA').toList();
    final tarde = tramos.where((t) => t.turno == 'TARDE').toList();
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColumna(context, ref, 'Mañana', Icons.wb_sunny_outlined, manana)),
          const SizedBox(width: 24),
          Expanded(child: _buildColumna(context, ref, 'Tarde', Icons.nights_stay_outlined, tarde)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (manana.isNotEmpty) _buildColumna(context, ref, 'Mañana', Icons.wb_sunny_outlined, manana),
        if (tarde.isNotEmpty) _buildColumna(context, ref, 'Tarde', Icons.nights_stay_outlined, tarde),
      ],
    );
  }

  Widget _buildColumna(BuildContext context, WidgetRef ref, String label, IconData icon, List<TramoHorario> tramos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTurnoHeader(context, label, icon),
        if (tramos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.tr('admin.configuration.slots.emptyTitle'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
          )
        else
          ...tramos.map((t) => _buildTramoTile(context, ref, t)),
      ],
    );
  }

  Widget _buildTurnoHeader(BuildContext context, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 1.2,
              )),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildTramoTile(BuildContext context, WidgetRef ref, TramoHorario tramo) {
    final inactivo = !tramo.activo;
    return Opacity(
      opacity: inactivo ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tramo.esRecreo ? Icons.coffee_rounded : Icons.access_time_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          title: Text(
            tramo.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "${tramo.rangoHorario}${inactivo ? ' · ${context.tr('admin.configuration.slots.inactive')}' : ''}",
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RvGhostIconButton(
                icon: Icons.edit_rounded,
                onTap: () => _showTramoDialog(context, ref, tramo),
              ),
              const SizedBox(width: 8),
              RvGhostIconButton(
                icon: Icons.delete_outline_rounded,
                onTap: () => _confirmarEliminar(context, ref, tramo),
              ),
              const SizedBox(width: 8),
              RvGhostIconButton(
                icon: inactivo ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                onTap: () => _confirmarDesactivar(context, ref, tramo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, WidgetRef ref, TramoHorario tramo) async {
    final ok = await RvAlerts.confirm(
      context,
      title: context.tr('admin.configuration.slots.deleteTitle'),
      content: context.tr('admin.configuration.slots.deleteContent').replaceAll('{nombre}', tramo.nombre),
      confirmLabel: context.tr('admin.configuration.slots.deleteConfirm'),
      isDestructive: true,
    );
    if (ok != true) return;

    final success = await ref.read(adminTramosProvider.notifier).eliminarTramo(tramo.id);
    if (success && context.mounted) {
      RvAlerts.success(context, context.tr('admin.configuration.slots.delete_success'));
    }
  }

  Future<void> _confirmarDesactivar(BuildContext context, WidgetRef ref, TramoHorario tramo) async {
    final accion = tramo.activo ? context.tr('admin.configuration.slots.deactivate') : context.tr('admin.configuration.slots.activate');
    final estado = tramo.activo ? context.tr('admin.configuration.slots.inactive').toLowerCase() : context.tr('admin.configuration.slots.activate').toLowerCase();
    final ok = await RvAlerts.confirm(
      context,
      title: context.tr('admin.configuration.slots.deactivateTitle').replaceAll('{accion}', accion),
      content: context.tr('admin.configuration.slots.deactivateContent').replaceAll('{nombre}', tramo.nombre).replaceAll('{estado}', estado),
      confirmLabel: accion.toUpperCase(),
    );
    if (ok != true) return;

    await ref.read(adminTramosProvider.notifier).editarTramo(tramo.id, {'activo': !tramo.activo});
  }

  void _showTramoDialog(BuildContext context, WidgetRef ref, TramoHorario? tramo) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => _TramoDialog(tramo: tramo, ref: ref),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
}

class _TramosSkeleton extends StatelessWidget {
  const _TramosSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _columnaSkeleton()),
          const SizedBox(width: 24),
          Expanded(child: _columnaSkeleton()),
        ],
      );
    }
    return _columnaSkeleton();
  }

  Widget _columnaSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Turno header skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: const [
              RvSkeleton(width: 14, height: 14, borderRadius: 4),
              SizedBox(width: 8),
              RvSkeleton(width: 60, height: 11, borderRadius: 4),
              SizedBox(width: 8),
              Expanded(child: RvSkeleton(width: double.infinity, height: 1, borderRadius: 1)),
            ],
          ),
        ),
        // Tramo tiles skeleton
        for (int i = 0; i < 4; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                RvSkeleton(width: 34, height: 34, borderRadius: 17),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RvSkeleton(width: 100, height: 13, borderRadius: 5),
                      SizedBox(height: 6),
                      RvSkeleton(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                RvSkeleton(width: 24, height: 24, borderRadius: 6),
                SizedBox(width: 8),
                RvSkeleton(width: 24, height: 24, borderRadius: 6),
                SizedBox(width: 8),
                RvSkeleton(width: 24, height: 24, borderRadius: 6),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TramoDialog extends StatefulWidget {
  final TramoHorario? tramo;
  final WidgetRef ref;
  const _TramoDialog({this.tramo, required this.ref});

  @override
  State<_TramoDialog> createState() => _TramoDialogState();
}

class _TramoDialogState extends State<_TramoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  String _turno = 'MAÑANA';
  bool _esRecreo = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tramo;
    _nombreCtrl = TextEditingController(text: t?.nombre ?? '');
    _numeroCtrl = TextEditingController(text: t?.numero.toString() ?? '');
    _inicioCtrl = TextEditingController(text: t?.horaInicio ?? '');
    _finCtrl = TextEditingController(text: t?.horaFin ?? '');
    _turno = t?.turno ?? 'MAÑANA';
    _esRecreo = t?.esRecreo ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: RvSurfaceCard(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tramo != null ? context.tr('admin.configuration.slots.dialog.edit') : context.tr('admin.configuration.slots.dialog.new'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                ),
                const SizedBox(height: 24),
                _buildFieldLabel(context.tr('admin.configuration.slots.dialog.generalInfo')),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('admin.configuration.slots.dialog.nameLabel'),
                    prefixIcon: const Icon(Icons.label_important_outline_rounded),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? context.tr('admin.configuration.slots.dialog.required') : null,
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _turno,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.tr('admin.configuration.slots.dialog.turn')),
                      items: [
                        DropdownMenuItem(value: 'MAÑANA', child: Text(context.tr('admin.configuration.slots.morning'))),
                        DropdownMenuItem(value: 'TARDE', child: Text(context.tr('admin.configuration.slots.afternoon'))),
                      ],
                      onChanged: (v) => setState(() => _turno = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _numeroCtrl,
                      decoration: InputDecoration(labelText: context.tr('admin.configuration.slots.dialog.order')),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? context.tr('admin.configuration.slots.dialog.required') : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildFieldLabel(context.tr('admin.configuration.slots.dialog.schedule')),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _inicioCtrl,
                        decoration: InputDecoration(
                          hintText: '08:00',
                          labelText: context.tr('admin.configuration.slots.dialog.start'),
                          prefixIcon: const Icon(Icons.login_rounded),
                        ),
                        validator: _validarHora,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _finCtrl,
                        decoration: InputDecoration(
                          hintText: '09:00',
                          labelText: context.tr('admin.configuration.slots.dialog.end'),
                          prefixIcon: const Icon(Icons.logout_rounded),
                        ),
                        validator: _validarHora,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _esRecreo,
                  onChanged: (v) => setState(() => _esRecreo = v),
                  title: Text(context.tr('admin.configuration.slots.dialog.isBreak'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('admin.configuration.slots.dialog.cancel')),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: RvPrimaryButton(
                        label: widget.tramo != null ? context.tr('admin.configuration.slots.dialog.save') : context.tr('admin.configuration.slots.dialog.create'),
                        isLoading: _loading,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).hintColor,
            letterSpacing: 1.1,
          )),
    );
  }

  String? _validarHora(String? v) {
    if (v == null || v.isEmpty) return context.tr('admin.configuration.slots.dialog.required');
    if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v)) return context.tr('admin.configuration.slots.dialog.invalidTime');
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final body = {
      'nombre': _nombreCtrl.text.trim(),
      'turno': _turno,
      'numero': int.tryParse(_numeroCtrl.text) ?? 0,
      'hora_inicio': '${_inicioCtrl.text.trim()}:00',
      'hora_fin': '${_finCtrl.text.trim()}:00',
      'es_recreo': _esRecreo,
    };

    final notifier = widget.ref.read(adminTramosProvider.notifier);
    final success = widget.tramo != null
        ? await notifier.editarTramo(widget.tramo!.id, body)
        : await notifier.crearTramo(body);

    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        Navigator.pop(context);
        RvAlerts.success(context, context.tr(widget.tramo != null ? 'admin.configuration.slots.edit' : 'admin.configuration.slots.add_success'));
      }
    }
  }
}