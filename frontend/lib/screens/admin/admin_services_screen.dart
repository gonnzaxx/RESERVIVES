import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/widgets/allowed_time_slots_selector.dart';

final adminServicesProvider = FutureProvider.autoDispose<List<ServicioInstituto>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/servicios/todos');
  return (response as List<dynamic>)
      .map((json) => ServicioInstituto.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminServicesScreen extends ConsumerWidget {
  const AdminServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(adminServicesProvider);
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    double extent = 190;
    if (width > 1200) {
      crossAxisCount = 3;
      extent = 320;
    } else if (width > 800) {
      crossAxisCount = 2;
      extent = 320;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: RvPageHeader(
                title: context.tr('admin.services.title'),
                eyebrow: context.tr('admin.services.eyebrow'),
                trailing: Row(
                  children: [
                    RvGhostIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      onTap: () => _openEditor(context, ref),
                    ),
                    const SizedBox(width: 8),
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(adminServicesProvider),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: servicesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.room_service_outlined,
                      title: context.tr('admin.services.empty'),
                      subtitle: context.tr('admin.services.emptySubtitle'),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, width > 700 ? 40 : 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: extent,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final isWeb = width > 800;
                      final item = items[index];
                      return isWeb
                          ? _AdminServiceWebCard(
                        item: item,
                        onEdit: () => _openEditor(context, ref, servicio: item),
                        onDelete: () => _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(context, ref, item),
                      )
                          : _AdminServiceMobileCard(
                        item: item,
                        onEdit: () => _openEditor(context, ref, servicio: item),
                        onDelete: () => _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(context, ref, item),
                      );
                    },
                  );
                },
                loading: () => _AdminServicesSkeleton(crossAxisCount: crossAxisCount, extent: extent),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(adminServicesProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {ServicioInstituto? servicio}) async {
    final nombreCtrl = TextEditingController(text: servicio?.nombre ?? '');
    final descCtrl = TextEditingController(text: servicio?.descripcion ?? '');
    final ubicacionCtrl = TextEditingController(text: servicio?.ubicacion ?? '');
    final horarioCtrl = TextEditingController(text: servicio?.horario ?? '');
    final precioCtrl = TextEditingController(text: (servicio?.precioTokens ?? 0).toString());
    final ordenCtrl = TextEditingController(text: (servicio?.orden ?? 0).toString());
    bool activo = servicio?.activo ?? true;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showServicioForm(
      context: context,
      title: servicio == null ? context.tr('admin.services.new') : context.tr('admin.services.edit'),
      nombreCtrl: nombreCtrl,
      descCtrl: descCtrl,
      ubicacionCtrl: ubicacionCtrl,
      horarioCtrl: horarioCtrl,
      precioCtrl: precioCtrl,
      ordenCtrl: ordenCtrl,
      initialActivo: activo,
      currentImageUrl: servicio?.imagenUrl,
      onActivoChanged: (val) => activo = val,
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
    );

    if (result != true) return;
    if (nombreCtrl.text.trim().isEmpty) {
      RvAlerts.error(context, context.tr('admin.services.error.nameRequired'));
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = servicio?.imagenUrl;
      if (imageBytes != null && imageName != null) {
        final uploadResponse = await apiClient.postMultipart('/uploads/imagen', fileField: 'file', fileBytes: imageBytes!, fileName: imageName!);
        uploadedImageUrl = uploadResponse['url'] as String?;
      }
      final body = {
        'nombre': nombreCtrl.text.trim(),
        'descripcion': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'imagen_url': uploadedImageUrl,
        'ubicacion': ubicacionCtrl.text.trim().isEmpty ? null : ubicacionCtrl.text.trim(),
        'horario': horarioCtrl.text.trim().isEmpty ? null : horarioCtrl.text.trim(),
        'precio_tokens': int.tryParse(precioCtrl.text) ?? 0,
        'orden': int.tryParse(ordenCtrl.text) ?? 0,
        'activo': activo,
      };
      if (servicio == null) {
        await apiClient.post('/servicios/', body: body);
      } else {
        await apiClient.put('/servicios/${servicio.id}', body: body);
      }
      ref.invalidate(adminServicesProvider);
      if (context.mounted) RvAlerts.success(context, servicio == null ? context.tr('admin.service.alert.create') : context.tr('admin.service.alert.update'));
    } catch (error) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ServicioInstituto servicio) async {
    final confirmed = await RvAlerts.confirm(
        context,
        title:
        context.tr('admin.delete.service'),
        content: '¿Seguro que quieres eliminar "${servicio.nombre}"?',
        confirmLabel: context.tr('admin.remove.text'),
        isDestructive: true);

    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/servicios/${servicio.id}');
      ref.invalidate(adminServicesProvider);
      if (context.mounted) RvAlerts.success(context, context.tr('admin.service.alert.remove'));
    } catch (error) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error)); }
  }

  Future<void> _openTramosConfig(BuildContext context, WidgetRef ref, ServicioInstituto servicio) async {
    final selectorKey = GlobalKey<TramoPermitidoSelectorState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(ctx).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Tramos de "${servicio.nombre}"', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(context.tr('admin.services.slots.subtitle')),
            const SizedBox(height: 24),
            Flexible(child: SingleChildScrollView(child: TramoPermitidoSelector(key: selectorKey, resourceId: servicio.id, isServicio: true))),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('generic.cancel')))),
              const SizedBox(width: 16),
              Expanded(child: RvPrimaryButton(label: context.tr('generic.save'), onTap: () async {
                try {
                  await selectorKey.currentState?.guardar();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    RvAlerts.success(context, context.tr('admin.services.slots.success'));
                  }
                } catch (e) { if (ctx.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
              })),
            ]),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showServicioForm({
    required BuildContext context, required String title, required TextEditingController nombreCtrl, required TextEditingController descCtrl,
    required TextEditingController ubicacionCtrl, required TextEditingController horarioCtrl, required TextEditingController precioCtrl,
    required TextEditingController ordenCtrl, required Function(bool) onActivoChanged, required Function(Uint8List?, String?) onImageSelected,
    bool initialActivo = true, String? currentImageUrl,
  }) {
    bool activo = initialActivo;
    Uint8List? imageBytes;
    return showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setState) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: '${context.tr('admin.common.name')} *', prefixIcon: const Icon(Icons.room_service_outlined))),          const SizedBox(height: 16),
          TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: context.tr('admin.common.description'), prefixIcon: const Icon(Icons.description_outlined))),          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: ubicacionCtrl, decoration: InputDecoration(labelText: context.tr('admin.common.location'), prefixIcon: const Icon(Icons.location_on_outlined)))),            const SizedBox(width: 12),
            Expanded(child: TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('admin.common.tokens'), prefixIcon: const Icon(Icons.stars_rounded)))),          ]),
          const SizedBox(height: 16),
          TextField(controller: horarioCtrl, decoration: InputDecoration(labelText: context.tr('admin.common.schedule'), prefixIcon: const Icon(Icons.access_time_rounded))),          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (img == null) return;
              final bytes = await img.readAsBytes();
              setState(() => imageBytes = bytes);
              onImageSelected(bytes, img.name);
            },
            child: Container(
              height: 160, width: double.infinity,
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: imageBytes != null ? Image.memory(imageBytes!, fit: BoxFit.cover) : (currentImageUrl != null ? RvImage(imageUrl: currentImageUrl, fit: BoxFit.cover) : Icon(Icons.add_a_photo_outlined, color: Theme.of(context).primaryColor, size: 40)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(flex: 2, child: SwitchListTile(title: Text(context.tr('admin.common.active'), style: const TextStyle(fontSize: 14)), value: activo, onChanged: (v) { setState(() => activo = v); onActivoChanged(v); }, contentPadding: EdgeInsets.zero)),            const SizedBox(width: 12),
            Expanded(child: TextField(controller: ordenCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('admin.common.position')))),          ]),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('generic.cancel')))),            const SizedBox(width: 16),
            Expanded(child: RvPrimaryButton(onTap: () => Navigator.pop(context, true), label: context.tr('generic.save'))),          ]),
        ])),
      )),
    );
  }
}

class _AdminServiceMobileCard extends StatelessWidget {
  final ServicioInstituto item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;
  const _AdminServiceMobileCard({required this.item, required this.onEdit, required this.onDelete, required this.onTramos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Contenido principal
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 72, height: 72,
                    child: item.imagenUrl != null
                        ? RvImage(imageUrl: item.imagenUrl!, fit: BoxFit.cover)
                        : Container(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      child: const Icon(Icons.room_service_rounded, color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!item.activo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RvBadge(label: context.tr('admin.services.inactive'), color: Colors.grey),
                        ),
                      Text(
                        item.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.horario ?? context.tr('admin.services.noSchedule'),
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RvBadge(
                        label: '${item.precioTokens} Tokens',
                        icon: Icons.stars_rounded,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divisor
          Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha: 0.15)),

          // Barra de acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.schedule_rounded,
                    label: context.tr('admin.services.slots.label'),
                    onTap: onTramos,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(width: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_outlined,
                    label: context.tr('generic.edit'),
                    onTap: onEdit,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(width: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha:0.15)),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: context.tr('generic.delete'),
                    onTap: onDelete,
                    isDestructive: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).hintColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminServiceWebCard extends StatelessWidget {
  final ServicioInstituto item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;
  const _AdminServiceWebCard({required this.item, required this.onEdit, required this.onDelete, required this.onTramos});

  @override
  Widget build(BuildContext context) {
    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: item.imagenUrl != null
                        ? RvImage(imageUrl: item.imagenUrl!, fit: BoxFit.cover)
                        : Container(color: AppColors.primaryBlue.withValues(alpha: 0.1), child: const Icon(Icons.room_service_rounded, color: AppColors.primaryBlue, size: 48)),
                  ),
                ),
                if(!item.activo)
                  Positioned(top: 12, left: 12, child: const RvBadge(label: "INACTIVO", color: Colors.grey)),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: RvBadge(
                      label: '${item.precioTokens} Tokens',
                      color: Colors.white,
                      icon: Icons.stars_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(item.horario ?? 'Horario no definido', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    RvGhostIconButton(icon: Icons.schedule_rounded, onTap: onTramos),
                    const SizedBox(width: 4),
                    RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                    const SizedBox(width: 4),
                    RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminServicesSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double extent;
  const _AdminServicesSkeleton({required this.crossAxisCount, required this.extent});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: extent),
      itemCount: 6,
      itemBuilder: (_, __) => RvSkeleton(width: double.infinity, height: extent, borderRadius: 28),
    );
  }
}