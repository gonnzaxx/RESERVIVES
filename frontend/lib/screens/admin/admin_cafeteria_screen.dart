import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/models/cafeteria.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/i10n/app_localizations.dart';

final adminCafeteriaProvider = FutureProvider.autoDispose<List<CategoriaCafeteria>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/cafeteria/categorias');
  return (response as List<dynamic>)
      .map((json) => CategoriaCafeteria.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminCafeteriaScreen extends ConsumerWidget {
  const AdminCafeteriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafeteriaAsync = ref.watch(adminCafeteriaProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: RvPageHeader(
                title: context.tr('cafeteria.admin.title'),
                eyebrow: 'Inventario',
                trailing: Row(
                  children: [
                    RvGhostIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      onTap: () => _showSelectionSheet(context, ref),
                    ),
                    const SizedBox(width: 8),
                    RvGhostIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => ref.invalidate(adminCafeteriaProvider),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: cafeteriaAsync.when(
                data: (categorias) {
                  if (categorias.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.local_cafe_outlined,
                      title: context.tr('home.board.emptyTitle'),
                      subtitle: context.tr('home.board.emptySubtitle'),
                    );
                  }

                  if (isWeb) {
                    return _AdminCafeteriaWebGrid(categorias: categorias, ref: ref);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: categorias.length,
                    itemBuilder: (context, index) => _CategoriaExpansionTile(
                      categoria: categorias[index],
                      allCategorias: categorias,
                    ),
                  );
                },
                loading: () => const _AdminCafeteriaSkeleton(),
                error: (error, _) => Center(child: RvApiErrorState(onRetry: () => ref.invalidate(adminCafeteriaProvider))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(context.tr('admin.common.new'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.fastfood_rounded,
              color: AppColors.primaryBlue,
              title: context.tr('cafeteria.admin.new.product.label'),
              subtitle: context.tr('cafeteria.admin.new.product.text'),
              onTap: () {
                Navigator.pop(context);
                final cats = ref.read(adminCafeteriaProvider).value ?? [];
                _createProducto(context, ref, cats);
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.category_rounded,
              color: AppColors.accentPurple,
              title: context.tr('cafeteria.admin.newCatTitle'),
              subtitle: context.tr('cafeteria.admin.new.category.text'),
              onTap: () {
                Navigator.pop(context);
                _showCategoriaForm(context: context, ref: ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategoria(BuildContext context, WidgetRef ref, CategoriaCafeteria cat) async {
    final confirmed = await RvAlerts.confirm(context, title: context.tr('cafeteria.admin.deleteCatTitle'), content: context.tr('cafeteria.admin.deleteCatContent').replaceAll('{name}', cat.nombre), isDestructive: true);
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/cafeteria/categorias/${cat.id}');
      ref.invalidate(adminCafeteriaProvider);
      if (context.mounted) RvAlerts.success(context, context.tr('admin.removed.text'));
    } catch (e) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
  }

  Future<void> _showCategoriaForm({required BuildContext context, required WidgetRef ref, CategoriaCafeteria? categoria}) async {
    final nombreCtrl = TextEditingController(text: categoria?.nombre ?? '');
    final descCtrl = TextEditingController(text: categoria?.descripcion ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(categoria == null ? context.tr('cafeteria.admin.newCatTitle') : context.tr('cafeteria.admin.editCatTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('generic.cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('generic.save'))),
        ],
      ),
    );
    if (result != true) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      if (categoria == null) {
        await apiClient.post('/cafeteria/categorias', body: {'nombre': nombreCtrl.text.trim(), 'descripcion': descCtrl.text.trim(), 'orden': 0});
      } else {
        await apiClient.put('/cafeteria/categorias/${categoria.id}', body: {'nombre': nombreCtrl.text.trim(), 'descripcion': descCtrl.text.trim(), 'orden': categoria.orden});
      }
      ref.invalidate(adminCafeteriaProvider);
    } catch (e) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
  }

  Future<void> _deleteProducto(BuildContext context, WidgetRef ref, ProductoCafeteria producto) async {
    final confirmed = await RvAlerts.confirm(context, title: context.tr('cafeteria.deleteTitle'), content: context.tr('announcements.admin.deleteConfirm').replaceAll('{title}', producto.nombre), isDestructive: true);
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete('/cafeteria/productos/${producto.id}');
      ref.invalidate(adminCafeteriaProvider);
    } catch (e) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
  }

  Future<void> _createProducto(BuildContext context, WidgetRef ref, List<CategoriaCafeteria> categorias) async {
    if (categorias.isEmpty) { RvAlerts.error(context, 'Crea una categoría primero'); return; }
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController(text: '0');
    final descCtrl = TextEditingController();
    String? categoriaId = categorias.first.id;
    bool disponible = true;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showProductoForm(
      context: context, title: context.tr('cafeteria.admin.productLabel'), categorias: categorias, nombreCtrl: nombreCtrl, precioCtrl: precioCtrl, descCtrl: descCtrl,
      initialCategoriaId: categoriaId, onCategoriaChanged: (val) => categoriaId = val, onDisponibleChanged: (val) => disponible = val,
      onImageSelected: (bytes, name) { imageBytes = bytes; imageName = name; },
    );

    if (result != true) return;
    _saveProducto(context, ref, null, nombreCtrl.text, descCtrl.text, precioCtrl.text, categoriaId!, disponible, imageBytes, imageName);
  }

  Future<void> _editProducto(BuildContext context, WidgetRef ref, List<CategoriaCafeteria> categorias, ProductoCafeteria producto) async {
    final nombreCtrl = TextEditingController(text: producto.nombre);
    final precioCtrl = TextEditingController(text: producto.precio.toString());
    final descCtrl = TextEditingController(text: producto.descripcion ?? '');
    String? categoriaId = producto.categoriaId;
    bool disponible = producto.disponible;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showProductoForm(
      context: context, title: context.tr('cafeteria.admin.productLabel'), categorias: categorias, nombreCtrl: nombreCtrl, precioCtrl: precioCtrl, descCtrl: descCtrl,
      initialCategoriaId: categoriaId, initialDisponible: disponible, currentImageUrl: producto.imagenUrl,
      onCategoriaChanged: (val) => categoriaId = val, onDisponibleChanged: (val) => disponible = val,
      onImageSelected: (bytes, name) { imageBytes = bytes; imageName = name; },
    );

    if (result != true) return;
    _saveProducto(context, ref, producto.id, nombreCtrl.text, descCtrl.text, precioCtrl.text, categoriaId!, disponible, imageBytes, imageName, currentUrl: producto.imagenUrl, destacado: producto.destacado);
  }

  Future<void> _saveProducto(BuildContext context, WidgetRef ref, String? id, String nombre, String desc, String precioText, String catId, bool disp, Uint8List? bytes, String? name, {String? currentUrl, bool destacado = false}) async {
    final precio = double.tryParse(precioText.replaceAll(',', '.'));
    if (nombre.isEmpty || precio == null) { RvAlerts.error(context, 'Datos inválidos'); return; }
    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = currentUrl;
      if (bytes != null && name != null) {
        final uploadResponse = await apiClient.postMultipart('/uploads/imagen', fileField: 'file', fileBytes: bytes, fileName: name);
        uploadedImageUrl = uploadResponse['url'] as String?;
      }
      final body = {'categoria_id': catId, 'nombre': nombre, 'descripcion': desc, 'imagen_url': uploadedImageUrl, 'precio': precio, 'disponible': disp, 'destacado': destacado};
      if (id == null) { await apiClient.post('/cafeteria/productos', body: body); }
      else { await apiClient.put('/cafeteria/productos/$id', body: body); }
      ref.invalidate(adminCafeteriaProvider);
    } catch (e) { if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e)); }
  }

  Future<bool?> _showProductoForm({
    required BuildContext context, required String title, required List<CategoriaCafeteria> categorias, required TextEditingController nombreCtrl,
    required TextEditingController precioCtrl, required TextEditingController descCtrl, required Function(String?) onCategoriaChanged,
    required Function(bool) onDisponibleChanged, required Function(Uint8List?, String?) onImageSelected,
    String? initialCategoriaId, bool initialDisponible = true, String? currentImageUrl,
  }) {
    bool disponible = initialDisponible;
    Uint8List? imageBytes;

    return showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setState) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: initialCategoriaId, decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.category_outlined)),
            items: categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
            onChanged: (v) { onCategoriaChanged(v); },
          ),
          const SizedBox(height: 16),
          TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.drive_file_rename_outline))),
          const SizedBox(height: 16),
          TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción', prefixIcon: Icon(Icons.description_outlined))),
          const SizedBox(height: 16),
          TextField(controller: precioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio', prefixIcon: Icon(Icons.euro_symbol), suffixText: '€')),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (img == null) return;
              final bytes = await img.readAsBytes();
              setState(() => imageBytes = bytes);
              onImageSelected(bytes, img.name);
            },
            child: Container(
              height: 140, width: double.infinity,
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor)),
              child: ClipRRect(borderRadius: BorderRadius.circular(23), child: imageBytes != null ? Image.memory(imageBytes!, fit: BoxFit.cover) : (currentImageUrl != null ? RvImage(imageUrl: currentImageUrl, fit: BoxFit.cover) : Icon(Icons.add_a_photo_outlined, color: Theme.of(context).primaryColor, size: 32))),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(title: const Text('Disponible para venta'), value: disponible, onChanged: (v) { setState(() => disponible = v); onDisponibleChanged(v); }, contentPadding: EdgeInsets.zero),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('generic.cancel')))),
            const SizedBox(width: 16),
            Expanded(child: RvPrimaryButton(onTap: () => Navigator.pop(context, true), label: context.tr('generic.save'))),
          ]),
        ])),
      )),
    );
  }
}

// --- Componentes Visuales con el nuevo Design System ---

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context).dividerColor.withOpacity(0.05),
    );
  }
}

class _CategoriaExpansionTile extends ConsumerWidget {
  final CategoriaCafeteria categoria;
  final List<CategoriaCafeteria> allCategorias;
  const _CategoriaExpansionTile({required this.categoria, required this.allCategorias});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        title: Text(categoria.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${categoria.productos.length} productos'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RvGhostIconButton(icon: Icons.edit_outlined, onTap: () => const AdminCafeteriaScreen()._showCategoriaForm(context: context, ref: ref, categoria: categoria)),
            const SizedBox(width: 12),
            RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: () => const AdminCafeteriaScreen()._deleteCategoria(context, ref, categoria)),
          ],
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: categoria.productos.map((p) => _ProductoAdminListTile(producto: p, allCats: allCategorias)).toList(),
      ),
    );
  }
}

class _ProductoAdminListTile extends ConsumerWidget {
  final ProductoCafeteria producto;
  final List<CategoriaCafeteria> allCats;
  const _ProductoAdminListTile({required this.producto, required this.allCats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: RvSurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 60, height: 60,
                child: producto.imagenUrl != null
                    ? RvImage(imageUrl: producto.imagenUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.orange.withOpacity(0.1), child: const Icon(Icons.fastfood_rounded, color: Colors.orange, size: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('${producto.precio.toStringAsFixed(2)} €', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (!producto.disponible) const RvBadge(label: "AGOTADO", color: Colors.grey),
            const SizedBox(width: 8),
            RvGhostIconButton(icon: Icons.edit_outlined, onTap: () => const AdminCafeteriaScreen()._editProducto(context, ref, allCats, producto)),
            const SizedBox(width: 12),
            RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: () => const AdminCafeteriaScreen()._deleteProducto(context, ref, producto)),
          ],
        ),
      ),
    );
  }
}

class _AdminCafeteriaWebGrid extends StatelessWidget {
  final List<CategoriaCafeteria> categorias;
  final WidgetRef ref;
  const _AdminCafeteriaWebGrid({required this.categorias, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 600,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        mainAxisExtent: 450,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final cat = categorias[index];
        return RvSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Expanded(child: Text(cat.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  RvGhostIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => const AdminCafeteriaScreen()._showCategoriaForm(context: context, ref: ref, categoria: cat),
                  ),
                  const SizedBox(width: 12),
                  RvGhostIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => const AdminCafeteriaScreen()._deleteCategoria(context, ref, cat),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cat.productos.length,
                  itemBuilder: (context, i) => _ProductoAdminListTile(producto: cat.productos[i], allCats: categorias),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminCafeteriaSkeleton extends StatelessWidget {
  const _AdminCafeteriaSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: RvSkeleton(height: 100, borderRadius: 28),
      ),
    );
  }
}