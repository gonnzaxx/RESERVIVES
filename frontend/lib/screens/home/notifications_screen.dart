import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/datetime_utils.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/notificacion.dart';
import 'package:reservives/providers/navigation_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:reservives/widgets/design_system.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(notificationsInboxProvider.notifier).consumeUnread();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsInboxProvider);
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
                          context.tr('notifications.title'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      RvGhostIconButton(
                        icon: Icons.done_all_rounded,
                        onTap: () => ref.read(notificationsInboxProvider.notifier).consumeUnread(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notificationsAsync.when(
                    skipLoadingOnReload: true,
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return Center(
                          child: RvEmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: context.tr('notifications.emptyTitle'),
                            subtitle: context.tr('notifications.emptySubtitle'),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.read(notificationsInboxProvider.notifier).consumeUnread();
                        },
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 120),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return Dismissible(
                              key: Key(notification.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadii.m),
                                ),
                                child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
                              ),
                              onDismissed: (_) {
                                ref.read(notificationsInboxProvider.notifier).deleteNotification(notification.id);
                              },
                              child: _NotificationCard(item: notification)
                                  .animate()
                                  .fadeIn(duration: 200.ms)
                                  .slideX(begin: 0.05, duration: 200.ms, curve: Curves.easeOutQuad),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 120),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) => const _NotificationSkeleton(),
                    ),
                    error: (error, _) => Center(
                      child: RvApiErrorState(
                        onRetry: () => ref.read(notificationsInboxProvider.notifier).loadUnread(),
                      ),
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

class _NotificationCard extends ConsumerWidget {
  final Notificacion item;

  const _NotificationCard({required this.item});

  Color _colorForTipo(BuildContext context) {
    switch (item.tipo) {
      case TipoNotificacion.reservaAprobada:
        return AppColors.success;
      case TipoNotificacion.reservaRechazada:
      case TipoNotificacion.reservaCancelada:
        return AppColors.error;
      case TipoNotificacion.nuevaReservaPendiente:
      case TipoNotificacion.nuevaIncidencia:
        return AppColors.warning;
      case TipoNotificacion.nuevoEspacio:
      case TipoNotificacion.nuevoServicio:
      case TipoNotificacion.incidenciaResueltas:
        return AppColors.accentPurple;
      case TipoNotificacion.nuevoAnuncio:
      case TipoNotificacion.nuevaEncuesta:
        return AppColors.primaryBlue;
      case TipoNotificacion.recargaTokens:
        return Colors.greenAccent.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _iconForTipo() {
    switch (item.tipo) {
      case TipoNotificacion.reservaAprobada:
        return Icons.check_circle_rounded;
      case TipoNotificacion.reservaRechazada:
        return Icons.cancel_rounded;
      case TipoNotificacion.reservaCancelada:
        return Icons.event_busy_rounded;
      case TipoNotificacion.nuevaReservaPendiente:
        return Icons.pending_actions_rounded;
      case TipoNotificacion.nuevoEspacio:
        return Icons.place_rounded;
      case TipoNotificacion.nuevoServicio:
        return Icons.build_circle_rounded;
      case TipoNotificacion.nuevoAnuncio:
        return Icons.campaign_rounded;
      case TipoNotificacion.nuevaEncuesta:
        return Icons.how_to_vote_rounded;
      case TipoNotificacion.nuevaIncidencia:
        return Icons.report_problem_rounded;
      case TipoNotificacion.incidenciaResueltas:
        return Icons.task_alt_rounded;
      case TipoNotificacion.recargaTokens:
        return Icons.toll_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    switch (item.tipo) {
      case TipoNotificacion.reservaAprobada:
      case TipoNotificacion.reservaRechazada:
      case TipoNotificacion.reservaCancelada:
        ref.read(servicesTabIndexProvider.notifier).setIndex(2);
        context.goNamed('servicios');
        break;

      case TipoNotificacion.nuevaReservaPendiente:
        context.pushNamed('admin_reservas');
        break;

      case TipoNotificacion.nuevoAnuncio:
        if (item.referenciaId != null) {
          context.pushNamed('anuncio_detalle', pathParameters: {
            'anuncioId': item.referenciaId!,
          });
        } else {
          context.goNamed('home');
        }
        break;

      case TipoNotificacion.nuevoEspacio:
        ref.read(servicesTabIndexProvider.notifier).setIndex(0);
        context.goNamed('servicios');
        break;

      case TipoNotificacion.nuevoServicio:
        ref.read(servicesTabIndexProvider.notifier).setIndex(1);
        context.goNamed('servicios');
        break;

      case TipoNotificacion.nuevaEncuesta:
        context.pushNamed('votaciones');
        break;

      case TipoNotificacion.nuevaIncidencia:
      case TipoNotificacion.incidenciaResueltas:
        context.pop();
        context.goNamed('perfil');
        break;

      case TipoNotificacion.recargaTokens:
        context.pop();
        context.goNamed('perfil');
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typeColor = _colorForTipo(context);
    final typeIcon = _iconForTipo();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: item.leida ? theme.cardColor : theme.cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: item.leida ? AppShadows.soft(context) : [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
        border: Border.all(
          color: item.leida ? theme.dividerColor.withValues(alpha: 0.1) : typeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.m),
          onTap: () => _handleTap(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(typeIcon, size: 22, color: typeColor),
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
                                  item.titulo,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: item.leida ? FontWeight.w600 : FontWeight.w800,
                                    color: item.leida ? null : typeColor,
                                  ),
                                ),
                              ),
                              if (!item.leida)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: typeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRelativeDate(item.createdAt, context),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.mensaje,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: item.leida ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8) : null,
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

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: AppShadows.soft(context),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RvSkeleton(width: 38, height: 38, borderRadius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RvSkeleton(width: 150, height: 16, borderRadius: 8),
                    SizedBox(height: 6),
                    RvSkeleton(width: 80, height: 12, borderRadius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          RvSkeleton(width: double.infinity, height: 14, borderRadius: 8),
          SizedBox(height: 8),
          RvSkeleton(width: 200, height: 14, borderRadius: 8),
        ],
      ),
    );
  }
}