import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/l10n/app_localizations.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/widgets/tramo_permitido_selector.dart';

final adminSpacesProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios');
  return (response as List<dynamic>)
      .map((json) => Espacio.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminSpacesScreen extends ConsumerWidget {
  const AdminSpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(adminSpacesProvider);
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    double extent = 180;
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
            // Cabecera Moderna Premium
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: RvPageHeader(
                      title: context.tr('admin.spaces.title'),
                      eyebrow: 'Infraestructura',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.add_circle_outline_rounded,
                        onTap: () => _openEditor(context, ref),
                      ),
                      const SizedBox(width: 4),
                      RvGhostIconButton(
                        icon: Icons.refresh_rounded,
                        onTap: () => ref.invalidate(adminSpacesProvider),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: spacesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const RvEmptyState(
                      icon: Icons.business_rounded,
                      title: 'No hay espacios',
                      subtitle: 'Añade recintos deportivos o aulas para empezar.',
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
                          ? _AdminSpaceWebCard(
                        item: item,
                        onEdit: () => _openEditor(context, ref, espacio: item),
                        onDelete: () => _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(context, ref, item),
                      )
                          : _AdminSpaceMobileCard(
                        item: item,
                        onEdit: () => _openEditor(context, ref, espacio: item),
                        onDelete: () => _delete(context, ref, item),
                        onTramos: () => _openTramosConfig(context, ref, item),
                      );
                    },
                  );
                },
                loading: () => _AdminSpacesSkeleton(crossAxisCount: crossAxisCount, extent: extent),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(adminSpacesProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Métodos de lógica (Editor, Delete, Tramos) ---

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Espacio? espacio}) async {
    final nombreCtrl = TextEditingController(text: espacio?.nombre ?? '');
    final descripcionCtrl = TextEditingController(text: espacio?.descripcion ?? '');
    final precioCtrl = TextEditingController(text: (espacio?.precioTokens ?? 0).toString());
    final antelacionCtrl = TextEditingController(text: (espacio?.antelacionDias ?? 7).toString());
    final ubicacionCtrl = TextEditingController(text: espacio?.ubicacion ?? '');

    TipoEspacio tipo = espacio?.tipo ?? TipoEspacio.pista;
    bool reservable = espacio?.reservable ?? true;
    bool requiereAutorizacion = espacio?.requiereAutorizacion ?? false;
    bool activo = espacio?.activo ?? true;
    bool allowAlumno = espacio?.rolesPermitidos.contains('ALUMNO') ?? true;
    bool allowProfesor = espacio?.rolesPermitidos.contains('PROFESOR') ?? true;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showEspacioForm(
      context: context,
      title: espacio == null ? 'Nuevo espacio' : 'Editar espacio',
      nombreCtrl: nombreCtrl, descCtrl: descripcionCtrl, precioCtrl: precioCtrl,
      antelacionCtrl: antelacionCtrl, ubicacionCtrl: ubicacionCtrl,
      initialTipo: tipo, initialReservable: reservable,
      initialAutorizacion: requiereAutorizacion, initialActivo: activo,
      initialAllowAlumno: allowAlumno, initialAllowProfesor: allowProfesor,
      currentImageUrl: espacio?.imagenUrl,
      onTipoChanged: (val) => tipo = val,
      onReservableChanged: (val) => reservable = val,
      onAutorizacionChanged: (val) => requiereAutorizacion = val,
      onActivoChanged: (val) => activo = val,
      onRolesChanged: (al, pr) { allowAlumno = al; allowProfesor = pr; },
      onImageSelected: (bytes, name) { imageBytes = bytes; imageName = name; },
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = espacio?.imagenUrl;
      if (imageBytes != null && imageName != null) {
        final uploadResponse = await apiClient.postMultipart('/uploads/imagen', fileField: 'file', fileBytes: imageBytes!, fileName: imageName!);
        uploadedImageUrl = uploadResponse['url'] as String?;
      }

      final body = {
        'nombre': nombreCtrl.text.trim(),
        'descripcion': descripcionCtrl.text.trim(),
        'imagen_url': uploadedImageUrl,
        'tipo': tipo.value,
        'precio_tokens': int.tryParse(precioCtrl.text) ?? 0,
        'reservable': reservable,
        'requiere_autorizacion': requiereAutorizacion,
        'antelacion_dias': int.tryParse(antelacionCtrl.text) ?? 7,
        'ubicacion': ubicacionCtrl.text.trim(),
        'activo': activo,
        'roles_permitidos': [if (allowAlumno) 'ALUMNO', if (allowProfesor) 'PROFESOR'],
      };

      if (espacio == null) { await apiClient.post('/espacios/', body: body); }
      else { await apiClient.put('/espacios/${espacio.id}', body: body); }

      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
      if (context.mounted) RvAlerts.success(context, 'Operación exitosa');
    } catch (error) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error)); }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Espacio espacio) async {
    final confirmed = await RvAlerts.confirm(context, title: 'Eliminar', content: '¿Eliminar "${espacio.nombre}"?', isDestructive: true);
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/espacios/${espacio.id}');
      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
    } catch (e) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
  }

  Future<void> _openTramosConfig(BuildContext context, WidgetRef ref, Espacio espacio) async {
    final selectorKey = GlobalKey<TramoPermitidoSelectorState>();
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(ctx).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Tramos', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Flexible(child: SingleChildScrollView(child: TramoPermitidoSelector(key: selectorKey, resourceId: espacio.id, isServicio: false))),
            const SizedBox(height: 24),
            RvPrimaryButton(label: 'Guardar', onTap: () async {
              await selectorKey.currentState?.guardar();
              if (ctx.mounted) Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showEspacioForm({
    required BuildContext context, required String title, required TextEditingController nombreCtrl,
    required TextEditingController descCtrl, required TextEditingController precioCtrl,
    required TextEditingController antelacionCtrl, required TextEditingController ubicacionCtrl,
    required TipoEspacio initialTipo, required Function(TipoEspacio) onTipoChanged,
    required Function(bool) onReservableChanged, required Function(bool) onAutorizacionChanged,
    required Function(bool) onActivoChanged, required Function(bool, bool) onRolesChanged,
    required Function(Uint8List?, String?) onImageSelected, bool initialReservable = true,
    bool initialAutorizacion = false, bool initialActivo = true, bool initialAllowAlumno = true,
    bool initialAllowProfesor = true, String? currentImageUrl,
  }) {
    bool activo = initialActivo; bool reservable = initialReservable;
    return showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setState) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Tokens')),
          SwitchListTile(title: const Text('Activo'), value: activo, onChanged: (v) { setState(()=> activo = v); onActivoChanged(v); }),
          const SizedBox(height: 20),
          RvPrimaryButton(onTap: () => Navigator.pop(context, true), label: 'Guardar'),
        ])),
      )),
    );
  }
}

class _AdminSpaceMobileCard extends StatelessWidget {
  final Espacio item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;
  const _AdminSpaceMobileCard({required this.item, required this.onEdit, required this.onDelete, required this.onTramos});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RvSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 100, height: 100,
                child: item.imagenUrl != null
                    ? RvImage(imageUrl: item.imagenUrl!, fit: BoxFit.cover)
                    : Container(color: AppColors.primaryBlue.withOpacity(0.1), child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 2, overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 6),
                  RvBadge(label: '${item.precioTokens} Tokens', color: AppColors.primaryBlue),
                  const Spacer(),
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                      const SizedBox(width: 4),
                      RvGhostIconButton(icon: Icons.schedule_rounded, onTap: onTramos),
                      const SizedBox(width: 4),
                      RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
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

class _AdminSpaceWebCard extends StatelessWidget {
  final Espacio item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTramos;
  const _AdminSpaceWebCard({required this.item, required this.onEdit, required this.onDelete, required this.onTramos});

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
                        : Container(color: AppColors.primaryBlue.withOpacity(0.1), child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 48)),
                  ),
                ),
                if(!item.activo)
                  Positioned(top: 12, left: 12, child: const RvBadge(label: "INACTIVO", color: Colors.grey)),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.precioTokens} Tokens',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                Text(item.ubicacion ?? 'Sin ubicación', style: Theme.of(context).textTheme.bodySmall),
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

class _AdminSpacesSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double extent;
  const _AdminSpacesSkeleton({required this.crossAxisCount, required this.extent});

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