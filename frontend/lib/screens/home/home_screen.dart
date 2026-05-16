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
import 'package:reservives/providers/announcements_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/polls_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/bookings_live_updates_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/screens/onboarding/app_tutorial_dialog.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/screens/chat/ai_chat_fab.dart';

// Dashboard principal del usuario: muestra reservas recientes, encuestas activas y anuncios.
// En el primer acceso lanza el tutorial de bienvenida.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
      _loadReservations();
    });
  }

  // Recarga las reservas del usuario si no es invitado
  void _loadReservations() {
    if (!mounted) return;
    final isGuest = ref.read(authProvider).isGuest;
    if (isGuest) return;
    ref.invalidate(misReservasProvider);
    ref.invalidate(misReservasServiciosProvider);
  }

  // Comprueba si debe mostrarse el tutorial y lo lanza si es necesario
  Future<void> _checkAndShowTutorial() async {
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    final should = await AppTutorialDialog.shouldShow(user);
    if (!should || !mounted) return;
    await AppTutorialDialog.show(context, user!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isGuest = auth.isGuest;
    final user = auth.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = AppConstants.isWideScreen(context);

    if (!isGuest) ref.watch(bookingsWebSocketProvider).connect();

    final anunciosAsync = ref.watch(anunciosProvider);
    final reservasAsync = isGuest
        ? const AsyncData<List<Reserva>>(<Reserva>[])
        : ref.watch(activityHistoryProvider);
    final encuestasAsync = isGuest
        ? const AsyncData<List<Encuesta>>(<Encuesta>[])
        : ref.watch(todasEncuestasProvider);
    final unreadCountAsync = isGuest
        ? const AsyncData<int>(0)
        : ref.watch(unreadNotificationsCountProvider);

    final displayName = isGuest
        ? context.tr('common.user')
        : (user?.nombre ?? context.tr('common.user'));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: AiChatFab(isGuest: isGuest),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(anunciosProvider);
                ref.invalidate(misReservasProvider);
                ref.invalidate(activityHistoryProvider);
                ref.invalidate(todasEncuestasProvider);
                ref.invalidate(unreadNotificationsCountProvider);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 14, 20, isWeb ? 24 : 8),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: RvPageHeader(
                                  eyebrow: _greeting(context),
                                  title: displayName,
                                ),
                              ),
                              if (!isGuest && user != null && !isWeb)
                                _HeaderActions(
                                  unreadCountAsync:
                                  unreadCountAsync,
                                  user: user,
                                  isDark: isDark,
                                  theme: theme,
                                ),
                            ],
                          ).animate().fadeIn().slideY(begin: 0.08),

                          const SizedBox(height: 24),

                          if (!isGuest)
                            _ActivitySection(
                              encuestasAsync: encuestasAsync,
                              reservasAsync: reservasAsync,
                              isDark: isDark,
                              theme: theme,
                            ),

                          SizedBox(height: isGuest ? 8 : 28),

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('home.board.title'),
                                  style: theme.textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.10),
                                  borderRadius:
                                  BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 13,
                                      color:
                                      theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr(
                                          'home.board.updatedToday'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme
                                            .colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
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
                            title: context
                                .tr('home.board.emptyTitle'),
                            subtitle: context
                                .tr('home.board.emptySubtitle'),
                            buttonLabel:
                            context.tr('common.refresh'),
                            onButtonPressed: () =>
                                ref.invalidate(anunciosProvider),
                          ),
                        );
                      }

                      final limited = anuncios.take(20).toList();

                      if (isWeb) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              20, 16, 20, 40),
                          sliver: SliverGrid(
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 140,
                            ),
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                  _AnnouncementCard(
                                    anuncio: limited[index],
                                    isDark: isDark,
                                    theme: theme,
                                  ),
                              childCount: limited.length,
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            20, 12, 20, 120),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(
                                  AppRadii.l),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white
                                    .withValues(alpha: 0.06)
                                    : Colors.black
                                    .withValues(alpha: 0.05),
                                width: 1.5,
                              ),
                              boxShadow: AppShadows.soft(context),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppRadii.l),
                              child: Column(
                                children: List.generate(
                                  limited.length,
                                      (index) => Column(
                                    children: [
                                      _AnnouncementListItem(
                                        anuncio: limited[index],
                                        isDark: isDark,
                                        theme: theme,
                                      ),
                                      if (index <
                                          limited.length - 1)
                                        Divider(
                                          height: 0.5,
                                          thickness: 0.5,
                                          indent: 16,
                                          color: theme.dividerColor
                                              .withValues(alpha: 0.4),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn()
                              .slideY(begin: 0.04),
                        ),
                      );
                    },
                    loading: () =>
                        _AnunciosSkeleton(isWeb: isWeb, isDark: isDark),
                    error: (_, __) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: RvApiErrorState(
                        title:
                        context.tr('home.board.errorTitle'),
                        subtitle:
                        context.tr('home.board.errorSubtitle'),
                        onRetry: () =>
                            ref.invalidate(anunciosProvider),
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

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 13) return context.tr('home.greeting.morning');
    if (hour < 20) return context.tr('home.greeting.afternoon');
    return context.tr('home.greeting.night');
  }
}

class _HeaderActions extends StatelessWidget {
  final AsyncValue<int> unreadCountAsync;
  final dynamic user;
  final bool isDark;
  final ThemeData theme;

  const _HeaderActions({
    required this.unreadCountAsync,
    required this.user,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NotifBell(
            unreadCountAsync: unreadCountAsync,
            isDark: isDark,
            theme: theme),
        const SizedBox(width: 10),
        _AvatarButton(user: user),
      ],
    );
  }
}

class _NotifBell extends StatefulWidget {
  final AsyncValue<int> unreadCountAsync;
  final bool isDark;
  final ThemeData theme;

  const _NotifBell({
    required this.unreadCountAsync,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.pushNamed('notificaciones'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _hovered
                    ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06))
                    : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                size: 20,
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.80)
                    : Colors.black.withValues(alpha: 0.65),
              ),
            ),
            Positioned(
              top: -3,
              right: -3,
              child: widget.unreadCountAsync.when(
                data: (count) => count <= 0
                    ? const SizedBox.shrink()
                    : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius:
                    BorderRadius.circular(100),
                    border: Border.all(
                      color: widget.isDark
                          ? AppColors.darkSurface
                          : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final dynamic user;
  const _AvatarButton({required this.user});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.pushNamed('perfil'),
        child: RvAvatar(
          imageUrl: user.fullAvatarUrl,
          fallbackText: user.nombre,
          radius: 21,
        ),
      ),
    );
  }
}

/// Sección que agrupa la "actividad" del usuario.
///
/// Dependiendo de los datos que recibe, muestra un banner
/// si hay votaciones pendientes, y la lista de sus reservas más próximas (hasta 5).
class _ActivitySection extends StatelessWidget {
  final AsyncValue<List<Encuesta>> encuestasAsync;
  final AsyncValue<List<Reserva>> reservasAsync;
  final bool isDark;
  final ThemeData theme;

  const _ActivitySection({
    required this.encuestasAsync,
    required this.reservasAsync,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        encuestasAsync.when(
          data: (encuestas) {
            final active = encuestas
                .where((e) =>
            e.activa && e.fechaFin.isAfter(DateTime.now()))
                .toList();
            if (active.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _PollsBanner(
                  count: active.length, theme: theme),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        Text(
          context.tr('home.weeklyBookings.title'),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 10),

        reservasAsync.when(
          data: (reservas) {
            final activas = reservas
                .where((r) => r.isActiva)
                .toList()
              ..sort((a, b) =>
                  a.fechaInicio.compareTo(b.fechaInicio));

            final visible = activas.take(5).toList();
            final hayMas = activas.length > 5;

            if (visible.isEmpty) {
              return _EmptyBookings(isDark: isDark, theme: theme);
            }

            final locale =
                Localizations.localeOf(context).languageCode;
            final dayFmt = DateFormat('EEE', locale);
            final dayNumFmt = DateFormat('d', locale);
            final monthFmt = DateFormat('MMM', locale);
            final hourFmt = DateFormat('HH:mm', locale);

            return Column(
              children: [
                ...visible.map((reserva) => _ActivityCard(
                  title: reserva.nombreEspacio ??
                      context.tr(
                          'home.weeklyBookings.defaultReservation'),
                  time:
                  '${hourFmt.format(reserva.fechaInicio)} - ${hourFmt.format(reserva.fechaFin)}',
                  dayName: dayFmt
                      .format(reserva.fechaInicio)
                      .toUpperCase(),
                  dayNum: dayNumFmt
                      .format(reserva.fechaInicio),
                  month: monthFmt
                      .format(reserva.fechaInicio)
                      .toUpperCase(),
                  color: _statusColor(reserva.estado),
                  isDark: isDark,
                  theme: theme,
                  onTap: () => context.pushNamed(
                    'reserva_detalle',
                    pathParameters: {
                      'reservaId': reserva.id
                    },
                    queryParameters: {
                      'tipo': (reserva.tipoEspacio ?? '')
                          .toUpperCase()
                    },
                    extra: reserva,
                  ),
                ).animate().fadeIn(delay: 60.ms).slideX(begin: 0.04)),
                if (hayMas)
                  _SeeAllButton(
                      count: activas.length, theme: theme),
              ],
            );
          },
          loading: () => const RvSkeleton(
              width: double.infinity,
              height: 80,
              borderRadius: 14),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Color _statusColor(EstadoReserva estado) {
    switch (estado) {
      case EstadoReserva.pendiente:
        return AppColors.warning;
      case EstadoReserva.cancelada:
      case EstadoReserva.rechazada:
        return AppColors.error;
      case EstadoReserva.aprobada:
        return AppColors.success;
    }
  }
}

class _PollsBanner extends StatefulWidget {
  final int count;
  final ThemeData theme;

  const _PollsBanner({required this.count, required this.theme});

  @override
  State<_PollsBanner> createState() => _PollsBannerState();
}

class _PollsBannerState extends State<_PollsBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.pushNamed('votaciones'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.theme.colorScheme.primary,
                widget.theme.colorScheme.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.l),
            boxShadow: [
              BoxShadow(
                color: widget.theme.colorScheme.primary
                    .withValues(alpha: _hovered ? 0.35 : 0.20),
                blurRadius: _hovered ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home.quick.vote.title'),
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context
                          .tr('home.polls.activeCount')
                          .replaceAll(
                          '{n}', widget.count.toString()),
                      style: widget.theme.textTheme.bodySmall
                          ?.copyWith(
                        color: Colors.white
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ],
          ),
        ),
      ),
    ).animate().shimmer(delay: 2.seconds, duration: 1.5.seconds);
  }
}

class _EmptyBookings extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _EmptyBookings({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 28, horizontal: 20),
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
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 40,
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('home.weeklyBookings.empty'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          _GoBookButton(theme: theme),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06, curve: Curves.easeOutBack);
  }
}

class _GoBookButton extends StatefulWidget {
  final ThemeData theme;
  const _GoBookButton({required this.theme});

  @override
  State<_GoBookButton> createState() => _GoBookButtonState();
}

class _GoBookButtonState extends State<_GoBookButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.pushNamed('espacios');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                context.tr('home.weeklyBookings.goToBookings'),
                style: widget.theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final int count;
  final ThemeData theme;

  const _SeeAllButton({required this.count, required this.theme});

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => context.pushNamed('actividad'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ver todas las reservas ($count)',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded,
                size: 16, color: primary),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta visual que representa un evento o reserva individual.
///
/// El color del borde izquierdo indica el estado.
class _ActivityCard extends StatefulWidget {
  final String title;
  final String time;
  final String dayName;
  final String dayNum;
  final String month;
  final Color color;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.time,
    required this.dayName,
    required this.dayNum,
    required this.month,
    required this.color,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkCard
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.m),
              border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.35)
                    : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
                width: 1.5,
              ),
              boxShadow: _hovered
                  ? AppShadows.deep(context)
                  : AppShadows.soft(context),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadii.m),
                        bottomLeft:
                        Radius.circular(AppRadii.m),
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.dayName,
                          style: widget.theme.textTheme
                              .labelSmall
                              ?.copyWith(
                            color: widget.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.dayNum,
                          style: widget.theme.textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          widget.month,
                          style: widget.theme.textTheme
                              .labelSmall
                              ?.copyWith(
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: widget.theme.dividerColor
                        .withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: widget.theme.textTheme
                                .titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: widget.isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.time,
                                style: widget.theme.textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: widget.isDark
                                      ? AppColors
                                      .darkTextSecondary
                                      : AppColors
                                      .lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: widget.isDark
                        ? AppColors.darkTextSecondary
                        .withValues(alpha: 0.5)
                        : AppColors.lightTextSecondary
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// Tarjeta contenedora para la vista de cuadrícula (modo Web/Desktop) de un anuncio.
class _AnnouncementCard extends StatefulWidget {
  final Anuncio anuncio;
  final bool isDark;
  final ThemeData theme;

  const _AnnouncementCard({
    required this.anuncio,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.pushNamed(
          'anuncio_detalle',
          pathParameters: {
            'anuncioId': widget.anuncio.id.toString()
          },
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.l),
            border: Border.all(
              color: _hovered
                  ? primary.withValues(alpha: 0.28)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? AppShadows.deep(context)
                : AppShadows.soft(context),
          ),
          child: _AnnouncementListItem(
            anuncio: widget.anuncio,
            isDark: widget.isDark,
            theme: widget.theme,
          ),
        ),
      ),
    );
  }
}

/// Elemento individual del tablón de anuncios.
///
/// Muestra título, contenido, fecha de publicación y, si está
/// marcado como destacado, un icono de chincheta. Si tiene imagen, la carga
/// asíncronamente con [RvImage].
class _AnnouncementListItem extends StatefulWidget {
  final Anuncio anuncio;
  final bool isDark;
  final ThemeData theme;

  const _AnnouncementListItem({
    required this.anuncio,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_AnnouncementListItem> createState() =>
      _AnnouncementListItemState();
}

class _AnnouncementListItemState
    extends State<_AnnouncementListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat(
      'd MMM',
      Localizations.localeOf(context).languageCode,
    );
    final hasImage = widget.anuncio.imagenUrl != null &&
        widget.anuncio.imagenUrl!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.pushNamed(
          'anuncio_detalle',
          pathParameters: {
            'anuncioId': widget.anuncio.id.toString()
          },
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
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
                        if (widget.anuncio.destacado) ...[
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: AppColors.accentPurple,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          dateFormat
                              .format(widget.anuncio
                              .fechaPublicacion)
                              .toUpperCase(),
                          style: widget.theme.textTheme
                              .labelSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.anuncio.titulo,
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.anuncio.contenido,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.bodySmall
                          ?.copyWith(
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RvImage(
                    imageUrl: widget.anuncio.imagenUrl!,
                    height: 76,
                    width: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnunciosSkeleton extends StatelessWidget {
  final bool isWeb;
  final bool isDark;

  const _AnunciosSkeleton(
      {required this.isWeb, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, isWeb ? 40 : 120),
      sliver: SliverToBoxAdapter(
        child: Container(
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
          child: Column(
            children: List.generate(3, (index) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: const [
                              RvSkeleton(
                                  width: 70,
                                  height: 12,
                                  borderRadius: 4),
                              SizedBox(height: 8),
                              RvSkeleton(
                                  width: double.infinity,
                                  height: 16,
                                  borderRadius: 5),
                              SizedBox(height: 6),
                              RvSkeleton(
                                  width: double.infinity,
                                  height: 12,
                                  borderRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        const RvSkeleton(
                            width: 76,
                            height: 76,
                            borderRadius: 12),
                      ],
                    ),
                  ),
                  if (index < 2)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 16,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.4),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

