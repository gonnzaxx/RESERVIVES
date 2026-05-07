import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/favourites_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final espaciosAsync = ref.watch(listaFavoritosEspaciosProvider);
    final serviciosAsync = ref.watch(listaFavoritosServiciosProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 32 : 16, 20, isWeb ? 24 : 12),
                    child: Row(
                      children: [
                        RvGhostIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context
                                    .tr('profile.accountEyebrow')
                                    .toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('favorites.title'),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                  ),


                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _StyledTabBar(
                      isDark: isDark,
                      theme: theme,
                      tabs: [
                        context.tr('favorites.tabs.spaces'),
                        context.tr('favorites.tabs.services'),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms, duration: 300.ms),


                  Expanded(
                    child: TabBarView(
                      children: [
                        _FavoritosList(
                          asyncValue: espaciosAsync,
                          emptyTitle: context.tr('favorites.emptySpaces'),
                          emptyButtonLabel:
                          context.tr('favourites.redirect.text.space'),
                          onRedirect: () => context.goNamed('instalaciones'),
                          onToggle: (id) async {
                            await ref
                                .read(favoritosProvider.notifier)
                                .toggleEspacioFavorito(id);
                            if (!context.mounted) return;
                            RvAlerts.success(
                                context, context.tr('favorites.removed'));
                          },
                          isEspacio: true,
                          isWeb: isWeb,
                        ),
                        _FavoritosList(
                          asyncValue: serviciosAsync,
                          emptyTitle: context.tr('favorites.emptyServices'),
                          emptyButtonLabel:
                          context.tr('favourites.redirect.text.service'),
                          onRedirect: () => context.goNamed('servicios'),
                          onToggle: (id) async {
                            await ref
                                .read(favoritosProvider.notifier)
                                .toggleServicioFavorito(id);
                            if (!context.mounted) return;
                            RvAlerts.success(
                                context, context.tr('favorites.removed'));
                          },
                          isEspacio: false,
                          isWeb: isWeb,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyledTabBar extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final List<String> tabs;

  const _StyledTabBar({
    required this.isDark,
    required this.theme,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicator: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPurple.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

class _FavoritosList extends StatelessWidget {
  final AsyncValue<List<dynamic>> asyncValue;
  final String emptyTitle;
  final String emptyButtonLabel;
  final VoidCallback onRedirect;
  final Future<void> Function(String) onToggle;
  final bool isEspacio;
  final bool isWeb;

  const _FavoritosList({
    required this.asyncValue,
    required this.emptyTitle,
    required this.emptyButtonLabel,
    required this.onRedirect,
    required this.onToggle,
    required this.isEspacio,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: RvEmptyState(
                icon: Icons.favorite_border_rounded,
                title: emptyTitle,
                subtitle: context.tr('favorites.emptySubtitle'),
                buttonLabel: emptyButtonLabel,
                onButtonPressed: onRedirect,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, isWeb ? 12 : 4, 20, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _FavoritoCard(
              item: items[index],
              isEspacio: isEspacio,
              onToggle: () => onToggle(items[index].id),
            )
                .animate()
                .fadeIn(
              delay: Duration(milliseconds: 40 * index),
              duration: 280.ms,
            )
                .slideY(
              begin: 0.05,
              duration: 280.ms,
              curve: Curves.easeOutCubic,
            );
          },
        );
      },
      loading: () => ListView.separated(
        padding: EdgeInsets.fromLTRB(20, isWeb ? 12 : 4, 20, 100),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _FavoritoSkeleton(),
      ),
      error: (_, __) => Center(
        child: RvApiErrorState(onRetry: () {}),
      ),
    );
  }
}

class _FavoritoCard extends ConsumerStatefulWidget {
  final dynamic item;
  final bool isEspacio;
  final VoidCallback onToggle;

  const _FavoritoCard({
    required this.item,
    required this.isEspacio,
    required this.onToggle,
  });

  @override
  ConsumerState<_FavoritoCard> createState() => _FavoritoCardState();
}

class _FavoritoCardState extends ConsumerState<_FavoritoCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _navigate() {
    if (widget.isEspacio) {
      context.push('/booking/${widget.item.id}');
    } else {
      context.pushNamed(
        'reserva_servicio',
        pathParameters: {'servicioId': widget.item.id},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasUrl = widget.item.imagenUrl != null &&
        widget.item.imagenUrl!.toString().isNotEmpty;
    final String fullUrl =
    hasUrl ? AppConstants.resolveApiUrl(widget.item.imagenUrl!) : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _navigate();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.l),
              border: Border.all(
                color: _hovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.28)
                    : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
                width: 1.5,
              ),
              boxShadow: _hovered
                  ? AppShadows.deep(context)
                  : AppShadows.soft(context),
            ),
            child: Row(
              children: [
                _ItemImage(
                  fullUrl: fullUrl,
                  isEspacio: widget.isEspacio,
                  hovered: _hovered,
                  isDark: isDark,
                ),

                const SizedBox(width: 14),


                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.nombre,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _TypeBadge(
                        label: widget.isEspacio
                            ? (widget.item.tipo.value)
                            : (widget.item.horario ??
                            context.tr('favorites.available')),
                        theme: theme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                _RemoveFavButton(onTap: widget.onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  final String fullUrl;
  final bool isEspacio;
  final bool hovered;
  final bool isDark;

  const _ItemImage({
    required this.fullUrl,
    required this.isEspacio,
    required this.hovered,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        boxShadow: hovered
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: fullUrl.startsWith('http')
            ? RvImage(
          imageUrl: fullUrl,
          fit: BoxFit.cover,
          fallbackWidget: _Fallback(isEspacio: isEspacio),
        )
            : _Fallback(isEspacio: isEspacio),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final bool isEspacio;
  const _Fallback({required this.isEspacio});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkHeroGradient
            : AppColors.lightHeroGradient,
      ),
      child: Center(
        child: Icon(
          isEspacio ? Icons.place_rounded : Icons.build_circle_rounded,
          size: 26,
          color: AppColors.accentPurple.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _TypeBadge({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.accentPurple.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.accentPurple,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RemoveFavButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RemoveFavButton({required this.onTap});

  @override
  State<_RemoveFavButton> createState() => _RemoveFavButtonState();
}

class _RemoveFavButtonState extends State<_RemoveFavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.30).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _ctrl.forward().then((_) => _ctrl.reverse());
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.error.withValues(alpha: 0.14)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.error,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}


class _FavoritoSkeleton extends StatelessWidget {
  const _FavoritoSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: Row(
        children: [
          const RvSkeleton(width: 72, height: 72, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                RvSkeleton(width: 160, height: 16, borderRadius: 6),
                SizedBox(height: 8),
                RvSkeleton(width: 80, height: 22, borderRadius: 100),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const RvSkeleton(width: 38, height: 38, borderRadius: 11),
        ],
      ),
    );
  }
}