import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/cafeteria.dart';
import 'package:reservives/providers/cafeteria_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class CafeteriaScreen extends ConsumerStatefulWidget {
  const CafeteriaScreen({super.key});

  @override
  ConsumerState<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends ConsumerState<CafeteriaScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};

  void _scrollToCategory(String id) {
    final key = _categoryKeys[id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
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
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(menuCafeteriaProvider.future),
              child: menuAsync.when(
                data: (categorias) {
                  if (categorias.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        RvEmptyState(
                          icon: Icons.local_cafe_outlined,
                          title: context.tr('cafeteria.emptyTitle'),
                          subtitle: context.tr('cafeteria.emptySubtitle'),
                        ),
                      ],
                    );
                  }

                  for (var c in categorias) {
                    _categoryKeys.putIfAbsent(c.id, () => GlobalKey());
                  }

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
                              child: RvPageHeader(
                                eyebrow: context.tr('cafeteria.eyebrow'),
                                title: context.tr('cafeteria.title'),
                                subtitle: context.tr('cafeteria.subtitle'),
                                trailing: RvGhostIconButton(
                                  icon: Icons.info_outline_rounded,
                                  onTap: () => _showInfo(context, isWeb),
                                ),
                              ).animate().fadeIn(),
                            ),
                            Container(
                              height: 50,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemCount: categorias.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cat = categorias[index];
                                  return ActionChip(
                                    label: Text(cat.nombre),
                                    onPressed: () => _scrollToCategory(cat.id),
                                    backgroundColor: Theme.of(context).cardColor,
                                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...categorias.map((categoria) {
                        if (categoria.productos.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }

                        return SliverPadding(
                          key: _categoryKeys[categoria.id],
                          padding: const EdgeInsets.only(bottom: 32),
                          sliver: _CategoriaGridSection(categoria: categoria, isWeb: isWeb),
                        );
                      }),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  );
                },
                loading: () => _buildSkeleton(context, isWeb),
                error: (error, _) => const Center(child: RvApiErrorState()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, bool isWeb) {
    if (isWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: const _CafeteriaInfoContent(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _CafeteriaInfoSheet(),
      );
    }
  }

  Widget _buildSkeleton(BuildContext context, bool isWeb) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const RvSkeleton(width: 100, height: 14),
          const SizedBox(height: 10),
          const RvSkeleton(width: 200, height: 28),
          const SizedBox(height: 40),
          const RvSkeleton(width: 150, height: 22),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: isWeb ? 4 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.7,
              children: List.generate(isWeb ? 8 : 4, (index) =>
              const RvSkeleton(height: 220, borderRadius: 20)
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaGridSection extends StatelessWidget {
  final CategoriaCafeteria categoria;
  final bool isWeb;

  const _CategoriaGridSection({required this.categoria, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              categoria.nombre,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWeb ? 4 : 2,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: isWeb ? 0.75 : 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return _ProductoCard(producto: categoria.productos[index])
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * index))
                    .slideY(begin: 0.1, curve: Curves.easeOutQuad);
              },
              childCount: categoria.productos.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final ProductoCafeteria producto;

  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: producto.imagenUrl != null
                    ? RvImage(
                  imageUrl: producto.imagenUrl!,
                  fit: BoxFit.cover,
                  fallbackWidget: const _FoodFallback(),
                )
                    : const _FoodFallback(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${producto.precio.toStringAsFixed(2)} ${context.tr('cafeteria.currency')}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
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

class _CafeteriaInfoContent extends StatelessWidget {
  const _CafeteriaInfoContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded, color: AppColors.primaryBlue, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('cafeteria.infoTitle'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('cafeteria.infoContent'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: RvPrimaryButton(
              label: "Entendido",
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CafeteriaInfoSheet extends StatelessWidget {
  const _CafeteriaInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: const _CafeteriaInfoContent(),
    );
  }
}

class _FoodFallback extends StatelessWidget {
  const _FoodFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkHeroGradient
            : const LinearGradient(
          colors: [Color(0xFFFFFBF1), Color(0xFFFFF0D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 38, color: AppColors.warning),
      ),
    );
  }
}