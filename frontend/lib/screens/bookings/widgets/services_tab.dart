import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/favourites_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/i10n/app_localizations.dart';


class ServiciosTab extends ConsumerStatefulWidget {
  const ServiciosTab({super.key});

  @override
  ConsumerState<ServiciosTab> createState() => _ServiciosTabState();
}

class _ServiciosTabState extends ConsumerState<ServiciosTab> {
  @override
  Widget build(BuildContext context) {
    final serviciosAsync = ref.watch(serviciosFiltradosProvider);
    final query = ref.watch(serviciosSearchQueryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(serviciosInstitutoProvider.future),
      child: CustomScrollView(
        slivers: [
          // Buscador
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: RvDebouncedSearchBar(
                initialValue: query,
                hintText: context.tr('search.placeholder'),
                onDebouncedChanged: (val) =>
                    ref.read(serviciosSearchQueryProvider.notifier).setQuery(val),
              ),
            ),
          ),

          // Contenido
          serviciosAsync.when(
            data: (servicios) {
              if (servicios.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: RvEmptyState(
                      icon: Icons.build_circle_outlined,
                      title: context.tr('services.services.emptyTitle'),
                      subtitle: context.tr('services.services.emptySubtitle'),
                      buttonLabel: context.tr('common.refresh'),
                      onButtonPressed: () => ref
                          .read(serviciosSearchQueryProvider.notifier)
                          .setQuery(''),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ServicioCard(servicio: servicios[index])
                          .animate()
                          .fadeIn(
                        delay: Duration(milliseconds: 40 * index),
                        duration: 300.ms,
                      )
                          .slideY(
                        begin: 0.05,
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    childCount: servicios.length,
                  ),
                ),
              );
            },
            loading: () =>
            const SliverToBoxAdapter(child: LoadingSkeletonList()),
            error: (_, __) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: RvApiErrorState(
                  onRetry: () => ref.invalidate(serviciosInstitutoProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicioCard extends ConsumerStatefulWidget {
  final ServicioInstituto servicio;
  const _ServicioCard({required this.servicio});

  @override
  ConsumerState<_ServicioCard> createState() => _ServicioCardState();
}

class _ServicioCardState extends ConsumerState<_ServicioCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final isGuest = auth.isGuest;
    final user = auth.user;

    final effectiveTokens =
    user?.usesTokens == true ? widget.servicio.precioTokens : 0;
    final rolesPermitidos = widget.servicio.rolesPermitidos;
    final isRoleBlocked = rolesPermitidos.isNotEmpty &&
        (user == null || !rolesPermitidos.contains(user.rol.value));
    final canBook = !isRoleBlocked;

    return MouseRegion(
      cursor: canBook ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: canBook ? (_) => setState(() => _pressed = true) : null,
        onTapUp: canBook
            ? (_) {
          setState(() => _pressed = false);
          if (isGuest) {
            context.goNamed('restricted');
            return;
          }
          context.pushNamed(
            'reserva_servicio',
            pathParameters: {'servicioId': widget.servicio.id},
          );
        }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.l),
              border: Border.all(
                color: _hovered && canBook
                    ? theme.colorScheme.primary.withValues(alpha: 0.30)
                    : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
                width: 1.5,
              ),
              boxShadow:
              _hovered && canBook ? AppShadows.deep(context) : AppShadows.soft(context),
            ),
            child: Opacity(
              opacity: canBook ? 1.0 : 0.50,
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceImage(
                    servicio: widget.servicio,
                    hovered: _hovered && canBook,
                  ),

                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        _BadgeRow(servicio: widget.servicio, canBook: canBook),

                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                widget.servicio.nombre,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            _FavButton(servicioId: widget.servicio.id),
                          ],
                        ),

                        if (widget.servicio.descripcion != null &&
                            widget.servicio.descripcion!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            widget.servicio.descripcion!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 12),

                        _InfoPills(
                          servicio: widget.servicio,
                          user: user,
                          effectiveTokens: effectiveTokens,
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
      ),
    );
  }
}

class _ServiceImage extends StatelessWidget {
  final ServicioInstituto servicio;
  final bool hovered;

  const _ServiceImage({required this.servicio, required this.hovered});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: hovered
            ? [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RvImage(
          imageUrl: servicio.imagenUrl,
          width: 92,
          height: 92,
          fallbackIcon: Icons.build_circle_rounded,
          fallbackIconColor: primaryColor,
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final ServicioInstituto servicio;
  final bool canBook;

  const _BadgeRow({required this.servicio, required this.canBook});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        RvBadge(
          label: canBook
              ? context.tr('spaces.availability')
              : context.tr('spaces.noAvailability'),
          color: canBook ? AppColors.success : AppColors.error,
          icon: canBook ? Icons.check_circle_rounded : Icons.cancel_rounded,
        ),
      ],
    );
  }
}

class _FavButton extends ConsumerStatefulWidget {
  final String servicioId;

  const _FavButton({required this.servicioId});

  @override
  ConsumerState<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends ConsumerState<_FavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final isGuest = ref.read(authProvider).isGuest;
    if (isGuest) {
      RvAlerts.info(context, context.tr('favorites.guest.loginRequired'));
      return;
    }
    _ctrl.forward().then((_) => _ctrl.reverse());
    HapticFeedback.lightImpact();
    final added = await ref
        .read(favoritosProvider.notifier)
        .toggleServicioFavorito(widget.servicioId);
    if (!mounted) return;
    RvAlerts.success(
      context,
      added
          ? context.tr('favorites.added')
          : context.tr('favorites.removed'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritosProvider);
    final isFav = favs.serviciosIds.contains(widget.servicioId);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isFav
                ? AppColors.error.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? AppColors.error : Theme.of(context).dividerColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _InfoPills extends StatelessWidget {
  final ServicioInstituto servicio;
  final dynamic user;
  final int effectiveTokens;

  const _InfoPills({
    required this.servicio,
    required this.user,
    required this.effectiveTokens,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (servicio.ubicacion != null)
          _Pill(
            icon: Icons.location_on_rounded,
            text: servicio.ubicacion!,
            bg: pillBg,
            iconColor: AppColors.accentPurple,
          ),
        _Pill(
          icon: Icons.stars_rounded,
          text: user?.usesTokens == true
              ? '$effectiveTokens tokens'
              : context.tr('services.no.cost'),
          bg: pillBg,
          iconColor: AppColors.warning,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color iconColor;

  const _Pill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      constraints: const BoxConstraints(maxWidth: 200), 
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Flexible( 
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis, 
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}