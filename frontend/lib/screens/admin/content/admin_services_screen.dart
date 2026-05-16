import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/providers/roles_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/widgets/allowed_time_slots_selector.dart';

final _gestorCandidatesProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/usuarios/');
  const allowed = {'ADMINISTRADOR', 'JEFATURA', 'GESTOR_SERVICIO'};
  return (response as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((u) => allowed.contains((u['rol'] as String?)?.toUpperCase()))
      .toList();
});

final adminServicesProvider =
FutureProvider.autoDispose<List<ServicioInstituto>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/servicios/todos');
  return (response as List<dynamic>)
      .map((json) =>
      ServicioInstituto.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  ConsumerState<AdminServicesScreen> createState() =>
      _AdminServicesScreenState();
}

class _AdminServicesScreenState
    extends ConsumerState<AdminServicesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(adminServicesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    int cols = 1;
    double extent = 190;
    if (width > 1200) {
      cols = 3;
      extent = 320;
    } else if (width > 800) {
      cols = 2;
      extent = 320;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          context
                              .tr('admin.services.eyebrow')
                              .toUpperCase(),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('admin.services.title'),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderBtn(
                    icon: Icons.add_rounded,
                    color: theme.colorScheme.primary,
                    isDark: isDark,
                    onTap: () => _openEditor(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _HeaderBtn(
                    icon: Icons.refresh_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    isDark: isDark,
                    onTap: () =>
                        ref.invalidate(adminServicesProvider),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),

            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: RvSearchBar(
                controller: _searchCtrl,
                hintText: context.tr('admin.services.search'),
                onChanged: (v) =>
                    setState(() => _query = v.toLowerCase()),
                onClear: _query.isNotEmpty
                    ? () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                }
                    : null,
              ),
            ),

            Expanded(
              child: servicesAsync.when(
                data: (allItems) {
                  final items = _query.isEmpty
                      ? allItems
                      : allItems
                      .where((s) => s.nombre
                      .toLowerCase()
                      .contains(_query))
                      .toList();

                  if (allItems.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.room_service_outlined,
                      title:
                      context.tr('admin.services.empty'),
                      subtitle: context
                          .tr('admin.services.emptySubtitle'),
                    );
                  }
                  if (items.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('common.noResults'),
                      subtitle: context
                          .tr('common.tryOtherSearch'),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                        20, 4, 20, isWeb ? 40 : 100),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: extent,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return (isWeb
                          ? _WebCard(
                        item: item,
                        isDark: isDark,
                        theme: theme,
                        onEdit: () => _openEditor(
                            context, ref,
                            servicio: item),
                        onDelete: () => _delete(
                            context, ref, item),
                        onTramos: () =>
                            _openTramosConfig(
                                context, ref, item),
                      )
                          : _MobileCard(
                        item: item,
                        isDark: isDark,
                        theme: theme,
                        onEdit: () => _openEditor(
                            context, ref,
                            servicio: item),
                        onDelete: () => _delete(
                            context, ref, item),
                        onTramos: () =>
                            _openTramosConfig(
                                context, ref, item),
                      ))
                          .animate()
                          .fadeIn(
                        delay: Duration(
                            milliseconds: 40 * index),
                        duration: 280.ms,
                      )
                          .slideY(
                        begin: 0.04,
                        delay: Duration(
                            milliseconds: 40 * index),
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      );
                    },
                  );
                },
                loading: () =>
                    _Skeleton(cols: cols, extent: extent),
                error: (_, __) => Center(
                  child: RvApiErrorState(
                    onRetry: () => ref
                        .invalidate(adminServicesProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre el formulario para crear o editar un servicio
  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {ServicioInstituto? servicio}) async {
    final nombreCtrl = TextEditingController(
        text: servicio?.nombre ?? '');
    final descCtrl = TextEditingController(
        text: servicio?.descripcion ?? '');
    final ubicacionCtrl = TextEditingController(
        text: servicio?.ubicacion ?? '');
    final horarioCtrl = TextEditingController(
        text: servicio?.horario ?? '');
    final precioCtrl = TextEditingController(
        text: (servicio?.precioTokens ?? 0).toString());
    final ordenCtrl = TextEditingController(
        text: (servicio?.orden ?? 0).toString());
    bool activo = servicio?.activo ?? true;
    Uint8List? imageBytes;
    String? imageName;
    String? gestorUsuarioId = servicio?.gestorUsuarioId;
    Set<String> rolesPermitidos = servicio != null
        ? Set<String>.from(servicio.rolesPermitidos)
        : {};

    final result = await _showServicioForm(
      context: context,
      ref: ref,
      title: servicio == null
          ? context.tr('admin.services.new')
          : context.tr('admin.services.edit'),
      nombreCtrl: nombreCtrl,
      descCtrl: descCtrl,
      ubicacionCtrl: ubicacionCtrl,
      horarioCtrl: horarioCtrl,
      precioCtrl: precioCtrl,
      ordenCtrl: ordenCtrl,
      initialActivo: activo,
      currentImageUrl: servicio?.imagenUrl,
      initialGestorId: gestorUsuarioId,
      initialRoles: rolesPermitidos,
      onActivoChanged: (val) => activo = val,
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
      onGestorChanged: (id) => gestorUsuarioId = id,
      onRolesChanged: (roles) => rolesPermitidos = roles,
    );

    if (result != true) return;
    if (nombreCtrl.text.trim().isEmpty) {
      RvAlerts.error(context,
          context.tr('admin.services.error.nameRequired'));
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final nombre = nombreCtrl.text.trim();
      final descripcion = descCtrl.text.trim();
      final tokens = int.parse(precioCtrl.text.trim());
      String? uploadedImageUrl = servicio?.imagenUrl;
      if (imageBytes != null && imageName != null) {
        final uploadResponse = await apiClient.postMultipart(
          '/uploads/imagen',
          fileField: 'file',
          fileBytes: imageBytes!,
          fileName: imageName!,
        );
        uploadedImageUrl = uploadResponse['url'] as String?;
      }
      final body = {
        'nombre': nombre,
        'descripcion': descripcion,
        'imagen_url': uploadedImageUrl,
        'ubicacion': ubicacionCtrl.text.trim().isEmpty
            ? null
            : ubicacionCtrl.text.trim(),
        'horario': horarioCtrl.text.trim().isEmpty
            ? null
            : horarioCtrl.text.trim(),
        'precio_tokens': tokens,
        'orden': int.tryParse(ordenCtrl.text) ?? 0,
        'activo': activo,
        'gestor_usuario_id': gestorUsuarioId,
        'roles_permitidos': rolesPermitidos.toList(),
      };
      if (servicio == null) {
        await apiClient.post('/servicios/', body: body);
      } else {
        await apiClient.put(
            '/servicios/${servicio.id}', body: body);
      }
      ref.invalidate(adminServicesProvider);
      if (context.mounted) {
        RvAlerts.success(
          context,
          servicio == null
              ? context.tr('admin.service.alert.create')
              : context.tr('admin.service.alert.update'),
        );
      }
    } catch (error) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(error));
      }
    }
  }

  // Pide confirmación y elimina el servicio de la API
  Future<void> _delete(BuildContext context, WidgetRef ref, ServicioInstituto servicio) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.delete.service'),
      content: '¿Estás seguro de que quieres eliminar "${servicio.nombre}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      await ref.read(apiClientProvider).delete('/servicios/${servicio.id}');

      if (context.mounted) {
        RvAlerts.success(context, 'Servicio "${servicio.nombre}" eliminado');
      }

      ref.invalidate(adminServicesProvider);
    } catch (error) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(error));
      }
    }
  }

  // Abre el selector de tramos horarios permitidos para el servicio
  Future<void> _openTramosConfig(BuildContext context,
      WidgetRef ref, ServicioInstituto servicio) async {
    final selectorKey =
    GlobalKey<TramoPermitidoSelectorState>();
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(ctx).padding.top + 60),
        child: Container(
          decoration: BoxDecoration(
            color:
            isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24,
              14,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RvSheetHeader(onClose: () => Navigator.pop(ctx)),
              Text(
                '"${servicio.nombre}"',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('admin.services.slots.subtitle'),
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: TramoPermitidoSelector(
                    key: selectorKey,
                    resourceId: servicio.id,
                    isServicio: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RvPrimaryButton(
                label: context.tr('generic.save'),
                onTap: () async {
                  try {
                    await selectorKey.currentState?.guardar();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      RvAlerts.success(context,
                          context.tr('admin.services.slots.success'));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      RvAlerts.error(context,
                          toFriendlyErrorMessage(e));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showServicioForm({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required TextEditingController nombreCtrl,
    required TextEditingController descCtrl,
    required TextEditingController ubicacionCtrl,
    required TextEditingController horarioCtrl,
    required TextEditingController precioCtrl,
    required TextEditingController ordenCtrl,
    required Function(bool) onActivoChanged,
    required Function(Uint8List?, String?) onImageSelected,
    required Function(String?) onGestorChanged,
    required Function(Set<String>) onRolesChanged,
    bool initialActivo = true,
    String? currentImageUrl,
    String? initialGestorId,
    Set<String> initialRoles = const {},
  }) {
    bool activo = initialActivo;
    Uint8List? imageBytes;
    String? selectedGestorId = initialGestorId;
    Set<String> rolesLocales = Set<String>.from(initialRoles);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RvSheetHeader(onClose: () => Navigator.pop(context)),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).viewInsets.bottom + 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 24),
                      _FormSection(
                        label: context.tr('admin.common.name'),
                        child: TextField(
                          controller: nombreCtrl,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.common.description'),
                        child: TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FormSection(
                              label: context.tr('admin.common.location'),
                              child: TextField(
                                controller: ubicacionCtrl,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormSection(
                              label: context.tr('admin.common.tokens'),
                              child: TextField(
                                controller: precioCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.common.schedule'),
                        child: TextField(
                          controller: horarioCtrl,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.services.gestor'),
                        child: Consumer(
                          builder: (context, cRef, _) {
                            final candidatesAsync = cRef.watch(_gestorCandidatesProvider);
                            return candidatesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => Text(context.tr('generic.error')),
                              data: (users) => _GestorPickerField(
                                users: users,
                                selectedId: selectedGestorId,
                                noGestorLabel: context.tr('admin.services.noGestor'),
                                onChanged: (val) {
                                  setState(() => selectedGestorId = val);
                                  onGestorChanged(val);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('incidents.image.label'),
                        child: _ImagePicker(
                          imageBytes: imageBytes,
                          currentImageUrl: currentImageUrl,
                          isDark: isDark,
                          onPick: (bytes, name) {
                            setState(() => imageBytes = bytes);
                            onImageSelected(bytes, name);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SwitchRow(
                        isDark: isDark,
                        label: context.tr('admin.common.active'),
                        value: activo,
                        ordenCtrl: ordenCtrl,
                        ordenLabel: context.tr('admin.common.position'),
                        onChanged: (v) {
                          setState(() => activo = v);
                          onActivoChanged(v);
                        },
                      ),
                      const SizedBox(height: 20),
                      _RolesSection(
                        isDark: isDark,
                        selectedRoles: rolesLocales,
                        onChanged: (roles) {
                          setState(() => rolesLocales = roles);
                          onRolesChanged(roles);
                        },
                      ),
                      const SizedBox(height: 28),
                      RvPrimaryButton(
                        onTap: () {
                          final nombre = nombreCtrl.text.trim();
                          final descripcion = descCtrl.text.trim();
                          final horario = horarioCtrl.text.trim();
                          final tokens = precioCtrl.text.trim();

                          if (nombre.isEmpty || descripcion.isEmpty || horario.isEmpty || tokens.isEmpty) {
                            RvAlerts.warning(
                              context,
                              'Por favor, rellena nombre, descripción, horario y tokens',
                            );
                            return;
                          }
                          if (int.tryParse(tokens) == null) {
                            RvAlerts.warning(
                                context,
                                'El precio en tokens debe ser un número válido'
                            );
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        label: context.tr('generic.save'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.12)
                : widget.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(widget.icon, size: 20, color: widget.color),
        ),
      ),
    );
  }
}

class _RolesSection extends ConsumerWidget {
  final bool isDark;
  final Set<String> selectedRoles;
  final ValueChanged<Set<String>> onChanged;

  const _RolesSection({
    required this.isDark,
    required this.selectedRoles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rolesState = ref.watch(rolesProvider);
    final allRoles = rolesState.mappings.map((m) => m.roleName).toList();

    if (allRoles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('admin.spaces.form.allowedRoles'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.l),
            child: Column(
              children: [
                for (int i = 0; i < allRoles.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 16,
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  InkWell(
                    onTap: () {
                      final updated = Set<String>.from(selectedRoles);
                      if (updated.contains(allRoles[i])) {
                        updated.remove(allRoles[i]);
                      } else {
                        updated.add(allRoles[i]);
                      }
                      onChanged(updated);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: selectedRoles.contains(allRoles[i])
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selectedRoles.contains(allRoles[i])
                                    ? theme.colorScheme.primary
                                    : (isDark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.15)),
                                width: 1.5,
                              ),
                            ),
                            child: selectedRoles.contains(allRoles[i])
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            allRoles[i],
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormSection(
      {required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ImagePicker extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? currentImageUrl;
  final bool isDark;
  final void Function(Uint8List bytes, String name) onPick;

  const _ImagePicker({
    required this.imageBytes,
    required this.currentImageUrl,
    required this.isDark,
    required this.onPick,
  });

  @override
  State<_ImagePicker> createState() => _ImagePickerState();
}

class _ImagePickerState extends State<_ImagePicker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          final img = await ImagePicker().pickImage(
              source: ImageSource.gallery, imageQuality: 80);
          if (img == null) return;
          final bytes = await img.readAsBytes();
          widget.onPick(bytes, img.name);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkCard
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(
              color: _hovered
                  ? primary.withValues(alpha: 0.35)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.m),
            child: widget.imageBytes != null
                ? Stack(fit: StackFit.expand, children: [
              Image.memory(widget.imageBytes!,
                  fit: BoxFit.cover),
              if (_hovered)
                Container(
                  color:
                  Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 28),
                  ),
                ),
            ])
                : (widget.currentImageUrl?.isNotEmpty ?? false)
                ? Stack(fit: StackFit.expand, children: [
              RvImage(
                  imageUrl: widget.currentImageUrl!,
                  fit: BoxFit.cover),
              if (_hovered)
                Container(
                  color: Colors.black
                      .withValues(alpha: 0.35),
                  child: const Center(
                    child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 28),
                  ),
                ),
            ])
                : Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                      milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? primary.withValues(
                        alpha: 0.12)
                        : primary.withValues(
                        alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    size: 22,
                    color: primary.withValues(
                        alpha:
                        _hovered ? 0.9 : 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Toca para añadir imagen',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: widget.isDark
                        ? AppColors
                        .darkTextSecondary
                        : AppColors
                        .lightTextSecondary,
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

class _SwitchRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final TextEditingController ordenCtrl;
  final String ordenLabel;

  const _SwitchRow({
    required this.isDark,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.ordenCtrl,
    required this.ordenLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordenLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: ordenCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCard extends StatefulWidget {
  final ServicioInstituto item;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;

  const _MobileCard({
    required this.item,
    required this.isDark,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
    required this.onTramos,
  });

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
          widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(
            color: _hovered
                ? widget.theme.colorScheme.primary
                .withValues(alpha: 0.25)
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05)),
            width: 1.5,
          ),
          boxShadow: _hovered
              ? AppShadows.deep(context)
              : AppShadows.soft(context),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: widget.item.imagenUrl != null
                          ? RvImage(
                          imageUrl: widget.item.imagenUrl!,
                          fit: BoxFit.cover)
                          : Container(
                        color: AppColors.primaryBlue
                            .withValues(alpha: 0.10),
                        child: const Icon(
                            Icons.room_service_rounded,
                            color: AppColors.primaryBlue,
                            size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        if (!widget.item.activo)
                          Padding(
                            padding:
                            const EdgeInsets.only(bottom: 4),
                            child: RvBadge(
                              label: context.tr(
                                  'admin.services.inactive'),
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        Text(
                          widget.item.nombre,
                          style: widget.theme.textTheme.titleSmall
                              ?.copyWith(
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 12,
                                color: widget.isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.item.horario ??
                                    context.tr(
                                        'admin.services.noSchedule'),
                                style: widget.theme.textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: widget.isDark
                                      ? AppColors
                                      .darkTextSecondary
                                      : AppColors
                                      .lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RvBadge(
                          label:
                          '${widget.item.precioTokens} tokens',
                          icon: Icons.stars_rounded,
                          color: AppColors.primaryBlue,
                        ),
                        if (widget.item.gestorNombre != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 12,
                                  color: widget.isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.item.gestorNombre!,
                                  style: widget.theme.textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: widget.isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: widget.theme.dividerColor
                  .withValues(alpha: 0.25),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  _CardIconBtn(
                    icon: Icons.schedule_rounded,
                    onTap: widget.onTramos,
                  ),
                  const SizedBox(width: 6),
                  _CardIconBtn(
                    icon: Icons.edit_outlined,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 6),
                  _CardIconBtn(
                    icon: Icons.delete_outline_rounded,
                    onTap: widget.onDelete,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebCard extends StatefulWidget {
  final ServicioInstituto item;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;

  const _WebCard({
    required this.item,
    required this.isDark,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
    required this.onTramos,
  });

  @override
  State<_WebCard> createState() => _WebCardState();
}

class _WebCardState extends State<_WebCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
          widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(
            color: _hovered
                ? widget.theme.colorScheme.primary
                .withValues(alpha: 0.25)
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05)),
            width: 1.5,
          ),
          boxShadow: _hovered
              ? AppShadows.deep(context)
              : AppShadows.soft(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadii.l)),
                      child: widget.item.imagenUrl != null
                          ? RvImage(
                          imageUrl: widget.item.imagenUrl!,
                          fit: BoxFit.cover)
                          : Container(
                        color: AppColors.primaryBlue
                            .withValues(alpha: 0.10),
                        child: const Icon(
                            Icons.room_service_rounded,
                            color: AppColors.primaryBlue,
                            size: 44),
                      ),
                    ),
                  ),
                  if (!widget.item.activo)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: RvBadge(
                        label: context
                            .tr('admin.services.inactive'),
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withValues(alpha: 0.55),
                        borderRadius:
                        BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${widget.item.precioTokens} tokens',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.nombre,
                    style: widget.theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.item.horario ??
                        context.tr('admin.services.noSchedule'),
                    style: widget.theme.textTheme.bodySmall
                        ?.copyWith(
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _CardIconBtn(
                          icon: Icons.schedule_rounded,
                          onTap: widget.onTramos),
                      const SizedBox(width: 4),
                      _CardIconBtn(
                          icon: Icons.edit_outlined,
                          onTap: widget.onEdit),
                      const SizedBox(width: 4),
                      _CardIconBtn(
                          icon: Icons.delete_outline_rounded,
                          onTap: widget.onDelete,
                          color: AppColors.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CardIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _CardIconBtn(
      {required this.icon, required this.onTap, this.color});

  @override
  State<_CardIconBtn> createState() => _CardIconBtnState();
}

class _CardIconBtnState extends State<_CardIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.color ?? theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _hovered ? 0.20 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: baseColor.withValues(alpha: _hovered ? 0.30 : 0.10),
              width: 1,
            ),
          ),
          child: Icon(widget.icon, size: 19, color: baseColor),
        ),
      ),
    );
  }
}

class _GestorPickerField extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final String? selectedId;
  final String noGestorLabel;
  final ValueChanged<String?> onChanged;

  const _GestorPickerField({
    required this.users,
    required this.selectedId,
    required this.noGestorLabel,
    required this.onChanged,
  });

  @override
  State<_GestorPickerField> createState() => _GestorPickerFieldState();
}

class _GestorPickerFieldState extends State<_GestorPickerField> {
  void _openPicker() {
    showDialog<String?>(
      context: context,
      builder: (ctx) => _GestorPickerDialog(
        users: widget.users,
        selectedId: widget.selectedId,
        noGestorLabel: widget.noGestorLabel,
        onSelected: (id) {
          Navigator.pop(ctx);
          widget.onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selectedId != null
        ? widget.users.where((u) => u['id'] == widget.selectedId).firstOrNull
        : null;
    final label = selected != null
        ? '${selected['nombre']} ${selected['apellidos']}'
        : widget.noGestorLabel;

    return GestureDetector(
      onTap: _openPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.person_search_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected != null ? null : theme.hintColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: theme.hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _GestorPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final String? selectedId;
  final String noGestorLabel;
  final ValueChanged<String?> onSelected;

  const _GestorPickerDialog({
    required this.users,
    required this.selectedId,
    required this.noGestorLabel,
    required this.onSelected,
  });

  @override
  State<_GestorPickerDialog> createState() => _GestorPickerDialogState();
}

class _GestorPickerDialogState extends State<_GestorPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.users;
    final q = _query.toLowerCase();
    return widget.users.where((u) {
      final name = '${u['nombre']} ${u['apellidos']}'.toLowerCase();
      return name.contains(q) || (u['email'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seleccionar gestor',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.hintColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: theme.hintColor),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: theme.hintColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    _GestorOption(
                      label: widget.noGestorLabel,
                      subtitle: '',
                      isSelected: widget.selectedId == null,
                      icon: Icons.person_off_rounded,
                      onTap: () => widget.onSelected(null),
                    ),
                    ..._filtered.map((u) {
                      final id = u['id'] as String;
                      final rol = (u['rol'] as String? ?? '');
                      return _GestorOption(
                        label: '${u['nombre']} ${u['apellidos']}',
                        subtitle: '${u['email']}  •  $rol',
                        isSelected: widget.selectedId == id,
                        icon: Icons.person_rounded,
                        onTap: () => widget.onSelected(id),
                      );
                    }),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Sin resultados',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestorOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _GestorOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? primary.withValues(alpha: 0.12) : theme.hintColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: isSelected ? primary : theme.hintColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? primary : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final int cols;
  final double extent;

  const _Skeleton({required this.cols, required this.extent});

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: extent,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
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
    );
  }
}