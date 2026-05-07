import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/cafeteria.dart';
import 'package:reservives/providers/cafeteria_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/screens/cafeteria/product_detail_screen.dart';

class CafeteriaScreen extends ConsumerStatefulWidget {
  const CafeteriaScreen({super.key});

  @override
  ConsumerState<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends ConsumerState<CafeteriaScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String? _activeCategoryId;

  void _scrollToCategory(String id) {
    setState(() => _activeCategoryId = id);
    final key = _categoryKeys[id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuCafeteriaProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
              child: menuAsync.when(
                data: (categorias) {
                  if (categorias.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: RvEmptyState(
                        icon: Icons.local_cafe_outlined,
                        title: context.tr('cafeteria.emptyTitle'),
                        subtitle: context.tr('cafeteria.emptySubtitle'),
                      ),
                    );
                  }

                  for (final c in categorias) {
                    _categoryKeys.putIfAbsent(c.id, () => GlobalKey());
                  }
                  _activeCategoryId ??= categorias.first.id;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, 14, 20, isWeb ? 20 : 4),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context
                                        .tr('cafeteria.eyebrow')
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
                                    context.tr('cafeteria.title'),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (context
                                      .tr('cafeteria.subtitle')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('cafeteria.subtitle'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: isDark
                                            ? AppColors
                                            .darkTextSecondary
                                            : AppColors
                                            .lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _InfoButton(
                              isDark: isDark,
                              theme: theme,
                              onTap: () =>
                                  _showInfo(context, isDark, isWeb),
                            ),
                          ],
                        ).animate().fadeIn(duration: 300.ms),
                      ),

                      _CategoryNav(
                        categorias: categorias,
                        activeCategoryId: _activeCategoryId!,
                        isDark: isDark,
                        theme: theme,
                        onSelect: _scrollToCategory,
                      ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

                      const SizedBox(height: 8),

                      ...categorias.map((categoria) {
                        if (categoria.productos.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          key: _categoryKeys[categoria.id],
                          padding: const EdgeInsets.only(bottom: 36),
                          child: _CategoriaSection(
                            categoria: categoria,
                            isDark: isDark,
                            theme: theme,
                            isWeb: isWeb,
                            onShowDetalle: (producto, catNombre) {
                              final allProductos = <ProductoCafeteria>[];
                              final allCatNombres = <String>[];
                              for (final cat in categorias) {
                                for (final p in cat.productos) {
                                  allProductos.add(p);
                                  allCatNombres.add(cat.nombre);
                                }
                              }
                              final idx = allProductos.indexWhere(
                                  (p) => p.id == producto.id);
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    productos: allProductos,
                                    categoriaNombres: allCatNombres,
                                    initialIndex: idx >= 0 ? idx : 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),

                      const SizedBox(height: 120),
                    ],
                  );
                },
                loading: () =>
                    _CafeteriaSkeleton(isWeb: isWeb, isDark: isDark),
                error: (_, __) => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: RvApiErrorState(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, bool isDark, bool isWeb) {
    if (isWeb) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 440),
            child: _CafeteriaInfoContent(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CafeteriaInfoSheet(isDark: isDark),
      );
    }
  }
}

class _InfoButton extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _InfoButton({
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<_InfoButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hovered
                ? primary.withValues(alpha: 0.14)
                : primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: primary,
          ),
        ),
      ),
    );
  }
}

class _CategoryNav extends StatelessWidget {
  final List<CategoriaCafeteria> categorias;
  final String activeCategoryId;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<String> onSelect;

  const _CategoryNav({
    required this.categorias,
    required this.activeCategoryId,
    required this.isDark,
    required this.theme,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final isActive = cat.id == activeCategoryId;

          return _CategoryChip(
            label: cat.nombre,
            isActive: isActive,
            isDark: isDark,
            theme: theme,
            onTap: () => onSelect(cat.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? primary
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isActive
                  ? Colors.transparent
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Text(
            widget.label,
            style: widget.theme.textTheme.labelMedium?.copyWith(
              color: widget.isActive
                  ? Colors.white
                  : (widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
              fontWeight: widget.isActive
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriaSection extends StatelessWidget {
  final CategoriaCafeteria categoria;
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;
  final void Function(ProductoCafeteria, String) onShowDetalle;

  const _CategoriaSection({
    required this.categoria,
    required this.isDark,
    required this.theme,
    required this.isWeb,
    required this.onShowDetalle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(
            children: [
              Text(
                categoria.nombre,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${categoria.productos.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWeb ? 4 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: isWeb ? 0.75 : 0.68,
            ),
            itemCount: categoria.productos.length,
            itemBuilder: (context, index) {
              return _ProductoCard(
                producto: categoria.productos[index],
                categoriaNombre: categoria.nombre,
                isDark: isDark,
                theme: theme,
                onShowDetalle: onShowDetalle,
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 40 * index))
                  .slideY(
                begin: 0.06,
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductoCard extends StatefulWidget {
  final ProductoCafeteria producto;
  final String categoriaNombre;
  final bool isDark;
  final ThemeData theme;
  final void Function(ProductoCafeteria, String) onShowDetalle;

  const _ProductoCard({
    required this.producto,
    required this.categoriaNombre,
    required this.isDark,
    required this.theme,
    required this.onShowDetalle,
  });

  @override
  State<_ProductoCard> createState() => _ProductoCardState();
}

class _ProductoCardState extends State<_ProductoCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onShowDetalle(widget.producto, widget.categoriaNombre);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _hovered
                        ? AppShadows.deep(context)
                        : AppShadows.soft(context),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.producto.imagenUrl != null
                            ? RvImage(
                          imageUrl: widget.producto.imagenUrl!,
                          fit: BoxFit.cover,
                          fallbackWidget: const _FoodFallback(),
                        )
                            : const _FoodFallback(),
                        if (widget.producto.destacado)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius:
                                BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.star_rounded,
                                      size: 11,
                                      color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Top',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!widget.producto.disponible)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: 0.45),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.55),
                                    borderRadius:
                                    BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    context.tr(
                                        'spaces.noAvailability'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.producto.precio.toStringAsFixed(2)} ${context.tr('cafeteria.currency')}',
                      style: widget.theme.textTheme.labelMedium
                          ?.copyWith(
                        color: widget.theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
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

class _CafeteriaInfoContent extends StatelessWidget {
  const _CafeteriaInfoContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('cafeteria.infoTitle'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('cafeteria.infoContent'),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 28),
          RvPrimaryButton(
            label: context.tr('generic.understood'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CafeteriaInfoSheet extends StatelessWidget {
  final bool isDark;
  const _CafeteriaInfoSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: const _CafeteriaInfoContent(),
    );
  }
}

class _CafeteriaSkeleton extends StatelessWidget {
  final bool isWeb;
  final bool isDark;

  const _CafeteriaSkeleton(
      {required this.isWeb, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RvSkeleton(width: 80, height: 12, borderRadius: 6),
          const SizedBox(height: 10),
          const RvSkeleton(width: 200, height: 32, borderRadius: 8),
          const SizedBox(height: 8),
          const RvSkeleton(width: 260, height: 14, borderRadius: 6),
          const SizedBox(height: 24),
          Row(
            children: List.generate(
              3,
                  (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RvSkeleton(
                    width: 80 + (i * 10).toDouble(),
                    height: 36,
                    borderRadius: 22),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const RvSkeleton(width: 130, height: 22, borderRadius: 6),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isWeb ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isWeb ? 0.75 : 0.68,
            children: List.generate(
              isWeb ? 8 : 4,
                  (_) => const RvSkeleton(
                  height: 220, borderRadius: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodFallback extends StatelessWidget {
  const _FoodFallback();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkHeroGradient
            : const LinearGradient(
          colors: [Color(0xFFFFFBF1), Color(0xFFFFF0D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 36,
          color: AppColors.warning,
        ),
      ),
    );
  }
}