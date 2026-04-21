import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/l10n/app_localizations.dart';
import 'package:reservives/models/admin_summary.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

final adminSummaryProvider = FutureProvider<AdminSummary>((ref) async {
  ref.watch(adminCountersVersionProvider);
  ref.watch(adminCountersPollTickProvider);
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/admin/summary');
  return AdminSummary.fromJson(response as Map<String, dynamic>);
});

final adminPendingApprovalsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(adminCountersVersionProvider);
  ref.watch(adminCountersPollTickProvider);
  final apiClient = ref.read(apiClientProvider);

  final espacios = await apiClient.get('/reservas-espacios/?estado=PENDIENTE');
  final servicios = await apiClient.get(
    '/servicios/reservas/todas?estado=PENDIENTE',
  );

  return (espacios as List).length + (servicios as List).length;
});

final adminCountersPollTickProvider = StreamProvider<int>((ref) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 30));
    tick++;
    yield tick;
  }
});

class AdminDashboardKpis {
  final AdminSummary summary;
  final int reservationsPendingApproval;

  const AdminDashboardKpis({
    required this.summary,
    required this.reservationsPendingApproval,
  });
}

final adminDashboardKpisProvider = FutureProvider<AdminDashboardKpis>((
    ref,
    ) async {
  ref.watch(adminCountersVersionProvider);

  final summary = await ref.watch(adminSummaryProvider.future);
  final pendingCount = await ref.watch(
    adminPendingApprovalsCountProvider.future,
  );

  return AdminDashboardKpis(
    summary: summary,
    reservationsPendingApproval: pendingCount,
  );
});

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(adminDashboardKpisProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final kpisAsync = ref.watch(adminDashboardKpisProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDashboardKpisProvider),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final crossAxisCount = isWide ? 4 : 2;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.translate('admin.dashboard.backoffice'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      RvBadge(
                        label: loc.translate('admin.dashboard.badge.admin'),
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  RvPageHeader(
                    eyebrow: loc.translate('admin.dashboard.panel.eyebrow'),
                    title: loc.translate('admin.dashboard.panel.title'),
                    subtitle: loc.translate('admin.dashboard.panel.subtitle'),
                  ),
                  const SizedBox(height: 18),

                  kpisAsync.when(
                    data: (kpis) => GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.2 : 0.95,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MetricCard(
                          title: loc.translate(
                            'admin.dashboard.metrics.reservationsPending',
                          ),
                          value: kpis.reservationsPendingApproval.toString(),
                          icon: Icons.event_note_rounded,
                          color: AppColors.warning,
                        ),
                        _MetricCard(
                          title: loc.translate(
                            'admin.dashboard.metrics.spaces',
                          ),
                          value: kpis.summary.espaciosDisponibles.toString(),
                          icon: Icons.grid_view_rounded,
                          color: AppColors.primaryBlue,
                        ),
                        _MetricCard(
                          title: loc.translate('admin.dashboard.metrics.users'),
                          value: kpis.summary.totalUsuarios.toString(),
                          icon: Icons.people_alt_rounded,
                          color: AppColors.accentPurple,
                        ),
                        _MetricCard(
                          title: loc.translate(
                            'admin.dashboard.metrics.announcements',
                          ),
                          value: kpis.summary.anunciosActivos.toString(),
                          icon: Icons.campaign_rounded,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    loading: () => GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.2 : 0.95,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(
                        4,
                            (index) => const RvSkeleton(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 18,
                        ),
                      ),
                    ),
                    error: (error, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: RvApiErrorState(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    loc.translate('admin.dashboard.section.management'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppRadii.m),
                      boxShadow: AppShadows.soft(context),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.m),
                      child: Column(
                        children: [
                          _AdminShortcut(
                            title: loc.translate(
                              'admin.dashboard.shortcut.users.title',
                            ),
                            subtitle: loc.translate(
                              'admin.dashboard.shortcut.users.subtitle',
                            ),
                            icon: Icons.people_alt_rounded,
                            color: AppColors.accentPurple,
                            onTap: () => context.pushNamed('admin_usuarios'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate(
                              'admin.dashboard.shortcut.reservations.title',
                            ),
                            subtitle: loc.translate(
                              'admin.dashboard.shortcut.reservations.subtitle',
                            ),
                            icon: Icons.approval_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.pushNamed('admin_reservas'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate(
                              'admin.dashboard.shortcut.spaces.title',
                            ),
                            subtitle: loc.translate(
                              'admin.dashboard.shortcut.spaces.subtitle',
                            ),
                            icon: Icons.grid_view_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.pushNamed('admin_espacios'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate(
                              'admin.dashboard.shortcut.services.title',
                            ),
                            subtitle: loc.translate(
                              'admin.dashboard.shortcut.services.subtitle',
                            ),
                            icon: Icons.build_circle_rounded,
                            color: AppColors.accentPurple,
                            onTap: () => context.pushNamed('admin_servicios'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate(
                              'admin.dashboard.shortcut.announcements.title',
                            ),
                            subtitle: loc.translate(
                              'admin.dashboard.shortcut.announcements.subtitle',
                            ),
                            icon: Icons.campaign_rounded,
                            color: AppColors.success,
                            onTap: () => context.pushNamed('admin_anuncios'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate('admin.dashboard.shortcut.cafeteria.title'),
                            subtitle: loc.translate('admin.dashboard.shortcut.cafeteria.subtitle'),
                            icon: Icons.local_cafe_rounded,
                            color: AppColors.warning,
                            onTap: () => context.pushNamed('admin_cafeteria'),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 56,
                            color: Theme.of(context).dividerColor,
                          ),
                          _AdminShortcut(
                            title: loc.translate('incidents.admin.title'),
                            subtitle: 'Reportes, averías y problemas técnicos',
                            icon: Icons.report_problem_rounded,
                            color: AppColors.error,
                            onTap: () => context.pushNamed('admin_incidencias'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RvSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(height: 1.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminShortcut extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

