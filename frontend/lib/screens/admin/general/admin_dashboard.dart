import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/admin_summary.dart';
import 'package:reservives/providers/admin_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

final adminSummaryProvider = FutureProvider<AdminSummary>((ref) async {
  ref.watch(adminCountersVersionProvider);
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/admin/summary');
  return AdminSummary.fromJson(response as Map<String, dynamic>);
});

final adminPendingApprovalsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(adminCountersVersionProvider);
  final apiClient = ref.read(apiClientProvider);

  final espacios = await apiClient.get('/reservas-espacios/?estado=PENDIENTE');
  final servicios = await apiClient.get(
    '/servicios/reservas/todas?estado=PENDIENTE',
  );
  final recurrentes = await apiClient.get(
    '/reservas-recurrentes/?estado=PENDIENTE_APROBACION',
  );

  return (espacios as List).length +
      (servicios as List).length +
      (recurrentes as List).length;
});

class AdminDashboardKpis {
  final AdminSummary summary;
  final int reservationsPendingApproval;

  const AdminDashboardKpis({
    required this.summary,
    required this.reservationsPendingApproval,
  });
}

final adminDashboardKpisProvider = FutureProvider<AdminDashboardKpis>((ref) async {
  ref.watch(adminCountersVersionProvider);

  final summary = await ref.watch(adminSummaryProvider.future);
  final pendingCount = await ref.watch(adminPendingApprovalsCountProvider.future);

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
  @override
  Widget build(BuildContext context) {
    final kpisAsync = ref.watch(adminDashboardKpisProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDashboardKpisProvider),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  RvPageHeader(
                    eyebrow: context.tr('admin.dashboard.panel.eyebrow'),
                    title: context.tr('admin.dashboard.panel.title'),
                  ).animate().fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  kpisAsync.when(
                    data: (kpis) => _KpiGrid(kpis: kpis, isWide: isWide, isDark: isDark),
                    loading: () => _KpiGridSkeleton(isWide: isWide),
                    error: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: RvApiErrorState(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    context.tr('admin.dashboard.section.management'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  isWide
                      ? _ShortcutsGrid(isDark: isDark)
                      : _ShortcutsList(isDark: isDark),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final AdminDashboardKpis kpis;
  final bool isWide;
  final bool isDark;

  const _KpiGrid({required this.kpis, required this.isWide, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        context.tr('admin.dashboard.metrics.reservationsPending'),
        kpis.reservationsPendingApproval.toString(),
        Icons.pending_actions_rounded,
        AppColors.warning,
      ),
      _KpiData(
        context.tr('admin.dashboard.metrics.spaces'),
        kpis.summary.espaciosDisponibles.toString(),
        Icons.grid_view_rounded,
        AppColors.primaryBlue,
      ),
      _KpiData(
        context.tr('admin.dashboard.metrics.users'),
        kpis.summary.totalUsuarios.toString(),
        Icons.people_alt_rounded,
        AppColors.accentPurple,
      ),
      _KpiData(
        context.tr('admin.dashboard.metrics.announcements'),
        kpis.summary.anunciosActivos.toString(),
        Icons.campaign_rounded,
        AppColors.success,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isWide ? 1.4 : 1.1,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _MetricCard(
          title: card.title,
          value: card.value,
          icon: card.icon,
          color: card.color,
          isDark: isDark,
        ).animate(delay: Duration(milliseconds: 80 * index)).fadeIn().slideY(begin: 0.08);
      },
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  _KpiData(this.title, this.value, this.icon, this.color);
}

class _KpiGridSkeleton extends StatelessWidget {
  final bool isWide;
  const _KpiGridSkeleton({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: isWide ? 1.4 : 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (_) => const RvSkeleton(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 18,
      )),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.3)
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05)),
            width: 1.5,
          ),
          boxShadow: _hovered ? AppShadows.deep(context) : AppShadows.soft(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutsGrid extends StatelessWidget {
  final bool isDark;
  const _ShortcutsGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shortcuts = _getShortcuts(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.2,
      ),
      itemCount: shortcuts.length,
      itemBuilder: (context, index) {
        final s = shortcuts[index];
        return _ShortcutCard(
          title: s.title,
          subtitle: s.subtitle,
          icon: s.icon,
          color: s.color,
          isDark: isDark,
          onTap: () => context.pushNamed(s.route),
        ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn().slideY(begin: 0.04);
      },
    );
  }
}

class _ShortcutsList extends StatelessWidget {
  final bool isDark;
  const _ShortcutsList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shortcuts = _getShortcuts(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.l),
        child: Column(
          children: List.generate(shortcuts.length, (index) {
            final s = shortcuts[index];
            return Column(
              children: [
                _AdminShortcutListItem(
                  title: s.title,
                  subtitle: s.subtitle,
                  icon: s.icon,
                  color: s.color,
                  onTap: () => context.pushNamed(s.route),
                ),
                if (index < shortcuts.length - 1)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 64,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
              ],
            );
          }),
        ),
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.04);
  }
}

class _ShortcutData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  _ShortcutData(this.title, this.subtitle, this.icon, this.color, this.route);
}

List<_ShortcutData> _getShortcuts(BuildContext context) {
  return [
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.users.title'),
      context.tr('admin.dashboard.shortcut.users.subtitle'),
      Icons.people_alt_rounded,
      AppColors.accentPurple,
      'admin_usuarios',
    ),
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.reservations.title'),
      context.tr('admin.dashboard.shortcut.reservations.subtitle'),
      Icons.approval_rounded,
      AppColors.primaryBlue,
      'admin_reservas',
    ),
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.spaces.title'),
      context.tr('admin.dashboard.shortcut.spaces.subtitle'),
      Icons.grid_view_rounded,
      AppColors.primaryBlue,
      'admin_espacios',
    ),
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.services.title'),
      context.tr('admin.dashboard.shortcut.services.subtitle'),
      Icons.build_circle_rounded,
      AppColors.accentPurple,
      'admin_servicios',
    ),
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.announcements.title'),
      context.tr('admin.dashboard.shortcut.announcements.subtitle'),
      Icons.campaign_rounded,
      AppColors.success,
      'admin_anuncios',
    ),
    _ShortcutData(
      context.tr('admin.dashboard.shortcut.cafeteria.title'),
      context.tr('admin.dashboard.shortcut.cafeteria.subtitle'),
      Icons.local_cafe_rounded,
      AppColors.warning,
      'admin_cafeteria',
    ),
    _ShortcutData(
      context.tr('incidents.admin.title'),
      context.tr('admin.dashboard.shortcut.incidents.subtitle'),
      Icons.report_problem_rounded,
      AppColors.error,
      'admin_incidencias',
    ),
  ];
}

class _ShortcutCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
              width: 1.5,
            ),
            boxShadow: _hovered ? AppShadows.deep(context) : AppShadows.soft(context),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: widget.isDark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.4)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminShortcutListItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminShortcutListItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AdminShortcutListItem> createState() => _AdminShortcutListItemState();
}

class _AdminShortcutListItemState extends State<_AdminShortcutListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02))
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
