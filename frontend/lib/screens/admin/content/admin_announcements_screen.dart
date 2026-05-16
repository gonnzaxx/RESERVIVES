import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

final adminAnnouncementsProvider =
FutureProvider.autoDispose<List<Anuncio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/anuncios/todos');
  return (response as List<dynamic>)
      .map((json) =>
      Anuncio.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anunciosAsync = ref.watch(adminAnnouncementsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    int cols = 1;
    double extent = 160;
    if (width > 1200) {
      cols = 3;
      extent = 340;
    } else if (width > 800) {
      cols = 2;
      extent = 340;
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
                              .tr('admin.announcements.eyebrow')
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
                          context
                              .tr('admin.announcements.title'),
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
                    onTap: () =>
                        _createAnuncio(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _HeaderBtn(
                    icon: Icons.refresh_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    isDark: isDark,
                    onTap: () => ref
                        .invalidate(adminAnnouncementsProvider),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),

            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: RvSearchBar(
                controller: _searchCtrl,
                hintText:
                context.tr('admin.announcements.search'),
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
              child: anunciosAsync.when(
                data: (allAnuncios) {
                  final anuncios = _query.isEmpty
                      ? allAnuncios
                      : allAnuncios
                      .where((a) =>
                  a.titulo
                      .toLowerCase()
                      .contains(_query) ||
                      a.contenido
                          .toLowerCase()
                          .contains(_query))
                      .toList();

                  if (allAnuncios.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.article_outlined,
                      title: context
                          .tr('home.board.emptyTitle'),
                      subtitle: context
                          .tr('home.board.emptySubtitle'),
                    );
                  }
                  if (anuncios.isEmpty) {
                    return RvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('common.noResults'),
                      subtitle: context
                          .tr('common.tryOtherSearch'),
                    );
                  }

                  if (!isWeb) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: anuncios.length,
                      itemBuilder: (context, index) {
                        final anuncio = anuncios[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _MobileCard(
                            anuncio: anuncio,
                            isDark: isDark,
                            theme: theme,
                            onEdit: () => _editAnuncio(context, ref, anuncio),
                            onDelete: () => _deleteAnuncio(context, ref, anuncio),
                          )
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 40 * index),
                                duration: 280.ms,
                              )
                              .slideY(
                                begin: 0.04,
                                delay: Duration(milliseconds: 40 * index),
                                duration: 280.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        );
                      },
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: extent,
                    ),
                    itemCount: anuncios.length,
                    itemBuilder: (context, index) {
                      final anuncio = anuncios[index];
                      return _WebCard(
                        anuncio: anuncio,
                        isDark: isDark,
                        theme: theme,
                        onEdit: () => _editAnuncio(context, ref, anuncio),
                        onDelete: () => _deleteAnuncio(context, ref, anuncio),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 40 * index),
                            duration: 280.ms,
                          )
                          .slideY(
                            begin: 0.04,
                            delay: Duration(milliseconds: 40 * index),
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
                    onRetry: () => ref.invalidate(
                        adminAnnouncementsProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre el formulario para crear o editar un anuncio
  Future<void> _createAnuncio(
      BuildContext context, WidgetRef ref) async {
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
    _processSave(context, ref, null, titleCtrl.text,
        contentCtrl.text, destacado, imageBytes, imageName);
  }

  Future<void> _editAnuncio(BuildContext context,
      WidgetRef ref, Anuncio anuncio) async {
    final titleCtrl =
    TextEditingController(text: anuncio.titulo);
    final contentCtrl =
    TextEditingController(text: anuncio.contenido);
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
    _processSave(context, ref, anuncio.id, titleCtrl.text,
        contentCtrl.text, destacado, imageBytes, imageName,
        currentUrl: anuncio.imagenUrl);
  }

  Future<void> _processSave(
      BuildContext context,
      WidgetRef ref,
      String? id,
      String title,
      String content,
      bool destacado,
      Uint8List? bytes,
      String? name, {
        String? currentUrl,
      }) async {


    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl = currentUrl;

      if (bytes != null && name != null) {
        final uploadResponse = await apiClient.postMultipart(
          '/uploads/imagen',
          fileField: 'file',
          fileBytes: bytes,
          fileName: name,
        );
        uploadedImageUrl = uploadResponse['url'] as String?;
      }

      final body = {
        'titulo': title.trim(),
        'contenido': content.trim(),
        'imagen_url': uploadedImageUrl,
        'destacado': destacado,
      };

      if (id == null) {
        await apiClient.post('/anuncios/', body: body);
      } else {
        await apiClient.put('/anuncios/$id', body: body);
      }

      ref.invalidate(adminAnnouncementsProvider);
      notifyAdminCountersChanged(ref);
      if (context.mounted) {
        RvAlerts.success(
          context,
          context.tr(id == null
              ? 'announcements.admin.publishSuccess'
              : 'announcements.admin.updateSuccess'),
        );
      }
    } catch (error) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(error));
      }
    }
  }

  // Pide confirmación y elimina el anuncio seleccionado
  Future<void> _deleteAnuncio(BuildContext context,
      WidgetRef ref, Anuncio anuncio) async {
    final confirmed = await RvAlerts.confirm(
      context,
      title: context.tr('admin.remove.announcement'),
      content: context
          .tr('announcements.admin.deleteConfirm')
          .replaceAll('{title}', anuncio.titulo),
      confirmLabel: context.tr('admin.remove.text'),
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete('/anuncios/${anuncio.id}');
      ref.invalidate(adminAnnouncementsProvider);
      if (context.mounted) {
        RvAlerts.success(context,
            context.tr('admin.removed.announcement'));
      }
    } catch (e) {
      if (context.mounted) {
        RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
  }

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
                        label: context.tr('announcements.admin.titleLabel'),
                        child: TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        label: context.tr('announcements.admin.contentLabel'),
                        child: TextField(
                          controller: contentCtrl,
                          maxLines: 4,
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
                      const SizedBox(height: 20),
                      _DestacadoSwitch(
                        isDark: isDark,
                        value: destacado,
                        label: context.tr('announcements.featured'),
                        subtitle: context
                            .tr('announcements.admin.featuredSubtitle'),
                        onChanged: (v) {
                          setState(() => destacado = v);
                          onDestacadoChanged(v);
                        },
                      ),
                      const SizedBox(height: 28),
                      RvPrimaryButton(
                        onTap: () {
                          final titulo = titleCtrl.text.trim();
                          final contenido = contentCtrl.text.trim();

                          if (titulo.isEmpty || contenido.isEmpty) {
                            RvAlerts.warning(
                              context,
                              'Por favor, rellena el título y el contenido del anuncio',
                            );
                            return;
                          }

                          Navigator.pop(context, true);
                        },
                        label: context.tr('announcements.publish'),
                        icon: Icons.send_rounded,
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
                  context.tr(
                      'announcements.admin.addImage'),
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

class _DestacadoSwitch extends StatelessWidget {
  final bool isDark;
  final bool value;
  final String label;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _DestacadoSwitch({
    required this.isDark,
    required this.value,
    required this.label,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? AppColors.accentPurple.withValues(alpha: 0.07)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: value
              ? AppColors.accentPurple.withValues(alpha: 0.25)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05)),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.accentPurple.withValues(alpha: 0.12)
                  : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.push_pin_rounded,
              size: 18,
              color: value
                  ? AppColors.accentPurple
                  : theme.hintColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: value ? AppColors.accentPurple : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.accentPurple,
          ),
        ],
      ),
    );
  }
}

class _MobileCard extends StatefulWidget {
  final Anuncio anuncio;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileCard({
    required this.anuncio,
    required this.isDark,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.anuncio.destacado
        ? AppColors.accentPurple
        : AppColors.primaryBlue;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: widget.anuncio.imagenUrl != null
                          ? RvImage(
                          imageUrl:
                          widget.anuncio.imagenUrl!,
                          fit: BoxFit.cover)
                          : Container(
                        color: accentColor
                            .withValues(alpha: 0.10),
                        child: Icon(
                          widget.anuncio.destacado
                              ? Icons.push_pin_rounded
                              : Icons.article_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        if (widget.anuncio.destacado)
                          Padding(
                            padding:
                            const EdgeInsets.only(bottom: 4),
                            child: RvBadge(
                              label: context
                                  .tr('announcements.featured'),
                              color: AppColors.accentPurple,
                              icon: Icons.push_pin_rounded,
                            ),
                          ),
                        Text(
                          widget.anuncio.titulo,
                          style: widget.theme.textTheme
                              .titleSmall
                              ?.copyWith(
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.anuncio.contenido,
                          style: widget.theme.textTheme.bodySmall
                              ?.copyWith(
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: widget.isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(
                                  widget
                                      .anuncio.fechaPublicacion),
                              style: widget.theme.textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: widget.isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
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
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: widget.theme.dividerColor
                  .withValues(alpha: 0.25),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.edit_outlined,
                      label: context.tr('generic.edit'),
                      onTap: widget.onEdit,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: widget.theme.dividerColor
                          .withValues(alpha: 0.20),
                    ),
                  ),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: context.tr('generic.delete'),
                      onTap: widget.onDelete,
                      isDestructive: true,
                    ),
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
  final Anuncio anuncio;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WebCard({
    required this.anuncio,
    required this.isDark,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
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
                      child: widget.anuncio.imagenUrl != null
                          ? RvImage(
                          imageUrl:
                          widget.anuncio.imagenUrl!,
                          fit: BoxFit.cover)
                          : Container(
                        color: AppColors.primaryBlue
                            .withValues(alpha: 0.05),
                        child: Icon(
                          Icons.article_rounded,
                          size: 44,
                          color: AppColors.primaryBlue
                              .withValues(alpha: 0.20),
                        ),
                      ),
                    ),
                  ),
                  if (widget.anuncio.destacado)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: RvBadge(
                        label: context
                            .tr('announcements.featured'),
                        color: AppColors.accentPurple,
                        icon: Icons.push_pin_rounded,
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
                  Text(
                    widget.anuncio.titulo,
                    style: widget.theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.anuncio.contenido,
                    style: widget.theme.textTheme.bodySmall
                        ?.copyWith(
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM, yyyy').format(
                            widget.anuncio.fechaPublicacion),
                        style: widget.theme.textTheme.bodySmall
                            ?.copyWith(
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const Spacer(),
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

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? AppColors.error
        : (Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
    final c = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered
                ? c.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(widget.icon, size: 18, color: c),
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