import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

final adminMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/admin/dashboard/');
  return response as Map<String, dynamic>;
});

class AdminMetricsScreen extends ConsumerWidget {
  const AdminMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminMetricsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin.metrics.subtitle').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('admin.metrics.title'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RvGhostIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref.invalidate(adminMetricsProvider),
                  ),
                ],
              ),
            ),

            Expanded(
              child: metricsAsync.when(
                data: (data) {
                  final aulas = data['espacios']['aulas'] as List;
                  final pistas = data['espacios']['pistas'] as List;
                  final servicios = data['servicios'] as List;
                  final anuncios = data['anuncios'] as List;

                  final totalEspacios = [...aulas, ...pistas];
                  final topEspacio = totalEspacios.isNotEmpty
                      ? totalEspacios.reduce((a, b) => (a['valor'] as int) >= (b['valor'] as int) ? a : b)
                      : null;
                  final topServicio = servicios.isNotEmpty
                      ? servicios.reduce((a, b) => (a['valor'] as int) >= (b['valor'] as int) ? a : b)
                      : null;
                  final totalReservas = totalEspacios.fold<int>(0, (sum, e) => sum + (e['valor'] as int));
                  final totalServicios = servicios.fold<int>(0, (sum, e) => sum + (e['valor'] as int));

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, width > 900 ? 40 : 100),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // KPI summary strip
                            _KpiStrip(
                              totalEspacios: totalReservas,
                              totalServicios: totalServicios,
                              totalAnuncios: anuncios.length,
                              isDark: isDark,
                              theme: theme,
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.04, duration: 300.ms, curve: Curves.easeOutCubic),

                            const SizedBox(height: 28),
                            _MetricSection(
                              title: context.tr('admin.metrics.spaces.title'),
                              icon: Icons.meeting_room_rounded,
                              items: totalEspacios,
                              topItem: topEspacio,
                              isDark: isDark,
                              theme: theme,
                            )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 300.ms)
                                .slideY(begin: 0.04, delay: 80.ms, duration: 300.ms, curve: Curves.easeOutCubic),

                            const SizedBox(height: 28),
                            _MetricSection(
                              title: context.tr('admin.metrics.services.title'),
                              icon: Icons.design_services_rounded,
                              items: servicios,
                              topItem: topServicio,
                              isDark: isDark,
                              theme: theme,
                            )
                                .animate()
                                .fadeIn(delay: 160.ms, duration: 300.ms)
                                .slideY(begin: 0.04, delay: 160.ms, duration: 300.ms, curve: Curves.easeOutCubic),

                            const SizedBox(height: 28),
                            _AnnouncementsSection(
                              items: anuncios,
                              isDark: isDark,
                              theme: theme,
                            )
                                .animate()
                                .fadeIn(delay: 240.ms, duration: 300.ms)
                                .slideY(begin: 0.04, delay: 240.ms, duration: 300.ms, curve: Curves.easeOutCubic),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const _AdminMetricsSkeleton(),
                error: (e, _) => Center(
                  child: RvApiErrorState(onRetry: () => ref.invalidate(adminMetricsProvider)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final int totalEspacios;
  final int totalServicios;
  final int totalAnuncios;
  final bool isDark;
  final ThemeData theme;

  const _KpiStrip({
    required this.totalEspacios,
    required this.totalServicios,
    required this.totalAnuncios,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 500;
      final kpis = [
        _KpiData(context.tr('admin.metrics.spaces.title'), '$totalEspacios', Icons.meeting_room_rounded, AppColors.primaryBlue),
        _KpiData(context.tr('admin.metrics.services.title'), '$totalServicios', Icons.design_services_rounded, AppColors.accentPurple),
        _KpiData(context.tr('admin.metrics.announcements.views'), '$totalAnuncios', Icons.campaign_rounded, AppColors.success),
      ];

      if (wide) {
        return Row(
          children: kpis.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: e.key == 0 ? 0 : 12),
                child: _KpiCard(data: e.value, isDark: isDark, theme: theme),
              ),
            );
          }).toList(),
        );
      }
      return Column(
        children: kpis.map((k) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _KpiCard(data: k, isDark: isDark, theme: theme),
        )).toList(),
      );
    });
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final bool isDark;
  final ThemeData theme;

  const _KpiCard({required this.data, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: data.color.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, size: 22, color: data.color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: data.color,
                  letterSpacing: -1,
                ),
              ),
              Text(
                data.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List items;
  final Map<String, dynamic>? topItem;
  final bool isDark;
  final ThemeData theme;

  const _MetricSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.topItem,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: title, icon: icon, theme: theme),
        const SizedBox(height: 14),
        if (items.isEmpty)
          RvSurfaceCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('admin.metrics.noData'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
          )
        else
          _MetricsBarList(items: items, isDark: isDark, theme: theme),
      ],
    );
  }
}

class _MetricsBarList extends StatelessWidget {
  final List items;
  final bool isDark;
  final ThemeData theme;

  const _MetricsBarList({required this.items, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final sorted = List.from(items)..sort((a, b) => (b['valor'] as int).compareTo(a['valor'] as int));
    final maxVal = sorted.isEmpty ? 1 : ((sorted.first['valor'] as int) == 0 ? 1 : sorted.first['valor'] as int);

    return RvSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final name = item['nombre'] as String? ?? '-';
          final count = item['valor'] as int? ?? 0;
          final ratio = count / maxVal;
          final color = AppColors.primaryBlue;

          return Padding(
            padding: EdgeInsets.only(bottom: i < sorted.length - 1 ? 16 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? color.withValues(alpha: 0.12)
                            : theme.dividerColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: i == 0 ? color : theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$count',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: i == 0 ? color : theme.hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      i == 0 ? color : color.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnnouncementsSection extends StatelessWidget {
  final List items;
  final bool isDark;
  final ThemeData theme;

  const _AnnouncementsSection({required this.items, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: context.tr('admin.metrics.announcements.views'),
          icon: Icons.campaign_rounded,
          theme: theme,
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          RvSurfaceCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('admin.metrics.noData'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
          )
        else
          RvSurfaceCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.06)),
              itemBuilder: (context, index) {
                final item = items[index];
                final count = item['valor'] as int? ?? 0;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.remove_red_eye_rounded, size: 18, color: AppColors.accentPurple),
                  ),
                  title: Text(
                    item['nombre'] ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$count ${context.tr('admin.metrics.viewsLabel').toLowerCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentPurple,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final ThemeData theme;

  const _SectionLabel({required this.title, required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _AdminMetricsSkeleton extends StatelessWidget {
  const _AdminMetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: RvSkeleton(width: double.infinity, height: 88, borderRadius: AppRadii.l)),
              const SizedBox(width: 12),
              Expanded(child: RvSkeleton(width: double.infinity, height: 88, borderRadius: AppRadii.l)),
              const SizedBox(width: 12),
              Expanded(child: RvSkeleton(width: double.infinity, height: 88, borderRadius: AppRadii.l)),
            ],
          ),
          const SizedBox(height: 28),
          const RvSkeleton(width: 160, height: 20, borderRadius: 8),
          const SizedBox(height: 14),
          RvSkeleton(width: double.infinity, height: 200, borderRadius: AppRadii.l),
          const SizedBox(height: 28),
          const RvSkeleton(width: 160, height: 20, borderRadius: 8),
          const SizedBox(height: 14),
          RvSkeleton(width: double.infinity, height: 160, borderRadius: AppRadii.l),
        ],
      ),
    );
  }
}
