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
            constraints: const BoxConstraints(maxWidth: 1000),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RvPageHeader(
                            eyebrow: _greeting(context),
                            title: user.nombre,
                            trailing: !isWeb ? _buildHeaderActions(context, unreadCountAsync, user) : null,
                          ).animate().fadeIn().slideY(begin: 0.1),
                          const SizedBox(height: 20),

                          _ActivitySection(
                            encuestasAsync: encuestasAsync,
                            reservasAsync: reservasAsync,
                          ),

                          const SizedBox(height: 32),
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

class _ActivitySection extends StatelessWidget {
  final AsyncValue<List<Encuesta>> encuestasAsync;
  final AsyncValue<List<Reserva>> reservasAsync;

  const _ActivitySection({
    required this.encuestasAsync,
    required this.reservasAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        encuestasAsync.when(
          data: (encuestas) {
            final active = encuestas.where((e) => e.activa && e.fechaFin.isAfter(DateTime.now())).toList();
            if (active.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accentPurple, AppColors.accentPurple.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.m),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.pushNamed('votaciones'),
                    borderRadius: BorderRadius.circular(AppRadii.m),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.how_to_vote_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('home.quick.vote.title'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  context.tr('home.polls.activeCount').replaceAll('{n}', active.length.toString()),
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.9)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().shimmer(delay: 2.seconds, duration: 1.5.seconds),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Text(
          context.tr('home.weeklyBookings.title'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.hintColor),
        ),
        const SizedBox(height: 12),
        reservasAsync.when(
          data: (reservas) {
            final now = DateTime.now();
            final weekEnd = DateTime(now.year, now.month, now.day, 23, 59).add(Duration(days: DateTime.sunday - now.weekday));
            final visible = reservas
                .where((r) => r.isActiva && !r.fechaInicio.isBefore(now) && !r.fechaInicio.isAfter(weekEnd))
                .toList()
              ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

            if (visible.isEmpty) {
              return Text(context.tr('home.weeklyBookings.empty'), style: theme.textTheme.bodyMedium);
            }

            final locale = Localizations.localeOf(context).languageCode;
            final dateFormat = DateFormat('EEE d MMM', locale);
            final hourFormat = DateFormat('HH:mm', locale);

            return Column(
              children: visible.take(3).map((reserva) {
                final tramo = reserva.tramo?.nombre;
                final timeInfo = (tramo != null && tramo.isNotEmpty) ? tramo : hourFormat.format(reserva.fechaInicio);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActivityCard(
                    title: reserva.nombreEspacio ?? context.tr('home.weeklyBookings.defaultReservation'),
                    subtitle: '${dateFormat.format(reserva.fechaInicio)} • $timeInfo',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.primaryBlue,
                    onTap: () => context.pushNamed(
                      'reserva_detalle',
                      pathParameters: {'reservaId': reserva.id},
                      queryParameters: {'tipo': (reserva.tipoEspacio ?? '').toUpperCase()},
                      extra: reserva,
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const RvSkeleton(width: double.infinity, height: 60),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.m),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.hintColor, size: 18),
              ],
            ),
          ),
        ),
      ),
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
