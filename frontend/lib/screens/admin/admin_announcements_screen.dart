import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/anuncio.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

/// Provider que gestiona la carga de anuncios desde la API.
final adminAnnouncementsProvider = FutureProvider.autoDispose<List<Anuncio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/anuncios/todos');
  return (response as List<dynamic>)
      .map((json) => Anuncio.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminAnnouncementsScreen extends ConsumerWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anunciosAsync = ref.watch(adminAnnouncementsProvider);
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    double extent = 160;
    if (width > 1200) {
      crossAxisCount = 3;
      extent = 340;
    } else if (width > 800) {
      crossAxisCount = 2;
      extent = 340;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: RvPageHeader(
                title: context.tr('admin.announcements.title'),
                eyebrow: context.tr('admin.announcements.eyebrow'),
                trailing: Row(
                  children: [
                    RvGhostIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      onTap: () => _createAnuncio(context, ref),
                    ),
                    const SizedBox(width: 8),
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(adminAnnouncementsProvider),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: anunciosAsync.when(
                data: (anuncios) {
                  if (anuncios.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.article_outlined,
                      title: context.tr('home.board.emptyTitle'),
                      subtitle: context.tr('home.board.emptySubtitle'),
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
                    itemCount: anuncios.length,
                    itemBuilder: (context, index) {
                      final isWeb = width > 800;
                      final anuncio = anuncios[index];
                      return isWeb
                          ? _AdminAnnouncementWebCard(
                        anuncio: anuncio,
                        onEdit: () => _editAnuncio(context, ref, anuncio),
                        onDelete: () => _deleteAnuncio(context, ref, anuncio),
                      )
                          : _AdminAnnouncementMobileCard(
                        anuncio: anuncio,
                        onEdit: () => _editAnuncio(context, ref, anuncio),
                        onDelete: () => _deleteAnuncio(context, ref, anuncio),
                      );
                    },
                  );
                },
                loading: () => _AdminAnnouncementsSkeleton(crossAxisCount: crossAxisCount, extent: extent),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(adminAnnouncementsProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inicializa el flujo para crear un nuevo anuncio.
  Future<void> _createAnuncio(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool destacado = false;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showAnuncioForm(
      context: context,
      title: context.tr('admin.new.announcement'),
      titleCtrl: titleCtrl,
      contentCtrl: contentCtrl,
      onDestacadoChanged: (val) => destacado = val,
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
    );

    if (result != true) return;
    _processSave(context, ref, null, titleCtrl.text, contentCtrl.text, destacado, imageBytes, imageName);
  }

  /// Prepara los datos actuales y abre el formulario para editar un anuncio existente.
  Future<void> _editAnuncio(BuildContext context, WidgetRef ref, Anuncio anuncio) async {
    final titleCtrl = TextEditingController(text: anuncio.titulo);
    final contentCtrl = TextEditingController(text: anuncio.contenido);
    bool destacado = anuncio.destacado;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showAnuncioForm(
      context: context,
      title: context.tr('announcements.admin.editTitle'),
      titleCtrl: titleCtrl,
      contentCtrl: contentCtrl,
      initialDestacado: destacado,
      currentImageUrl: anuncio.imagenUrl,
      onDestacadoChanged: (val) => destacado = val,
      onImageSelected: (bytes, name) {
        imageBytes = bytes;
        imageName = name;
      },
    );

    if (result != true) return;
    _processSave(context, ref, anuncio.id, titleCtrl.text, contentCtrl.text, destacado, imageBytes, imageName, currentUrl: anuncio.imagenUrl);
  }

  /// Lógica unificada para POST (crear) y PUT (editar).
  Future<void> _processSave(BuildContext context, WidgetRef ref, String? id, String title, String content, bool destacado, Uint8List? bytes, String? name, {String? currentUrl}) async {
    if (title.trim().isEmpty || content.trim().isEmpty) {
      RvAlerts.error(context, context.tr('admin.announcement.error.fields'));
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = currentUrl;

      // Si el usuario seleccionó una imagen nueva, la subimos primero
      if (bytes != null && name != null) {
        final uploadResponse = await apiClient.postMultipart('/uploads/imagen', fileField: 'file', fileBytes: bytes, fileName: name);
        uploadedImageUrl = uploadResponse['url'] as String?;
      }

      final body = {'titulo': title.trim(), 'contenido': content.trim(), 'imagen_url': uploadedImageUrl, 'destacado': destacado};

      if (id == null) {
        await apiClient.post('/anuncios/', body: body);
      } else {
        await apiClient.put('/anuncios/$id', body: body);
      }

      ref.invalidate(adminAnnouncementsProvider);
      notifyAdminCountersChanged(ref);
      if (context.mounted) RvAlerts.success(context, context.tr(id == null ? 'announcements.admin.publishSuccess' : 'announcements.admin.updateSuccess'));
    } catch (error) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(error));
    }
  }

  /// Elimina un anuncio tras la confirmación del usuario.
  Future<void> _deleteAnuncio(BuildContext context, WidgetRef ref, Anuncio anuncio) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.remove.announcement'),
      content: context.tr('announcements.admin.deleteConfirm').replaceAll('{title}', anuncio.titulo),
      confirmLabel: context.tr('admin.remove.text'),
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/anuncios/${anuncio.id}');
      ref.invalidate(adminAnnouncementsProvider);
      if (context.mounted) RvAlerts.success(context, context.tr('admin.removed.announcement'));
    } catch (e) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e));
    }
  }

  /// Formulario en ModalBottomSheet para la entrada de datos.
  Future<bool?> _showAnuncioForm({
    required BuildContext context,
    required String title,
    required TextEditingController titleCtrl,
    required TextEditingController contentCtrl,
    required Function(bool) onDestacadoChanged,
    required Function(Uint8List?, String?) onImageSelected,
    bool initialDestacado = false,
    String? currentImageUrl,
  }) {
    bool destacado = initialDestacado;
    Uint8List? imageBytes;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
          child: Container(
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // Campos de entrada
                TextField(controller: titleCtrl, decoration: InputDecoration(labelText: context.tr('announcements.admin.titleLabel'), prefixIcon: const Icon(Icons.title_rounded))),
                const SizedBox(height: 16),
                TextField(controller: contentCtrl, maxLines: 4, decoration: InputDecoration(labelText: context.tr('announcements.admin.contentLabel'), alignLabelWithHint: true, prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_outlined)))),
                const SizedBox(height: 24),

                // Selector de Imagen
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
                      child: imageBytes != null
                          ? Image.memory(imageBytes!, fit: BoxFit.cover)
                          : (currentImageUrl != null ? RvImage(imageUrl: currentImageUrl, fit: BoxFit.cover) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_outlined, size: 32), const SizedBox(height: 8), Text(context.tr('announcements.admin.addImage'))])),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Opción de destacar anuncio
                SwitchListTile(
                  title: Text(context.tr('announcements.featured')),
                  subtitle: Text(context.tr('announcements.admin.featuredSubtitle'), style: const TextStyle(fontSize: 12)),
                  value: destacado,
                  onChanged: (v) { setState(() => destacado = v); onDestacadoChanged(v); },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: Theme.of(context).cardColor,
                ),
                const SizedBox(height: 32),

                // Botones de acción
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('generic.cancel')))),
                  const SizedBox(width: 16),
                  Expanded(child: RvPrimaryButton(onTap: () => Navigator.pop(context, true), label: context.tr('announcements.publish'))),
                ]),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _AdminAnnouncementMobileCard extends StatelessWidget {
  final Anuncio anuncio;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AdminAnnouncementMobileCard({required this.anuncio, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = anuncio.destacado ? AppColors.accentPurple : AppColors.primaryBlue;

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 64, height: 64,
                    child: anuncio.imagenUrl != null
                        ? RvImage(imageUrl: anuncio.imagenUrl!, fit: BoxFit.cover)
                        : Container(
                      color: accentColor.withValues(alpha: 0.1),
                      child: Icon(
                        anuncio.destacado ? Icons.push_pin_rounded : Icons.article_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),


                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (anuncio.destacado)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RvBadge(
                            label: context.tr('announcements.featured'),
                            color: AppColors.accentPurple,
                            icon: Icons.push_pin_rounded,
                          ),
                        ),
                      Text(
                        anuncio.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        anuncio.contenido,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 11, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(anuncio.fechaPublicacion),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),


          Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha: 0.15)),


          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_outlined,
                    label: context.tr('generic.edit'),
                    onTap: onEdit,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
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

class _AdminAnnouncementWebCard extends StatelessWidget {
  final Anuncio anuncio;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AdminAnnouncementWebCard({required this.anuncio, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: anuncio.imagenUrl != null
                      ? RvImage(imageUrl: anuncio.imagenUrl!, fit: BoxFit.cover)
                      : Container(color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      child: Icon(Icons.article_rounded, size: 48, color: AppColors.primaryBlue.withValues(alpha: 0.2))))),
              if(anuncio.destacado) Positioned(top: 12, right: 12, child: RvBadge(label: "DESTACADO", color: AppColors.accentPurple, icon: Icons.push_pin_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(anuncio.titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(anuncio.contenido, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Row(children: [
                Text(DateFormat('dd MMMM, yyyy').format(anuncio.fechaPublicacion), style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const Spacer(),
                RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
                const SizedBox(width: 8),
                RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _AdminAnnouncementsSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double extent;
  const _AdminAnnouncementsSkeleton({required this.crossAxisCount, required this.extent});

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