import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/anuncio.dart';
import 'package:reservives/providers/anuncios_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final anunciosAsync = ref.watch(anunciosProvider);
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
                            subtitle: context.tr('home.subtitle'),
                            trailing: !isWeb ? _buildHeaderActions(context, unreadCountAsync, user) : null,
                          ).animate().fadeIn().slideY(begin: 0.1),
                          const SizedBox(height: 14),
                          _HeroSummary(user: user).animate().fadeIn(delay: 80.ms),
                          const SizedBox(height: 18),

                          // Grid de Acciones Rápidas (Adaptable)
                          _QuickActionsGrid(user: user, isWeb: isWeb),

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

class _QuickActionsGrid extends StatelessWidget {
  final dynamic user;
  final bool isWeb;
  const _QuickActionsGrid({required this.user, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [
      _QuickAction(
        title: context.tr('home.quick.reserve.title'),
        subtitle: context.tr('home.quick.reserve.subtitle'),
        icon: Icons.calendar_month_rounded,
        color: AppColors.accentPurple,
        onTap: () => context.goNamed('servicios'),
      ),
      _QuickAction(
        title: context.tr('home.quick.menu.title'),
        subtitle: context.tr('home.quick.menu.subtitle'),
        icon: Icons.local_cafe_rounded,
        color: AppColors.primaryBlue,
        onTap: () => context.goNamed('cafeteria'),
      ),
      if (!user.isAdmin)
        _QuickAction(
          title: context.tr('home.quick.vote.title'),
          subtitle: context.tr('home.quick.vote.subtitle'),
          icon: Icons.how_to_vote_rounded,
          color: Colors.orange.shade600,
          onTap: () => context.pushNamed('votaciones'),
        ),
      if (user.isAdmin)
        _QuickAction(
          title: context.tr('home.quick.backoffice.title'),
          subtitle: context.tr('home.quick.backoffice.subtitle'),
          icon: Icons.admin_panel_settings_rounded,
          color: AppColors.success,
          onTap: () => context.pushNamed('admin'),
        ),
    ];

    if (isWeb) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
        children: actions,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: actions[0]),
            const SizedBox(width: 12),
            Expanded(child: actions[1]),
          ],
        ),
        const SizedBox(height: 12),
        actions[2],
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final dynamic user;
  const _HeroSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      gradient: isDark
          ? AppColors.darkHeroGradient
          : AppColors.lightHeroGradient,
      child: Stack(
        children: [
          // Elemento decorativo sutil
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RvBadge(
                      label: user.isAlumno ? context.tr('home.role.student') : user.rol.value,
                      icon: Icons.verified_rounded,
                      color: AppColors.accentPurple,
                    ),
                    const Spacer(),
                    if (user.isAlumno)
                      Text(
                        '${user.tokens} ${context.tr('home.tokens')}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  user.isAlumno ? context.tr('home.hero.studentTitle') : context.tr('home.hero.staffTitle'),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.isAlumno ? context.tr('home.hero.studentSubtitle') : context.tr('home.hero.staffSubtitle'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    height: 1.5,
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

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: RvSurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
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