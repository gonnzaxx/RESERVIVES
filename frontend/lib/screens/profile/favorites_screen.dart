import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/favoritos_provider.dart';
import 'package:reservives/screens/bookings/service_booking_sheet.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('favorites.title'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: isWeb ? 16 : 4,
                          ),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: Colors.white,
                              unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                              overlayColor: WidgetStateProperty.all(Colors.transparent),
                              indicator: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              tabs: [
                                Tab(text: context.tr('favorites.tabs.spaces')),
                                Tab(text: context.tr('favorites.tabs.services')),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _FavoritosList(
                                asyncValue: espaciosAsync,
                                emptyTitle: context.tr('favorites.emptySpaces'),
                                onToggle: (id) async {
                                  await ref.read(favoritosProvider.notifier).toggleEspacioFavorito(id);
                                  if (!context.mounted) return;
                                  RvAlerts.success(context, context.tr('favorites.removed'));
                                },
                                isEspacio: true,
                              ),
                              _FavoritosList(
                                asyncValue: serviciosAsync,
                                emptyTitle: context.tr('favorites.emptyServices'),
                                onToggle: (id) async {
                                  await ref.read(favoritosProvider.notifier).toggleServicioFavorito(id);
                                  if (!context.mounted) return;
                                  RvAlerts.success(context, context.tr('favorites.removed'));
                                },
                                isEspacio: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _FavoritosList extends StatelessWidget {
  final AsyncValue<List<dynamic>> asyncValue;
  final String emptyTitle;
  final Function(String) onToggle;
  final bool isEspacio;

  const _FavoritosList({
    required this.asyncValue,
    required this.emptyTitle,
    required this.onToggle,
    required this.isEspacio,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

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
                buttonLabel: isEspacio ? 'Explorar espacios' : 'Explorar servicios',
                onButtonPressed: () => context.goNamed('servicios'),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 100),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _FavoritoCard(
              item: items[index],
              isEspacio: isEspacio,
              onToggle: () => onToggle(items[index].id),
            );
          },
        );
      },
      loading: () => ListView.separated(
        padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 100),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _FavoritoSkeleton(),
      ),
      error: (error, _) => Center(
        child: RvApiErrorState(onRetry: () {}),
      ),
    );
  }
}

class _FavoritoCard extends ConsumerWidget {
  final dynamic item;
  final bool isEspacio;
  final VoidCallback onToggle;

  const _FavoritoCard({
    required this.item,
    required this.isEspacio,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWeb = MediaQuery.of(context).size.width > 700;
    final hasUrl = item.imagenUrl != null && item.imagenUrl!.toString().isNotEmpty;
    final String fullUrl = hasUrl ? AppConstants.resolveApiUrl(item.imagenUrl!) : '';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft(context),
        border: isWeb ? Border.all(color: theme.dividerColor.withOpacity(0.05)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (isEspacio) {
              context.push('/booking/${item.id}');
            } else {
              showServiceBookingSheet(context, item);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.dividerColor.withOpacity(0.05),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: fullUrl.startsWith('http')
                        ? RvImage(
                      imageUrl: fullUrl,
                      fit: BoxFit.cover,
                      fallbackWidget: _buildFallback(context),
                    )
                        : _buildFallback(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nombre,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEspacio ? (item.tipo.value) : (item.horario ?? context.tr('favorites.available')),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.error.withOpacity(0.08),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Quitar de favoritos',
                    icon: const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
                    onPressed: onToggle,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Center(
      child: Icon(
        isEspacio ? Icons.place_rounded : Icons.build_circle_rounded,
        size: 28,
        color: Theme.of(context).dividerColor.withOpacity(0.5),
      ),
    );
  }
}

class _FavoritoSkeleton extends StatelessWidget {
  const _FavoritoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft(context),
      ),
      child: Row(
        children: [
          const RvSkeleton(width: 70, height: 70, borderRadius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RvSkeleton(width: 150, height: 16),
                const SizedBox(height: 8),
                const RvSkeleton(width: 80, height: 20, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const RvSkeleton(width: 36, height: 36, borderRadius: 18),
        ],
      ),
    );
  }
}