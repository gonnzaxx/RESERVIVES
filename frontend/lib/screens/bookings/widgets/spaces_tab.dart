import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/favoritos_provider.dart';
import 'package:reservives/providers/espacios_provider.dart';
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
      onRefresh: () async {
        ref.invalidate(espaciosProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RvDebouncedSearchBar(
                    initialValue: query,
                    hintText: context.tr('search.placeholder'),
                    onDebouncedChanged: (val) =>
                        ref.read(espaciosSearchQueryProvider.notifier).setQuery(val),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(context, ref, null, context.tr('instalaciones.filter.all')),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, TipoEspacio.pista, context.tr('spaces.type.court')),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, TipoEspacio.aula, context.tr('spaces.type.classroom')),
                      ],
                    ),
                  ),
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
                        ref.read(espaciosFilterTipoProvider.notifier).setTipo(null);
                        ref.read(espaciosSearchQueryProvider.notifier).setQuery('');
                      },
                      secondaryButtonLabel: 'Explorar espacios',
                      onSecondaryButtonPressed: () => ref.invalidate(espaciosProvider),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(AppRadii.m),
                            boxShadow: AppShadows.soft(context),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.m),
                            child: _EspacioCard(espacio: espacios[index]),
                          ),
                        ),
                      );
                    },
                    childCount: espacios.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: LoadingSkeletonList()),
            error: (error, _) => SliverFillRemaining(
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

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, TipoEspacio? tipo, String label) {
    final currentFilter = ref.watch(espaciosFilterTipoProvider);
    final isSelected = currentFilter == tipo;
    final theme = Theme.of(context);

    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? theme.colorScheme.primary : theme.cardColor,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      onPressed: () => ref.read(espaciosFilterTipoProvider.notifier).setTipo(tipo),
    );
  }
}

class _EspacioCard extends ConsumerWidget {
  final Espacio espacio;

  const _EspacioCard({required this.espacio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isAulaDisabledForAlumno =
        user?.rol == RolUsuario.alumno && espacio.tipo == TipoEspacio.aula;
    final canBookSpace = espacio.reservable && !isAulaDisabledForAlumno;
    final effectiveTokens = user?.usesTokens == true ? espacio.precioTokens : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canBookSpace
            ? () => context.pushNamed(
          'booking',
          pathParameters: {'espacioId': espacio.id},
        )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: isAulaDisabledForAlumno ? 0.55 : 1,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RvImage(
                imageUrl: espacio.imagenUrl,
                width: 96,
                height: 96,
                borderRadius: BorderRadius.circular(18),
                fallbackIcon: _iconForTipo(espacio.tipo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            RvBadge(
                              label: espacio.tipo == TipoEspacio.pista
                                  ? context.tr('spaces.type.court')
                                  : context.tr('spaces.type.classroom'),
                              color: AppColors.accentPurple,
                            ),
                            RvBadge(
                              label: canBookSpace
                                  ? context.tr('spaces.availability')
                                  : context.tr('spaces.noAvailability'),
                              color: canBookSpace ? AppColors.success : AppColors.error,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            espacio.nombre,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final favs = ref.watch(favoritosProvider);
                            final isFav = favs.espaciosIds.contains(espacio.id);
                            return IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: isAulaDisabledForAlumno ? null : () async {
                                final added = await ref
                                    .read(favoritosProvider.notifier)
                                    .toggleEspacioFavorito(espacio.id);
                                if (!context.mounted) return;
                                RvAlerts.success(
                                  context,
                                  added ? context.tr('favorites.added') : context.tr('favorites.removed'),
                                );
                              },
                              icon: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFav ? AppColors.error : Theme.of(context).dividerColor,
                                size: 22,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (espacio.descripcion != null && espacio.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        espacio.descripcion!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InfoPill(
                          icon: Icons.location_on_rounded,
                          text: espacio.ubicacion ?? context.tr('spaces.no.location'),
                        ),
                        InfoPill(
                          icon: Icons.stars_rounded,
                          text: user?.usesTokens == true
                              ? '$effectiveTokens tokens'
                              : context.tr('spaces.no.cost'),
                          color: AppColors.primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForTipo(TipoEspacio tipo) {
    return tipo == TipoEspacio.pista ? Icons.sports_basketball_rounded : Icons.meeting_room_rounded;
  }
}
