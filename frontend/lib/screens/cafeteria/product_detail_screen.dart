import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/cafeteria.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final List<ProductoCafeteria> productos;
  final List<String> categoriaNombres;
  final int initialIndex;

  const ProductDetailScreen({
    super.key,
    required this.productos,
    required this.categoriaNombres,
    required this.initialIndex,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final location = GoRouterState.of(context).uri.path;
    if (!location.startsWith('/cafeteria')) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              children: [
                _Header(
                  currentIndex: _currentIndex,
                  total: widget.productos.length,
                  isDark: isDark,
                  theme: theme,
                  isWeb: isWeb,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: widget.productos.length,
                        onPageChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return _ProductPage(
                            producto: widget.productos[index],
                            categoriaNombre: widget.categoriaNombres[index],
                            isDark: isDark,
                            theme: theme,
                            isWeb: isWeb,
                          );
                        },
                      ),
                      if (isWeb && widget.productos.length > 1)
                        Positioned.fill(
                          child: _WebNavArrows(
                            currentIndex: _currentIndex,
                            total: widget.productos.length,
                            isDark: isDark,
                            theme: theme,
                            onPrevious: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ),
                            onNext: () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _PageIndicator(
                  currentIndex: _currentIndex,
                  total: widget.productos.length,
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int currentIndex;
  final int total;
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;

  const _Header({
    required this.currentIndex,
    required this.total,
    required this.isDark,
    required this.theme,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 16 : 8),
      child: Row(
        children: [
          RvGhostIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('cafeteria.eyebrow').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('cafeteria.detail.title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${currentIndex + 1} / $total',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ProductPage extends StatelessWidget {
  final ProductoCafeteria producto;
  final String categoriaNombre;
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;

  const _ProductPage({
    required this.producto,
    required this.categoriaNombre,
    required this.isDark,
    required this.theme,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    if (isWeb) return _buildWebLayout(context);
    return _buildMobileLayout(context);
  }

  Widget _buildWebLayout(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: _ProductImage(producto: producto, isDark: isDark),
              ),
            ),
          ),
          const SizedBox(width: 36),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: _ProductInfo(
                producto: producto,
                categoriaNombre: categoriaNombre,
                isDark: isDark,
                theme: theme,
                primary: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _ProductImage(producto: producto, isDark: isDark),
            ),
          ),
          const SizedBox(height: 24),
          _ProductInfo(
            producto: producto,
            categoriaNombre: categoriaNombre,
            isDark: isDark,
            theme: theme,
            primary: primary,
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final ProductoCafeteria producto;
  final bool isDark;

  const _ProductImage({
    required this.producto,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        producto.imagenUrl != null
            ? RvImage(
                imageUrl: producto.imagenUrl!,
                fit: BoxFit.cover,
                fallbackWidget: const _FoodFallback(),
              )
            : const _FoodFallback(),
        if (producto.destacado)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('cafeteria.detail.featured'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!producto.disponible)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    context.tr('spaces.noAvailability'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final ProductoCafeteria producto;
  final String categoriaNombre;
  final bool isDark;
  final ThemeData theme;
  final Color primary;

  const _ProductInfo({
    required this.producto,
    required this.categoriaNombre,
    required this.isDark,
    required this.theme,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RvBadge(
              label: producto.disponible
                  ? context.tr('spaces.availability')
                  : context.tr('spaces.noAvailability'),
              color: producto.disponible ? AppColors.success : AppColors.error,
              icon: producto.disponible
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          producto.nombre,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          categoriaNombre,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 8,
              height: 3,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (producto.descripcion != null &&
            producto.descripcion!.trim().isNotEmpty) ...[
          Text(
            context.tr('cafeteria.detail.description'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            producto.descripcion!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        ] else ...[
          Text(
            context.tr('cafeteria.detail.noDescription'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadii.l),
            border: Border.all(
              color: primary.withValues(alpha: 0.14),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sell_rounded,
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('cafeteria.detail.price'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${producto.precio.toStringAsFixed(2)} ${context.tr('cafeteria.currency')}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WebNavArrows extends StatelessWidget {
  final int currentIndex;
  final int total;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WebNavArrows({
    required this.currentIndex,
    required this.total,
    required this.isDark,
    required this.theme,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavArrowButton(
            icon: Icons.chevron_left_rounded,
            visible: currentIndex > 0,
            isDark: isDark,
            theme: theme,
            onTap: onPrevious,
          ),
          _NavArrowButton(
            icon: Icons.chevron_right_rounded,
            visible: currentIndex < total - 1,
            isDark: isDark,
            theme: theme,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _NavArrowButton extends StatefulWidget {
  final IconData icon;
  final bool visible;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _NavArrowButton({
    required this.icon,
    required this.visible,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_NavArrowButton> createState() => _NavArrowButtonState();
}

class _NavArrowButtonState extends State<_NavArrowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.07))
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: _hovered ? 0.16 : 0.08)
                      : Colors.black.withValues(alpha: _hovered ? 0.12 : 0.06),
                  width: 1.5,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: 24,
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentIndex;
  final int total;
  final ThemeData theme;
  final bool isDark;

  const _PageIndicator({
    required this.currentIndex,
    required this.total,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox(height: 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: currentIndex > 0
                ? (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)
                : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(total > 7 ? 7 : total, (i) {
              final int dotIndex;
              if (total <= 7) {
                dotIndex = i;
              } else if (currentIndex < 4) {
                dotIndex = i;
              } else if (currentIndex > total - 4) {
                dotIndex = total - 7 + i;
              } else {
                dotIndex = currentIndex - 3 + i;
              }

              final isActive = dotIndex == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isActive ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.10)),
                  borderRadius: BorderRadius.circular(100),
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: currentIndex < total - 1
                ? (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)
                : Colors.transparent,
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
          size: 48,
          color: AppColors.warning,
        ),
      ),
    );
  }
}
