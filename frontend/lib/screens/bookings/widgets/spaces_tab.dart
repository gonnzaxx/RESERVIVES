import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/favourites_provider.dart';
import 'package:reservives/providers/spaces_provider.dart';
import 'package:reservives/screens/bookings/widgets/shared.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/i10n/app_localizations.dart';

class InstalacionesTab extends ConsumerStatefulWidget {
  const InstalacionesTab({super.key});

  @override
  ConsumerState<InstalacionesTab> createState() => _InstalacionesTabState();
}

class _InstalacionesTabState extends ConsumerState<InstalacionesTab> {
  @override
  Widget build(BuildContext context) {
    final espaciosAsync = ref.watch(espaciosProvider);
    final query = ref.watch(espaciosSearchQueryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(espaciosProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RvDebouncedSearchBar(
                    initialValue: query,
                    hintText: context.tr('search.placeholder'),
                    onDebouncedChanged: (val) => ref
                        .read(espaciosSearchQueryProvider.notifier)
                        .setQuery(val),
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(),
                ],
              ),
            ),
          ),

          espaciosAsync.when(
            data: (espacios) {
              if (espacios.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: RvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('search.notFoundTitle'),
                      subtitle: context.tr('search.notFoundSubtitle'),
                      buttonLabel: context.tr('common.refresh'),
                      onButtonPressed: () {
                        ref
                            .read(espaciosFilterTipoProvider.notifier)
                            .setTipo(null);
                        ref
                            .read(espaciosSearchQueryProvider.notifier)
                            .setQuery('');
                      },
                      secondaryButtonLabel: 'Explorar espacios',
                      onSecondaryButtonPressed: () =>
                          ref.invalidate(espaciosProvider),
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
                      child: _EspacioCard(espacio: espacios[index])
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
                    childCount: espacios.length,
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
                  onRetry: () => ref.invalidate(espaciosProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(espaciosFilterTipoProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filters = [
      (tipo: null, label: context.tr('instalaciones.filter.all')),
      (tipo: TipoEspacio.pista, label: context.tr('spaces.type.court')),
      (tipo: TipoEspacio.aula, label: context.tr('spaces.type.classroom')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters
            .map((f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _FilterChip(
            label: f.label,
            isSelected: current == f.tipo,
            isDark: isDark,
            theme: theme,
            onTap: () => ref
                .read(espaciosFilterTipoProvider.notifier)
                .setTipo(f.tipo),
          ),
        ))
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.theme.colorScheme.primary
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
            boxShadow: widget.isSelected
                ? [
              BoxShadow(
                color: widget.theme.colorScheme.primary
                    .withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Text(
            widget.label,
            style: widget.theme.textTheme.labelMedium?.copyWith(
              color: widget.isSelected
                  ? Colors.white
                  : (widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
              fontWeight:
              widget.isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EspacioCard extends ConsumerStatefulWidget {
  final Espacio espacio;
  const _EspacioCard({required this.espacio});

  @override
  ConsumerState<_EspacioCard> createState() => _EspacioCardState();
}

class _EspacioCardState extends ConsumerState<_EspacioCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;

    final rolesPermitidos = widget.espacio.rolesPermitidos;
    final isRoleBlocked = rolesPermitidos.isNotEmpty &&
        (user == null || !rolesPermitidos.contains(user.rol.value));
    final canBook = widget.espacio.reservable && !isRoleBlocked;
    final effectiveTokens =
    user?.usesTokens == true ? widget.espacio.precioTokens : 0;

    return MouseRegion(
      cursor: canBook ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: canBook ? (_) => setState(() => _pressed = true) : null,
        onTapUp: canBook
            ? (_) {
          setState(() => _pressed = false);
          context.pushNamed(
            'booking',
            pathParameters: {'espacioId': widget.espacio.id},
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
              boxShadow: _hovered && canBook
                  ? AppShadows.deep(context)
                  : AppShadows.soft(context),
            ),
            child: Opacity(
              opacity: canBook ? 1.0 : 0.50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _SpaceImage(
                      espacio: widget.espacio,
                      hovered: _hovered && canBook,
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BadgeRow(
                            espacio: widget.espacio,
                            canBook: canBook,
                          ),

                          const SizedBox(height: 8),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.espacio.nombre,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              _FavButton(
                                espacioId: widget.espacio.id,
                                disabled: false,
                              ),
                            ],
                          ),

                          // Descripción
                          if (widget.espacio.descripcion != null &&
                              widget.espacio.descripcion!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              widget.espacio.descripcion!,
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

                          // Pills de info
                          _InfoPills(
                            espacio: widget.espacio,
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

class _SpaceImage extends StatelessWidget {
  final Espacio espacio;
  final bool hovered;

  const _SpaceImage({required this.espacio, required this.hovered});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: hovered
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RvImage(
          imageUrl: espacio.imagenUrl,
          width: 92,
          height: 92,
          fallbackIcon: espacio.tipo == TipoEspacio.pista
              ? Icons.sports_basketball_rounded
              : Icons.meeting_room_rounded,
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final Espacio espacio;
  final bool canBook;

  const _BadgeRow({required this.espacio, required this.canBook});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        RvBadge(
          label: espacio.tipo == TipoEspacio.pista
              ? context.tr('spaces.type.court')
              : context.tr('spaces.type.classroom'),
          color: AppColors.accentPurple,
          icon: espacio.tipo == TipoEspacio.pista
              ? Icons.sports_basketball_rounded
              : Icons.meeting_room_rounded,
        ),
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
  final String espacioId;
  final bool disabled;

  const _FavButton({required this.espacioId, required this.disabled});

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
    if (widget.disabled) return;
    final isGuest = ref.read(authProvider).isGuest;
    if (isGuest) {
      RvAlerts.info(context, context.tr('favorites.guest.loginRequired'));
      return;
    }
    _ctrl.forward().then((_) => _ctrl.reverse());
    HapticFeedback.lightImpact();
    final added = await ref
        .read(favoritosProvider.notifier)
        .toggleEspacioFavorito(widget.espacioId);
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
    final isFav = favs.espaciosIds.contains(widget.espacioId);

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
            color: isFav
                ? AppColors.error
                : Theme.of(context).dividerColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}


class _InfoPills extends StatelessWidget {
  final Espacio espacio;
  final dynamic user;
  final int effectiveTokens;

  const _InfoPills({
    required this.espacio,
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
        _Pill(
          icon: Icons.location_on_rounded,
          text: espacio.ubicacion ?? context.tr('spaces.no.location'),
          bg: pillBg,
          iconColor: AppColors.accentPurple,
        ),
        _Pill(
          icon: Icons.stars_rounded,
          text: user?.usesTokens == true
              ? '$effectiveTokens tokens'
              : context.tr('spaces.no.cost'),
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
      constraints: const BoxConstraints(maxWidth: 180),
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