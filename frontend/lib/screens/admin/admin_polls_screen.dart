import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/providers/encuestas_provider.dart';
import 'package:reservives/widgets/design_system.dart';

class AdminPollsScreen extends ConsumerWidget {
  const AdminPollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(adminEncuestasProvider);
    final width = MediaQuery.of(context).size.width;

    // Configuración de cuadrícula responsiva
    int crossAxisCount = 1;
    if (width > 1200) {
      crossAxisCount = 3;
    } else if (width > 800) {
      crossAxisCount = 2;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera Moderna Premium
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: RvPageHeader(
                      title: context.tr('admin.polls.title'),
                      eyebrow: 'Participación',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.add_circle_outline_rounded,
                        onTap: () => _showCreateDialog(context, ref),
                      ),
                      const SizedBox(width: 4),
                      RvGhostIconButton(
                        icon: Icons.refresh_rounded,
                        onTap: () => ref.read(adminEncuestasProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: pollsAsync.when(
                data: (polls) {
                  if (polls.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.how_to_vote_rounded,
                      title: context.tr('admin.polls.empty'),
                      subtitle: context.tr('admin.polls.emptySubtitle'),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, width > 700 ? 40 : 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 340,
                    ),
                    itemCount: polls.length,
                    itemBuilder: (context, index) => _AdminPollCard(
                      poll: polls[index],
                      onEdit: () => _showEditDialog(context, ref, polls[index]),
                      onDelete: () => _deletePoll(context, ref, polls[index].id, polls[index].titulo),
                    ),
                  );
                },
                loading: () => _AdminPollsSkeleton(crossAxisCount: crossAxisCount),
                error: (e, _) => Center(
                  child: RvApiErrorState(onRetry: () => ref.read(adminEncuestasProvider.notifier).refresh()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePoll(BuildContext context, WidgetRef ref, String id, String title) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.polls.delete.title'),
      content: context.tr('admin.polls.delete.confirmText').replaceAll('{title}', title),
      confirmLabel: context.tr('admin.remove.text'),
      isDestructive: true,
    );
    if (confirmed == true) {
      final success = await ref.read(adminEncuestasProvider.notifier).eliminarEncuesta(id);
      if (context.mounted && success) {
        RvAlerts.success(context, context.tr('admin.polls.delete.success'));
      }
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreatePollSheet(),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Encuesta poll) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPollSheet(poll: poll),
    );
  }
}

class _AdminPollCard extends StatelessWidget {
  final Encuesta poll;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminPollCard({
    required this.poll,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    poll.titulo,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                RvGhostIconButton(
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
                RvGhostIconButton(
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  poll.activa ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                  size: 14,
                  color: poll.activa ? AppColors.success : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  poll.activa ? "Activa" : "Pausada",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: poll.activa ? AppColors.success : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy').format(poll.fechaFin),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: poll.opciones.length > 4 ? 4 : poll.opciones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final opt = poll.opciones[i];
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt.texto,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${opt.votos}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              '${context.tr('polls.user.totalVotes').replaceAll('{n}', poll.totalVotos.toString())}',
              style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePollSheet extends ConsumerStatefulWidget {
  const _CreatePollSheet();

  @override
  ConsumerState<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<_CreatePollSheet> {
  final _titleController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController()
  ];
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() async {
    final title = _titleController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (title.isEmpty || options.length < 2) {
      RvAlerts.error(context, context.tr('admin.polls.error.minOptions'));
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref.read(adminEncuestasProvider.notifier).crearEncuesta(
      titulo: title,
      opciones: options,
      fechaFin: _expiryDate,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        RvAlerts.success(context, context.tr('admin.polls.create.success'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text(context.tr('admin.polls.create'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: context.tr('admin.polls.question'), prefixIcon: const Icon(Icons.help_outline)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(context.tr('admin.polls.options'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              RvGhostIconButton(
                onTap: () => setState(() => _optionControllers.add(TextEditingController())),
                icon: Icons.add_circle_outline,
              ),
            ],
          ),
          ..._optionControllers.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(hintText: 'Opción ${entry.key + 1}'))),
                if (_optionControllers.length > 2)
                  IconButton(onPressed: () => setState(() => _optionControllers.removeAt(entry.key)), icon: const Icon(Icons.remove_circle_outline, color: AppColors.error)),
              ],
            ),
          )),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat('dd/MM/yyyy').format(_expiryDate)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _expiryDate = d);
            },
          ),
          const SizedBox(height: 24),
          RvPrimaryButton(onTap: _submit, label: context.tr('admin.polls.createButton'), isLoading: _isSaving),
        ],
      ),
    );
  }
}

class _EditPollSheet extends ConsumerStatefulWidget {
  final Encuesta poll;
  const _EditPollSheet({required this.poll});

  @override
  ConsumerState<_EditPollSheet> createState() => _EditPollSheetState();
}

class _EditPollSheetState extends ConsumerState<_EditPollSheet> {
  late TextEditingController _titleController;
  late DateTime _expiryDate;
  late bool _activa;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.poll.titulo);
    _expiryDate = widget.poll.fechaFin;
    _activa = widget.poll.activa;
  }

  void _submit() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _isSaving = true);
    final success = await ref.read(adminEncuestasProvider.notifier).actualizarEncuesta(
      id: widget.poll.id,
      titulo: _titleController.text,
      descripcion: widget.poll.descripcion ?? '',
      fechaFin: _expiryDate,
      activa: _activa,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(context.tr('admin.polls.editTitle'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Pregunta')),
          SwitchListTile(title: const Text('Activa'), value: _activa, onChanged: (v) => setState(() => _activa = v)),
          const SizedBox(height: 24),
          RvPrimaryButton(onTap: _submit, label: 'Guardar cambios', isLoading: _isSaving),
        ],
      ),
    );
  }
}

class _AdminPollsSkeleton extends StatelessWidget {
  final int crossAxisCount;
  const _AdminPollsSkeleton({required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 340,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const RvSkeleton(width: double.infinity, height: 340, borderRadius: 28),
    );
  }
}