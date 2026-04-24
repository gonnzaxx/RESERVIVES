import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/anuncio.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/anuncios_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/encuestas_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:reservives/providers/reservas_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final anunciosAsync = ref.watch(anunciosProvider);
    final reservasAsync = ref.watch(misReservasProvider);
    final encuestasAsync = ref.watch(todasEncuestasProvider);
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    if (user == null) return const Scaffold(body: Center(child: RvLogoLoader()));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000), // Ancho máximo profesional
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(anunciosProvider);
                ref.invalidate(misReservasProvider);
                ref.invalidate(todasEncuestasProvider);
                ref.invalidate(unreadNotificationsCountProvider);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
                      child: Column(
                        children: [
                          RvPageHeader(
                            eyebrow: _greeting(context),
                            title: user.nombre,
                            trailing: !isWeb ? _buildHeaderActions(context, unreadCountAsync, user) : null,
                          ).animate().fadeIn().slideY(begin: 0.1),
                          const SizedBox(height: 16),
                          _WeeklyBookingsSection(reservasAsync: reservasAsync),
                          const SizedBox(height: 12),
                          _ActivePollsSection(encuestasAsync: encuestasAsync),
                          const SizedBox(height: 24),


                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('home.board.title'),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              RvBadge(
                                label: context.tr('home.board.updatedToday'),
                                icon: Icons.bolt_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  anunciosAsync.when(
                    data: (anuncios) {
                      if (anuncios.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: RvEmptyState(
                            icon: Icons.campaign_outlined,
                            title: context.tr('home.board.emptyTitle'),
                            subtitle: context.tr('home.board.emptySubtitle'),
                            buttonLabel: context.tr('common.refresh'),
                            onButtonPressed: () => ref.invalidate(anunciosProvider),
                          ),
                        );
                      }

                      final anunciosLimitados = anuncios.take(20).toList();

                      if (isWeb) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 140,
                            ),
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) => _AnnouncementCard(anuncio: anunciosLimitados[index]),
                              childCount: anunciosLimitados.length,
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(AppRadii.m),
                              boxShadow: AppShadows.soft(context),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.m),
                              child: Column(
                                children: List.generate(anunciosLimitados.length, (index) {
                                  return Column(
                                    children: [
                                      _AnnouncementListItem(anuncio: anunciosLimitados[index]),
                                      if (index < anunciosLimitados.length - 1)
                                        Divider(
                                          height: 0.5,
                                          thickness: 0.5,
                                          indent: 16,
                                          color: Theme.of(context).dividerColor.withOpacity(0.5),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ).animate().fadeIn().slideY(begin: 0.05),
                        ),
                      );
                    },
                    loading: () => _buildAnunciosSkeleton(context, isWeb),
                    error: (error, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: RvApiErrorState(
                        title: context.tr('home.board.errorTitle'),
                        subtitle: context.tr('home.board.errorSubtitle'),
                        onRetry: () => ref.invalidate(anunciosProvider),
                      ),
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

  Widget _buildHeaderActions(BuildContext context, AsyncValue<int> countAsync, dynamic user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => context.pushNamed('notificaciones'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: countAsync.when(
                    data: (count) => count <= 0 ? const SizedBox.shrink() :
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(999)),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.pushNamed('perfil'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: RvAvatar(imageUrl: user.fullAvatarUrl, fallbackText: user.nombre, radius: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildAnunciosSkeleton(BuildContext context, bool isWeb) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, isWeb ? 40 : 120),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadii.m)),
          child: Column(
            children: List.generate(3, (index) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Column(children: [RvSkeleton(width: 80, height: 14), SizedBox(height: 8), RvSkeleton(width: double.infinity, height: 18)])),
                      SizedBox(width: 16),
                      RvSkeleton(width: 80, height: 80, borderRadius: 10),
                    ],
                  ),
                ),
                if (index < 2) const Divider(indent: 16),
              ],
            )),
          ),
        ),
      ),
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 13) return context.tr('home.greeting.morning');
    if (hour < 20) return context.tr('home.greeting.afternoon');
    return context.tr('home.greeting.night');
  }
}

class _WeeklyBookingsSection extends StatelessWidget {
  final AsyncValue<List<Reserva>> reservasAsync;
  const _WeeklyBookingsSection({required this.reservasAsync});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekEnd = DateTime(
      startOfToday.year,
      startOfToday.month,
      startOfToday.day,
      23,
      59,
      59,
    ).add(Duration(days: DateTime.sunday - startOfToday.weekday));

    return RvSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home.weeklyBookings.title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          reservasAsync.when(
            data: (reservas) {
              final visible = reservas
                  .where((reserva) =>
                      !reserva.fechaFin.isBefore(now) && !reserva.fechaInicio.isAfter(weekEnd))
                  .toList()
                ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

              final top = visible.take(4).toList();
              if (top.isEmpty) {
                return Text(
                  context.tr('home.weeklyBookings.empty'),
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }

              final locale = Localizations.localeOf(context).languageCode;
              final dateFormat = DateFormat('EEE d MMM', locale);
              final hourFormat = DateFormat('HH:mm', locale);

              return Column(
                children: List.generate(top.length, (index) {
                  final reserva = top[index];
                  final tramoNombre = reserva.tramo?.nombre;
                  final subtitle = (tramoNombre != null && tramoNombre.isNotEmpty)
                      ? tramoNombre
                      : '${hourFormat.format(reserva.fechaInicio)} - ${hourFormat.format(reserva.fechaFin)}';

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_note_rounded),
                        title: Text(
                          reserva.nombreEspacio ?? context.tr('home.weeklyBookings.defaultReservation'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${dateFormat.format(reserva.fechaInicio)} - $subtitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (index < top.length - 1)
                        Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                    ],
                  );
                }),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: RvSkeleton(width: double.infinity, height: 78, borderRadius: 16),
            ),
            error: (_, __) => Text(
              context.tr('home.weeklyBookings.error'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePollsSection extends StatelessWidget {
  final AsyncValue<List<Encuesta>> encuestasAsync;
  const _ActivePollsSection({required this.encuestasAsync});

  @override
  Widget build(BuildContext context) {
    return encuestasAsync.when(
      data: (encuestas) {
        final now = DateTime.now();
        final activeCount = encuestas.where((e) => e.activa && e.fechaFin.isAfter(now)).length;
        if (activeCount <= 0) return const SizedBox.shrink();

        final counterText = context
            .tr('home.polls.activeCount')
            .replaceAll('{n}', activeCount.toString());

        return RvSurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.how_to_vote_rounded),
            title: Text(
              context.tr('home.quick.vote.title'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(counterText),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed('votaciones'),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Anuncio anuncio;
  const _AnnouncementCard({required this.anuncio});

  @override
  Widget build(BuildContext context) {
    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => context.pushNamed('anuncio_detalle', pathParameters: {'anuncioId': anuncio.id.toString()}),
      child: _AnnouncementListItem(anuncio: anuncio),
    );
  }
}


class _AnnouncementListItem extends StatelessWidget {
  final Anuncio anuncio;
  const _AnnouncementListItem({required this.anuncio});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', Localizations.localeOf(context).languageCode);
    final hasImage = anuncio.imagenUrl != null && anuncio.imagenUrl!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pushNamed('anuncio_detalle', pathParameters: {'anuncioId': anuncio.id.toString()}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (anuncio.destacado) ...[
                          const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.accentPurple),
                          const SizedBox(width: 4),
                        ],
                        Text(dateFormat.format(anuncio.fechaPublicacion).toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(anuncio.titulo,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(anuncio.contenido,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.4)),
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RvImage(imageUrl: anuncio.imagenUrl!, height: 80, width: 80, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

