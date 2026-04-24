import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/favoritos_provider.dart';
import 'package:reservives/providers/servicio_provider.dart';
import 'package:reservives/screens/bookings/service_booking_sheet.dart';
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
    final user = ref.watch(authProvider).user;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(serviciosInstitutoProvider.future),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: RvDebouncedSearchBar(
              initialValue: query,
              hintText: context.tr('search.placeholder'),
              onDebouncedChanged: (val) =>
                  ref.read(serviciosSearchQueryProvider.notifier).setQuery(val),
            ),
          ),
          Expanded(
            child: serviciosAsync.when(
              data: (servicios) {
                if (servicios.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 100),
                      RvEmptyState(
                        icon: Icons.build_circle_outlined,
                        title: context.tr('services.services.emptyTitle'),
                        subtitle: context.tr('services.services.emptySubtitle'),
                        buttonLabel: context.tr('common.refresh'),
                        onButtonPressed: () => ref
                            .read(serviciosSearchQueryProvider.notifier)
                            .setQuery(''),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  itemCount: servicios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final servicio = servicios[index];
                    final tokenText = user?.usesTokens == true
                        ? '${servicio.precioTokens} tokens'
                        : context.tr('services.no.cost');

                    return _ServicioCard(servicio: servicio, tokenText: tokenText);
                  },
                );
              },
              loading: () => const LoadingSkeletonList(),
              error: (error, _) => Center(
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

class _ServicioCard extends ConsumerWidget {
  final ServicioInstituto servicio;
  final String tokenText;

  const _ServicioCard({required this.servicio, required this.tokenText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.m),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showServiceBookingSheet(context, servicio),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RvImage(
                    imageUrl: servicio.imagenUrl,
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(18),
                    fallbackIcon: Icons.build_circle_rounded,
                    fallbackIconColor: AppColors.accentPurple,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                servicio.nombre,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                final favs = ref.watch(favoritosProvider);
                                final isFav = favs.serviciosIds.contains(servicio.id);
                                return IconButton(
                                  onPressed: () async {
                                    final added = await ref
                                        .read(favoritosProvider.notifier)
                                        .toggleServicioFavorito(servicio.id);
                                    if (!context.mounted) return;
                                    RvAlerts.success(
                                      context,
                                      added
                                          ? context.tr('favorites.added')
                                          : context.tr('favorites.removed'),
                                    );
                                  },
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav
                                        ? AppColors.error
                                        : Theme.of(context).dividerColor,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (servicio.descripcion != null)
                          Text(
                            servicio.descripcion!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (servicio.ubicacion != null)
                              InfoPill(
                                icon: Icons.location_on_rounded,
                                text: servicio.ubicacion!,
                              ),
                            InfoPill(
                              icon: Icons.stars_rounded,
                              text: tokenText,
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
      ),
    );
  }
}
