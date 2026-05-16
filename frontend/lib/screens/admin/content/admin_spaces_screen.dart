import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/providers/roles_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/allowed_time_slots_selector.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

final adminSpacesProvider =
FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios/',
      queryParams: {'incluir_inactivos': 'true'});
  return (response as List<dynamic>)
      .map((json) => Espacio.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminSpacesScreen extends ConsumerStatefulWidget {
  const AdminSpacesScreen({super.key});

  @override
  ConsumerState<AdminSpacesScreen> createState() =>
      _AdminSpacesScreenState();
}

class _AdminSpacesScreenState
    extends ConsumerState<AdminSpacesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacesAsync = ref.watch(adminSpacesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    int cols = 1;
    double extent = 180;
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
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin.spaces.eyebrow').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('admin.spaces.title'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.add_rounded,
                    color: theme.colorScheme.primary,
                    isDark: isDark,
                    theme: theme,
                    onTap: () => _openEditor(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.refresh_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    isDark: isDark,
                    theme: theme,
                    onTap: () => ref.invalidate(adminSpacesProvider),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: RvSearchBar(
                controller: _searchCtrl,
                hintText: context.tr('admin.spaces.search'),
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
              child: spacesAsync.when(
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
                      icon: Icons.business_rounded,
                      title: context.tr('admin.spaces.emptyTitle'),
                      subtitle:
                      context.tr('admin.spaces.emptySubtitle'),
                    );
                  }
                  if (items.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('common.noResults'),
                      subtitle: context.tr('common.tryOtherSearch'),
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
                            espacio: item),
                        onDelete: () =>
                            _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(
                            context, ref, item),
                      )
                          : _MobileCard(
                        item: item,
                        isDark: isDark,
                        theme: theme,
                        onEdit: () => _openEditor(
                            context, ref,
                            espacio: item),
                        onDelete: () =>
                            _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(
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
                loading: () => _Skeleton(cols: cols, extent: extent),
                error: (_, __) => Center(
                  child: RvApiErrorState(
                    onRetry: () =>
                        ref.invalidate(adminSpacesProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre el formulario para crear o editar un espacio
  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Espacio? espacio}) async {
    final nombreCtrl =
    TextEditingController(text: espacio?.nombre ?? '');
    final descCtrl =
    TextEditingController(text: espacio?.descripcion ?? '');
    final precioCtrl = TextEditingController(
        text: (espacio?.precioTokens ?? 0).toString());
    final antelacionCtrl = TextEditingController(
        text: (espacio?.antelacionDias ?? 7).toString());
    final ubicacionCtrl =
    TextEditingController(text: espacio?.ubicacion ?? '');
    final capacidadCtrl = TextEditingController(
        text: espacio?.capacidad?.toString() ?? '');

    TipoEspacio tipo = espacio?.tipo ?? TipoEspacio.pista;
    bool reservable = espacio?.reservable ?? true;
    bool requiereAutorizacion = espacio?.requiereAutorizacion ?? false;
    bool activo = espacio?.activo ?? true;
    Set<String> rolesPermitidos = espacio != null
        ? Set<String>.from(espacio.rolesPermitidos)
        : {'ALUMNO', 'PROFESOR'};
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showEspacioForm(
      context: context,
      title: espacio == null
          ? context.tr('admin.spaces.form.newTitle')
          : context.tr('admin.spaces.form.editTitle'),
      nombreCtrl: nombreCtrl,
      descCtrl: descCtrl,
      precioCtrl: precioCtrl,
      antelacionCtrl: antelacionCtrl,
      ubicacionCtrl: ubicacionCtrl,
      capacidadCtrl: capacidadCtrl,
      initialTipo: tipo,
      initialReservable: reservable,
      initialAutorizacion: requiereAutorizacion,
      initialActivo: activo,
      initialRoles: rolesPermitidos,
      currentImageUrl: espacio?.imagenUrl,
      onTipoChanged: (val) => tipo = val,
      onReservableChanged: (val) => reservable = val,
      onAutorizacionChanged: (val) => requiereAutorizacion = val,
      onActivoChanged: (val) => activo = val,
      onRolesChanged: (roles) => rolesPermitidos = roles,
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
    );

    if (result != true) return;

    // Valida campos obligatorios antes de llamar a la API
    final nombre = nombreCtrl.text.trim();
    final descripcion = descCtrl.text.trim();
    final tokensStr = precioCtrl.text.trim();
    final capacidadStr = capacidadCtrl.text.trim();

    if (nombre.isEmpty || descripcion.isEmpty || tokensStr.isEmpty || capacidadStr.isEmpty) {
      RvAlerts.warning(
          context,
          'Por favor, rellena nombre, descripción, tokens y capacidad'
      );
      return;
    }

    // Validar que sean números válidos
    final tokens = int.tryParse(tokensStr);
    final capacidad = int.tryParse(capacidadStr);

    if (tokens == null || capacidad == null) {
      RvAlerts.warning(context, 'Tokens y Capacidad deben ser números válidos');
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = espacio?.imagenUrl;
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
        'nombre': nombreCtrl.text.trim(),
        'descripcion': descCtrl.text.trim().isEmpty
            ? null
            : descCtrl.text.trim(),
        'imagen_url': uploadedImageUrl,
        'tipo': tipo.value,
        'precio_tokens': int.tryParse(precioCtrl.text) ?? 0,
        'reservable': reservable,
        'requiere_autorizacion': requiereAutorizacion,
        'antelacion_dias':
        int.tryParse(antelacionCtrl.text) ?? 7,
        'ubicacion': ubicacionCtrl.text.trim().isEmpty
            ? null
            : ubicacionCtrl.text.trim(),
        'capacidad': int.tryParse(capacidadCtrl.text),
        'activo': activo,
        'roles_permitidos': rolesPermitidos.toList(),
      };

      if (espacio == null) {
        await apiClient.post('/espacios/', body: body);
      } else {
        await apiClient.put('/espacios/${espacio.id}', body: body);
      }

      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
      if (context.mounted) {
        RvAlerts.success(
            context,
            context.tr(
                'admin.spaces.form.saveSuccess'));
      }
    } catch (error) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(error));
      }
    }
  }

  // Pide confirmación y elimina el espacio de la API
  Future<void> _delete(
      BuildContext context, WidgetRef ref, Espacio espacio) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.spaces.delete.title'),
      content: context
          .tr('admin.spaces.delete.content')
          .replaceAll('{name}', espacio.nombre),
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete('/espacios/${espacio.id}');
      // Notifica al usuario que el espacio se ha eliminado
      if (context.mounted) {
        RvAlerts.success(context, 'Espacio eliminado correctamente');
      }

      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
    } catch (e) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
  }

  // Abre el selector de tramos horarios permitidos para el espacio
  Future<void> _openTramosConfig(
      BuildContext context, WidgetRef ref, Espacio espacio) async {
    final selectorKey =
    GlobalKey<TramoPermitidoSelectorState>();
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(ctx).padding.top + 60),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
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
            children: [
              RvSheetHeader(onClose: () => Navigator.pop(ctx)),
              Text(
                context.tr('admin.spaces.timeSlots.title'),
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: TramoPermitidoSelector(
                    key: selectorKey,
                    resourceId: espacio.id,
                    isServicio: false,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RvPrimaryButton(
                label: context.tr('common.save'),
                onTap: () async {
                  await selectorKey.currentState?.guardar();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra el formulario de espacio en un bottom sheet y devuelve true si se guarda
  Future<bool?> _showEspacioForm({
    required BuildContext context,
    required String title,
    required TextEditingController nombreCtrl,
    required TextEditingController descCtrl,
    required TextEditingController precioCtrl,
    required TextEditingController antelacionCtrl,
    required TextEditingController ubicacionCtrl,
    required TextEditingController capacidadCtrl,
    required TipoEspacio initialTipo,
    required Function(TipoEspacio) onTipoChanged,
    required Function(bool) onReservableChanged,
    required Function(bool) onAutorizacionChanged,
    required Function(bool) onActivoChanged,
    required Function(Set<String>) onRolesChanged,
    required Function(Uint8List?, String?) onImageSelected,
    bool initialReservable = true,
    bool initialAutorizacion = false,
    bool initialActivo = true,
    Set<String> initialRoles = const {'ALUMNO', 'PROFESOR'},
    String? currentImageUrl,
  }) {
    bool activo = initialActivo;
    bool reservable = initialReservable;
    bool requiereAutorizacion = initialAutorizacion;
    Set<String> rolesLocales = Set<String>.from(initialRoles);
    TipoEspacio tipo = initialTipo;
    Uint8List? imageBytes;
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
                      8,
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
                        label: context.tr('admin.spaces.form.name'),
                        child: TextField(
                            controller: nombreCtrl,
                            decoration: const InputDecoration()),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.spaces.form.description'),
                        child: TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(),
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
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.spaces.form.type'),
                        child: DropdownButtonFormField<TipoEspacio>(
                          initialValue: tipo,
                          decoration: const InputDecoration(),
                          items: [
                            DropdownMenuItem(
                              value: TipoEspacio.pista,
                              child: Text(context.tr('spaces.type.court')),
                            ),
                            DropdownMenuItem(
                              value: TipoEspacio.aula,
                              child: Text(context.tr('spaces.type.classroom')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => tipo = value);
                            onTipoChanged(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FormSection(
                              label: context.tr('admin.spaces.form.tokens'),
                              child: TextField(
                                controller: precioCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormSection(
                              label: context.tr('admin.spaces.form.capacity'),
                              child: TextField(
                                controller: capacidadCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.spaces.form.location'),
                        child: TextField(
                          controller: ubicacionCtrl,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('admin.spaces.form.advanceDays'),
                        child: TextField(
                          controller: antelacionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SwitchSection(
                        isDark: isDark,
                        items: [
                          _SwitchItem(
                            label: context.tr('admin.spaces.form.bookable'),
                            value: reservable,
                            onChanged: (v) {
                              setState(() => reservable = v);
                              onReservableChanged(v);
                            },
                          ),
                          _SwitchItem(
                            label: context.tr(
                                'admin.spaces.form.requiresAuthorization'),
                            value: requiereAutorizacion,
                            onChanged: (v) {
                              setState(() => requiereAutorizacion = v);
                              onAutorizacionChanged(v);
                            },
                          ),
                          _SwitchItem(
                            label: context.tr('admin.spaces.form.active'),
                            value: activo,
                            onChanged: (v) {
                              setState(() => activo = v);
                              onActivoChanged(v);
                            },
                          ),
                        ],
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
                      const SizedBox(height: 24),
                      RvPrimaryButton(
                        onTap: () {
                          // Valida antes de cerrar el sheet
                          final nombre = nombreCtrl.text.trim();
                          final descripcion = descCtrl.text.trim();
                          final tokens = precioCtrl.text.trim();
                          final capacidad = capacidadCtrl.text.trim();

                          if (nombre.isEmpty || descripcion.isEmpty || tokens.isEmpty || capacidad.isEmpty) {

                            RvAlerts.warning(
                              context,
                              'Por favor, rellena nombre, descripción, tokens y capacidad',
                            );
                            return;
                          }

                          Navigator.pop(context, true);
                        },
                        label: context.tr('common.save'),
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

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
          child: Icon(widget.icon,
              size: 20, color: widget.color),
        ),
      ),
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
              source: ImageSource.gallery, imageQuality: 85);
          if (img == null) return;
          final bytes = await img.readAsBytes();
          widget.onPick(bytes, img.name);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 140,
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
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.imageBytes!,
                    fit: BoxFit.cover),
                if (_hovered)
                  Container(
                    color: Colors.black
                        .withValues(alpha: 0.35),
                    child: const Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            )
                : (widget.currentImageUrl?.isNotEmpty ?? false)
                ? Stack(
              fit: StackFit.expand,
              children: [
                RvImage(
                    imageUrl:
                    widget.currentImageUrl!,
                    fit: BoxFit.cover),
                if (_hovered)
                  Container(
                    color: Colors.black
                        .withValues(alpha: 0.35),
                    child: const Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            )
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

class _SwitchItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class _SwitchSection extends StatelessWidget {
  final bool isDark;
  final List<_SwitchItem> items;

  const _SwitchSection(
      {required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 16,
                  color: theme.dividerColor
                      .withValues(alpha: 0.4),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
                        style:
                        theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: items[i].value,
                      onChanged: items[i].onChanged,
                      activeTrackColor:
                      theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ],
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

    if (allRoles.isEmpty) {
      return const SizedBox.shrink();
    }

    final roles = allRoles.map((roleName) => (
      label: roleName,
      value: selectedRoles.contains(roleName),
      onTap: () {
        final updated = Set<String>.from(selectedRoles);
        if (updated.contains(roleName)) {
          updated.remove(roleName);
        } else {
          updated.add(roleName);
        }
        onChanged(updated);
      },
    )).toList();

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
                for (int i = 0; i < roles.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 16,
                      color: theme.dividerColor
                          .withValues(alpha: 0.4),
                    ),
                  InkWell(
                    onTap: roles[i].onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: roles[i].value
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius:
                              BorderRadius.circular(6),
                              border: Border.all(
                                color: roles[i].value
                                    ? theme.colorScheme.primary
                                    : (isDark
                                    ? Colors.white
                                    .withValues(
                                    alpha: 0.20)
                                    : Colors.black
                                    .withValues(
                                    alpha: 0.15)),
                                width: 1.5,
                              ),
                            ),
                            child: roles[i].value
                                ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            roles[i].label,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(
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

class _MobileCard extends StatefulWidget {
  final Espacio item;
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
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(
            color: _hovered
                ? widget.theme.colorScheme.primary.withValues(alpha: 0.25)
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05)),
            width: 1.5,
          ),
          boxShadow: _hovered
              ? AppShadows.deep(context)
              : AppShadows.soft(context),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: widget.item.imagenUrl != null
                      ? RvImage(
                      imageUrl: widget.item.imagenUrl!, fit: BoxFit.cover)
                      : Container(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    child: const Icon(Icons.room_service_rounded,
                        color: AppColors.primaryBlue, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item.nombre,
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        RvBadge(
                          label: '${widget.item.precioTokens} tokens',
                          icon: Icons.stars_rounded,
                          color: AppColors.primaryBlue,
                        ),
                        if (!widget.item.activo)
                          RvBadge(
                            label: context.tr('admin.services.inactive'),
                            color: AppColors.lightTextSecondary,
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _CardIconBtn(
                          icon: Icons.edit_outlined,
                          onTap: widget.onEdit,
                        ),
                        const SizedBox(width: 6),
                        _CardIconBtn(
                          icon: Icons.schedule_rounded,
                          onTap: widget.onTramos,
                        ),
                        const SizedBox(width: 6),
                        _CardIconBtn(
                          icon: Icons.delete_outline_rounded,
                          onTap: widget.onDelete,
                          color: AppColors.error,
                        ),
                      ],
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

class _WebCard extends StatefulWidget {
  final Espacio item;
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
          color: widget.isDark ? AppColors.darkCard : Colors.white,
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
                            Icons.business_rounded,
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
                        label: context.tr(
                            'admin.spaces.status.inactive'),
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
                        color:
                        Colors.black.withValues(alpha: 0.55),
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
                    widget.item.ubicacion ??
                        context.tr('spaces.no.location'),
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

  const _CardIconBtn({required this.icon, required this.onTap, this.color});

  @override
  State<_CardIconBtn> createState() => _CardIconBtnState();
}

class _CardIconBtnState extends State<_CardIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Si no se pasa color, usa el primario del tema
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
          child: Icon(
              widget.icon,
              size: 19,
              color: baseColor
          ),
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