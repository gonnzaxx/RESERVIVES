import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/allowed_time_slots_selector.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

final adminSpacesProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios/', queryParams: {'incluir_inactivos': 'true'});
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: RvPageHeader(
                      title: context.tr('admin.spaces.title'),
                      eyebrow: context.tr('admin.spaces.eyebrow'),
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
                    return RvEmptyState(
                      icon: Icons.business_rounded,
                      title: context.tr('admin.spaces.emptyTitle'),
                      subtitle: context.tr('admin.spaces.emptySubtitle'),
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

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Espacio? espacio}) async {
    final nombreCtrl = TextEditingController(text: espacio?.nombre ?? '');
    final descripcionCtrl = TextEditingController(text: espacio?.descripcion ?? '');
    final precioCtrl = TextEditingController(text: (espacio?.precioTokens ?? 0).toString());
    final antelacionCtrl = TextEditingController(text: (espacio?.antelacionDias ?? 7).toString());
    final ubicacionCtrl = TextEditingController(text: espacio?.ubicacion ?? '');
    final capacidadCtrl = TextEditingController(text: espacio?.capacidad?.toString() ?? '');

    TipoEspacio tipo = espacio?.tipo ?? TipoEspacio.pista;
    bool reservable = espacio?.reservable ?? true;
    bool requiereAutorizacion = espacio?.requiereAutorizacion ?? false;
    bool activo = espacio?.activo ?? true;
    bool allowAlumno = espacio?.rolesPermitidos.contains('ALUMNO') ?? true;
    bool allowProfesor = espacio?.rolesPermitidos.contains('PROFESOR') ?? true;
    bool allowSecretaria = espacio?.rolesPermitidos.contains('SECRETARIA') ?? false;
    bool allowProfesorServicio = espacio?.rolesPermitidos.contains('PROFESOR_SERVICIO') ?? false;
    bool allowJefeEstudios = espacio?.rolesPermitidos.contains('JEFE_ESTUDIOS') ?? false;
    bool allowCafeteria = espacio?.rolesPermitidos.contains('CAFETERIA') ?? false;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showEspacioForm(
      context: context,
      title: espacio == null
          ? context.tr('admin.spaces.form.newTitle')
          : context.tr('admin.spaces.form.editTitle'),
      nombreCtrl: nombreCtrl,
      descCtrl: descripcionCtrl,
      precioCtrl: precioCtrl,
      antelacionCtrl: antelacionCtrl,
      ubicacionCtrl: ubicacionCtrl,
      capacidadCtrl: capacidadCtrl,
      initialTipo: tipo,
      initialReservable: reservable,
      initialAutorizacion: requiereAutorizacion,
      initialActivo: activo,
      initialAllowAlumno: allowAlumno,
      initialAllowProfesor: allowProfesor,
      initialAllowSecretaria: allowSecretaria,
      initialAllowProfesorServicio: allowProfesorServicio,
      initialAllowJefeEstudios: allowJefeEstudios,
      initialAllowCafeteria: allowCafeteria,
      currentImageUrl: espacio?.imagenUrl,
      onTipoChanged: (val) => tipo = val,
      onReservableChanged: (val) => reservable = val,
      onAutorizacionChanged: (val) => requiereAutorizacion = val,
      onActivoChanged: (val) => activo = val,
      onRolesChanged: (al, pr, sec, ps, je, ca) {
        allowAlumno = al;
        allowProfesor = pr;
        allowSecretaria = sec;
        allowProfesorServicio = ps;
        allowJefeEstudios = je;
        allowCafeteria = ca;
      },
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) {
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
        'descripcion': descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
        'imagen_url': uploadedImageUrl,
        'tipo': tipo.value,
        'precio_tokens': int.tryParse(precioCtrl.text) ?? 0,
        'reservable': reservable,
        'requiere_autorizacion': requiereAutorizacion,
        'antelacion_dias': int.tryParse(antelacionCtrl.text) ?? 7,
        'ubicacion': ubicacionCtrl.text.trim().isEmpty ? null : ubicacionCtrl.text.trim(),
        'capacidad': int.tryParse(capacidadCtrl.text),
        'activo': activo,
        'roles_permitidos': [
          if (allowAlumno) 'ALUMNO',
          if (allowProfesor) 'PROFESOR',
          if (allowSecretaria) 'SECRETARIA',
          if (allowProfesorServicio) 'PROFESOR_SERVICIO',
          if (allowJefeEstudios) 'JEFE_ESTUDIOS',
          if (allowCafeteria) 'CAFETERIA',
        ],
      };

      if (espacio == null) {
        await apiClient.post('/espacios/', body: body);
      } else {
        await apiClient.put('/espacios/${espacio.id}', body: body);
      }

      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
      if (context.mounted) {
        RvAlerts.success(context, context.tr('admin.spaces.form.saveSuccess'));
      }
    } catch (error) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(error));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Espacio espacio) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.spaces.delete.title'),
      content: context.tr('admin.spaces.delete.content').replaceAll('{name}', espacio.nombre),
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/espacios/${espacio.id}');
      ref.invalidate(adminSpacesProvider);
      notifyAdminCountersChanged(ref);
    } catch (e) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
  }

  Future<void> _openTramosConfig(BuildContext context, WidgetRef ref, Espacio espacio) async {
    final selectorKey = GlobalKey<TramoPermitidoSelectorState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(context.tr('admin.spaces.timeSlots.title'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: TramoPermitidoSelector(key: selectorKey, resourceId: espacio.id, isServicio: false),
              ),
            ),
            const SizedBox(height: 24),
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
    );
  }

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
    required Function(bool, bool, bool, bool, bool, bool) onRolesChanged,
    required Function(Uint8List?, String?) onImageSelected,
    bool initialReservable = true,
    bool initialAutorizacion = false,
    bool initialActivo = true,
    bool initialAllowAlumno = true,
    bool initialAllowProfesor = true,
    bool initialAllowSecretaria = false,
    bool initialAllowProfesorServicio = false,
    bool initialAllowJefeEstudios = false,
    bool initialAllowCafeteria = false,
    String? currentImageUrl,
  }) {
    bool activo = initialActivo;
    bool reservable = initialReservable;
    bool requiereAutorizacion = initialAutorizacion;
    bool allowAlumno = initialAllowAlumno;
    bool allowProfesor = initialAllowProfesor;
    bool allowSecretaria = initialAllowSecretaria;
    bool allowProfesorServicio = initialAllowProfesorServicio;
    bool allowJefeEstudios = initialAllowJefeEstudios;
    bool allowCafeteria = initialAllowCafeteria;
    TipoEspacio tipo = initialTipo;
    Uint8List? imageBytes;

    return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 60,
          ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),


                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),


                          TextField(
                            controller: nombreCtrl,
                            decoration: InputDecoration(labelText: context.tr('admin.spaces.form.name')),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(labelText: context.tr('admin.spaces.form.description')),
                          ),
                          const SizedBox(height: 12),


                          GestureDetector(
                            onTap: () async {
                              final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (img == null) return;
                              final bytes = await img.readAsBytes();
                              setState(() => imageBytes = bytes);
                              onImageSelected(bytes, img.name);
                            },
                            child: Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(19),
                                child: imageBytes != null
                                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                                    : (currentImageUrl != null && currentImageUrl.isNotEmpty
                                    ? RvImage(imageUrl: currentImageUrl, fit: BoxFit.cover)
                                    : const Icon(Icons.add_a_photo_outlined, size: 36)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          DropdownButtonFormField<TipoEspacio>(
                            initialValue: tipo,
                            decoration: InputDecoration(labelText: context.tr('admin.spaces.form.type')),
                            items: [
                              DropdownMenuItem(value: TipoEspacio.pista, child: Text(context.tr('spaces.type.court'))),
                              DropdownMenuItem(value: TipoEspacio.aula, child: Text(context.tr('spaces.type.classroom'))),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => tipo = value);
                              onTipoChanged(value);
                            },
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: precioCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: context.tr('admin.spaces.form.tokens')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: capacidadCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: context.tr('admin.spaces.form.capacity')),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          TextField(
                            controller: ubicacionCtrl,
                            decoration: InputDecoration(labelText: context.tr('admin.spaces.form.location')),
                          ),

                          const SizedBox(height: 12),
                          TextField(
                            controller: antelacionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: context.tr('admin.spaces.form.advanceDays')),
                          ),

                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: Text(context.tr('admin.spaces.form.bookable')),
                            value: reservable,
                            onChanged: (value) {
                              setState(() => reservable = value);
                              onReservableChanged(value);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: Text(context.tr('admin.spaces.form.requiresAuthorization')),
                            value: requiereAutorizacion,
                            onChanged: (value) {
                              setState(() => requiereAutorizacion = value);
                              onAutorizacionChanged(value);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: Text(context.tr('admin.spaces.form.active')),
                            value: activo,
                            onChanged: (value) {
                              setState(() => activo = value);
                              onActivoChanged(value);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 16),
                          Text(context.tr('admin.spaces.form.allowedRoles'), style: const TextStyle(fontWeight: FontWeight.bold)),

                          CheckboxListTile(
                            value: allowAlumno,
                            onChanged: (value) {
                              setState(() => allowAlumno = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.student')),
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: allowProfesor,
                            onChanged: (value) {
                              setState(() => allowProfesor = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.teacher')),
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: allowSecretaria,
                            onChanged: (value) {
                              setState(() => allowSecretaria = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.secretary')),
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: allowProfesorServicio,
                            onChanged: (value) {
                              setState(() => allowProfesorServicio = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.serviceTeacher')),
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: allowJefeEstudios,
                            onChanged: (value) {
                              setState(() => allowJefeEstudios = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.headOfStudies')),
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: allowCafeteria,
                            onChanged: (value) {
                              setState(() => allowCafeteria = value ?? false);
                              onRolesChanged(allowAlumno, allowProfesor, allowSecretaria, allowProfesorServicio, allowJefeEstudios, allowCafeteria);
                            },
                            title: Text(context.tr('admin.users.role.cafeteria')),
                            contentPadding: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 20),
                          RvPrimaryButton(
                              onTap: () => Navigator.pop(context, true),
                              label: context.tr('common.save')
                          ),
                        ],
                      ),
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
                width: 100,
                height: 100,
                child: item.imagenUrl != null
                    ? RvImage(imageUrl: item.imagenUrl!, fit: BoxFit.cover)
                    : Container(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RvBadge(label: '${item.precioTokens} ${context.tr('booking.tokens')}', color: AppColors.primaryBlue),
                      if (!item.activo) RvBadge(label: context.tr('admin.spaces.status.inactive'), color: Colors.grey),
                      if (!item.reservable) RvBadge(label: context.tr('admin.spaces.status.notBookable'), color: AppColors.warning),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const SizedBox(width: 60),
                      RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                      const SizedBox(width: 6),
                      RvGhostIconButton(icon: Icons.schedule_rounded, onTap: onTramos),
                      const SizedBox(width: 6),
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
                        : Container(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 48),
                    ),
                  ),
                ),
                if (!item.activo)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: RvBadge(label: context.tr('admin.spaces.status.inactive'), color: Colors.grey),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${item.precioTokens} ${context.tr('booking.tokens')}',
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
                Text(item.ubicacion ?? context.tr('spaces.no.location'), style: Theme.of(context).textTheme.bodySmall),
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: extent,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => RvSkeleton(width: double.infinity, height: extent, borderRadius: 28),
    );
  }
}
