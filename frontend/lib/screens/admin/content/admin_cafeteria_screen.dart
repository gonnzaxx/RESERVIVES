import 'dart:typed_data';

import 'package:flutter/material.dart';
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

class AdminCafeteriaScreen extends ConsumerStatefulWidget {
  const AdminCafeteriaScreen({super.key});

  @override
  ConsumerState<AdminCafeteriaScreen> createState() => _AdminCafeteriaScreenState();
}

class _AdminCafeteriaScreenState extends ConsumerState<AdminCafeteriaScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CategoriaCafeteria> _filtered(List<CategoriaCafeteria> all) {
    if (_query.isEmpty) return all;
    final q = _query;
    return all
        .map((cat) {
      if (cat.nombre.toLowerCase().contains(q)) return cat;
      final matchingProducts = cat.productos.where((p) => p.nombre.toLowerCase().contains(q)).toList();
      if (matchingProducts.isEmpty) return null;
      return CategoriaCafeteria(
        id: cat.id,
        nombre: cat.nombre,
        descripcion: cat.descripcion,
        orden: cat.orden,
        activa: cat.activa,
        productos: matchingProducts,
      );
    })
        .whereType<CategoriaCafeteria>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cafeteriaAsync = ref.watch(adminCafeteriaProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                          context.tr('cafeteria.admin.eyebrow').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('cafeteria.admin.title'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    onTap: () => _showSelectionSheet(context, ref),
                  ),
                  const SizedBox(width: 8), // Separación de 8 como en la anterior
                  _HeaderBtn(
                    icon: Icons.refresh_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    isDark: isDark,
                    onTap: () => ref.invalidate(adminCafeteriaProvider),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: RvSearchBar(
                controller: _searchCtrl,
                hintText: context.tr('cafeteria.admin.search'),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                onClear: _query.isNotEmpty ? () { _searchCtrl.clear(); setState(() => _query = ''); } : null,
              ),
            ),
            Expanded(
              child: cafeteriaAsync.when(
                data: (allCategorias) {
                  if (allCategorias.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.local_cafe_outlined,
                      title: context.tr('home.board.emptyTitle'),
                      subtitle: context.tr('home.board.emptySubtitle'),
                    );
                  }

                  final categorias = _filtered(allCategorias);

                  if (categorias.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('common.noResults'),
                      subtitle: context.tr('common.tryOtherSearch'),
                    );
                  }

                  if (isWeb) {
                    return _AdminCafeteriaWebGrid(
                      categorias: categorias,
                      allCategorias: allCategorias,
                      onEditCategoria: (cat) => _showCategoriaForm(context: context, ref: ref, categoria: cat),
                      onDeleteCategoria: (cat) => _deleteCategoria(context, ref, cat),
                      onEditProducto: (cats, p) => _editProducto(context, ref, cats, p),
                      onDeleteProducto: (p) => _deleteProducto(context, ref, p),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: categorias.length,
                    itemBuilder: (context, index) => _CategoriaExpansionTile(
                      categoria: categorias[index],
                      allCategorias: allCategorias,
                      onEdit: () => _showCategoriaForm(context: context, ref: ref, categoria: categorias[index]),
                      onDelete: () => _deleteCategoria(context, ref, categorias[index]),
                      onEditProducto: (p) => _editProducto(context, ref, allCategorias, p),
                      onDeleteProducto: (p) => _deleteProducto(context, ref, p),
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
            RvSheetHeader(onClose: () => Navigator.pop(context)),
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
    final isEdit = categoria != null;
    final theme = Theme.of(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setState) {
          final isValid = nombreCtrl.text.trim().isNotEmpty;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(ctx).padding.top + 60, 16,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RvSheetHeader(onClose: () => Navigator.pop(ctx, false)),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.add_rounded,
                          color: AppColors.accentPurple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? context.tr('cafeteria.admin.editCatTitle')
                                : context.tr('cafeteria.admin.newCatTitle'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            isEdit
                                ? context.tr('cafeteria.admin.editCatSubtitle')
                                : context.tr('cafeteria.admin.newCatSubtitle'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Campo nombre
                  Text(
                    context.tr('admin.spaces.form.name'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.hintColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.tr('cafeteria.admin.catNameHint'),
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.accentPurple.withValues(alpha:0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Campo descripción
                  Text(
                    context.tr('cafeteria.admin.descriptionLabel'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.hintColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.tr('cafeteria.admin.catDescHint'),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.description_outlined, size: 20),
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.accentPurple.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            context.tr('generic.cancel'),
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: RvPrimaryButton(
                          backgroundColor: AppColors.accentPurple,
                          onTap: isValid ? () => Navigator.pop(ctx, true) : null,
                          label: isEdit
                              ? context.tr('generic.save')
                              : context.tr('cafeteria.admin.createCategory'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != true) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      if (categoria == null) {
        await apiClient.post('/cafeteria/categorias', body: {
          'nombre': nombreCtrl.text.trim(),
          'descripción': descCtrl.text.trim(),
          'orden': 0,
        });
      } else {
        await apiClient.put('/cafeteria/categorias/${categoria.id}', body: {
          'nombre': nombreCtrl.text.trim(),
          'descripción': descCtrl.text.trim(),
          'orden': categoria.orden,
        });
      }
      ref.invalidate(adminCafeteriaProvider);
      if (context.mounted) {
        RvAlerts.success(
          context,
          isEdit
              ? context.tr('cafeteria.admin.editCatSuccess')
              : context.tr('cafeteria.admin.newCatSuccess'),
        );
      }
    } catch (e) {
      if (context.mounted) RvAlerts.error(context, toFriendlyErrorMessage(e));
    }
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
    if (categorias.isEmpty) {
      RvAlerts.error(context, context.tr('cafeteria.admin.error.noCategory'));
      return;
    }
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController(text: '0');
    final descCtrl = TextEditingController();
    String? categoriaId = categorias.first.id;
    bool disponible = true;
    bool destacado = false;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showProductoForm(
      context: context, title: context.tr('cafeteria.admin.productLabel'), categorias: categorias, nombreCtrl: nombreCtrl, precioCtrl: precioCtrl, descCtrl: descCtrl,
      initialCategoriaId: categoriaId, onCategoriaChanged: (val) => categoriaId = val, onDisponibleChanged: (val) => disponible = val,
      onDestacadoChanged: (val) => destacado = val,
      onImageSelected: (bytes, name) { imageBytes = bytes; imageName = name; },
    );

    if (result != true) return;
    _saveProducto(context, ref, null, nombreCtrl.text, descCtrl.text, precioCtrl.text, categoriaId!, disponible, imageBytes, imageName, destacado: destacado);
  }

  Future<void> _editProducto(BuildContext context, WidgetRef ref, List<CategoriaCafeteria> categorias, ProductoCafeteria producto) async {
    final nombreCtrl = TextEditingController(text: producto.nombre);
    final precioCtrl = TextEditingController(text: producto.precio.toString());
    final descCtrl = TextEditingController(text: producto.descripcion ?? '');
    String? categoriaId = producto.categoriaId;
    bool disponible = producto.disponible;
    bool destacado = producto.destacado;
    Uint8List? imageBytes;
    String? imageName;

    final result = await _showProductoForm(
      context: context, title: context.tr('cafeteria.admin.productLabel'), categorias: categorias, nombreCtrl: nombreCtrl, precioCtrl: precioCtrl, descCtrl: descCtrl,
      initialCategoriaId: categoriaId, initialDisponible: disponible, initialDestacado: producto.destacado, currentImageUrl: producto.imagenUrl,
      onCategoriaChanged: (val) => categoriaId = val, onDisponibleChanged: (val) => disponible = val,
      onDestacadoChanged: (val) => destacado = val,
      onImageSelected: (bytes, name) { imageBytes = bytes; imageName = name; },
    );

    if (result != true) return;
    _saveProducto(context, ref, producto.id, nombreCtrl.text, descCtrl.text, precioCtrl.text, categoriaId!, disponible, imageBytes, imageName, currentUrl: producto.imagenUrl, destacado: destacado);
  }

  Future<void> _saveProducto(BuildContext context, WidgetRef ref, String? id, String nombre, String desc, String precioText, String catId, bool disp, Uint8List? bytes, String? name, {String? currentUrl, bool destacado = false}) async {
    final precio = double.tryParse(precioText.replaceAll(',', '.'));
    if (nombre.isEmpty || precio == null) {
      RvAlerts.error(context, context.tr('admin.common.invalidData'));
      return;
    }
    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = currentUrl;
      if (bytes != null && name != null) {
        final uploadResponse = await apiClient.postMultipart('/uploads/imagen', fileField: 'file', fileBytes: bytes, fileName: name);
        uploadedImageUrl = uploadResponse['url'] as String?;
      }
      final body = {'categoria_id': catId, 'nombre': nombre, 'descripción': desc, 'imagen_url': uploadedImageUrl, 'precio': precio, 'disponible': disp, 'destacado': destacado};
      if (id == null) { await apiClient.post('/cafeteria/productos', body: body); }
      else {
        await apiClient.put('/cafeteria/productos/$id', body: body);
      }

      ref.invalidate(adminCafeteriaProvider);
    } catch (e) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
  }

  Future<bool?> _showProductoForm({
    required BuildContext context, required String title, required List<CategoriaCafeteria> categorias, required TextEditingController nombreCtrl,
    required TextEditingController precioCtrl, required TextEditingController descCtrl, required Function(String?) onCategoriaChanged,
    required Function(bool) onDisponibleChanged, required Function(bool) onDestacadoChanged, required Function(Uint8List?, String?) onImageSelected,
    String? initialCategoriaId, bool initialDisponible = true, bool initialDestacado = false, String? currentImageUrl,
  }) {
    bool disponible = initialDisponible;
    bool destacado = initialDestacado;
    Uint8List? imageBytes;

    return showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setState) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            RvSheetHeader(onClose: () => Navigator.pop(context, false)),
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              initialValue: initialCategoriaId,
              decoration: InputDecoration(
                  labelText: context.tr('cafeteria.admin.categoriaLabel'),
                  prefixIcon: Icon(Icons.category_outlined)
              ),
              items: categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
              onChanged: (v) { onCategoriaChanged(v); },
            ),

            const SizedBox(height: 16),
            TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: context.tr('admin.spaces.form.name'), prefixIcon: const Icon(Icons.drive_file_rename_outline))),
            const SizedBox(height: 16),
            TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: context.tr('cafeteria.admin.descriptionLabel'), prefixIcon: const Icon(Icons.description_outlined))),
            const SizedBox(height: 16),
            TextField(controller: precioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('cafeteria.admin.priceLabel'), prefixIcon: const Icon(Icons.euro_symbol), suffixText: '€')),
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
            SwitchListTile(title: Text(context.tr('cafeteria.admin.availableForSale')), value: disponible, onChanged: (v) { setState(() => disponible = v); onDisponibleChanged(v); }, contentPadding: EdgeInsets.zero),
            SwitchListTile(
              title: Text(context.tr('cafeteria.admin.featured')),
              secondary: const Icon(Icons.star_rounded, color: Color(0xFFFFB800)),
              value: destacado,
              onChanged: (v) { setState(() => destacado = v); onDestacadoChanged(v); },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('generic.cancel')))),
              const SizedBox(width: 16),
              Expanded(child: RvPrimaryButton(onTap: () => Navigator.pop(context, true), label: context.tr('generic.save'))),
            ]),
          ])),
        ),
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
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context).dividerColor.withValues(alpha: 0.05),
    );
  }
}

class _CategoriaExpansionTile extends StatelessWidget {
  final CategoriaCafeteria categoria;
  final List<CategoriaCafeteria> allCategorias;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(ProductoCafeteria) onEditProducto;
  final Function(ProductoCafeteria) onDeleteProducto;

  const _CategoriaExpansionTile({
    required this.categoria,
    required this.allCategorias,
    required this.onEdit,
    required this.onDelete,
    required this.onEditProducto,
    required this.onDeleteProducto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
        title: Text(categoria.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${categoria.productos.length} productos'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
            const SizedBox(width: 12),
            RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
          ],
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: categoria.productos.map((p) => _ProductoAdminListTile(
          producto: p,
          onEdit: () => onEditProducto(p),
          onDelete: () => onDeleteProducto(p),
        )).toList(),
      ),
    );
  }
}

class _ProductoAdminListTile extends StatelessWidget {
  final ProductoCafeteria producto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductoAdminListTile({
    required this.producto,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                    : Container(color: Colors.orange.withValues(alpha: 0.1), child: const Icon(Icons.fastfood_rounded, color: Colors.orange, size: 24)),
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
            if (!producto.disponible) RvBadge(label: context.tr('cafeteria.admin.outOfStock'), color: Colors.grey),
            const SizedBox(width: 8),
            RvGhostIconButton(icon: Icons.edit_outlined, onTap: onEdit),
            const SizedBox(width: 12),
            RvGhostIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

class _AdminCafeteriaWebGrid extends StatelessWidget {
  final List<CategoriaCafeteria> categorias;
  final List<CategoriaCafeteria> allCategorias;
  final Function(CategoriaCafeteria) onEditCategoria;
  final Function(CategoriaCafeteria) onDeleteCategoria;
  final Function(List<CategoriaCafeteria>, ProductoCafeteria) onEditProducto;
  final Function(ProductoCafeteria) onDeleteProducto;

  const _AdminCafeteriaWebGrid({
    required this.categorias,
    required this.allCategorias,
    required this.onEditCategoria,
    required this.onDeleteCategoria,
    required this.onEditProducto,
    required this.onDeleteProducto,
  });

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
                    onTap: () => onEditCategoria(cat),
                  ),
                  const SizedBox(width: 12),
                  RvGhostIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => onDeleteCategoria(cat),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cat.productos.length,
                  itemBuilder: (context, i) => _ProductoAdminListTile(
                    producto: cat.productos[i],
                    onEdit: () => onEditProducto(allCategorias, cat.productos[i]),
                    onDelete: () => onDeleteProducto(cat.productos[i]),
                  ),
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