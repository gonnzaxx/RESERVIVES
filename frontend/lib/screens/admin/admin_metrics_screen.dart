import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/widgets/design_system.dart';

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
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 900;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: RvPageHeader(
                      title: context.tr('admin.metrics.title'),
                      eyebrow: 'Analítica',
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

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, 10, 24, isWeb ? 40 : 100
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              title: context.tr('admin.metrics.spaces.title'),
                              icon: Icons.meeting_room_rounded,
                            ),
                            const SizedBox(height: 16),
                            _MetricsGrid(items: [...aulas, ...pistas]),

                            const SizedBox(height: 40),
                            _SectionTitle(
                              title: context.tr('admin.metrics.services.title'),
                              icon: Icons.design_services_rounded,
                            ),
                            const SizedBox(height: 16),
                            _MetricsGrid(items: servicios),

                            const SizedBox(height: 40),
                            _SectionTitle(
                              title: context.tr('admin.metrics.announcements.views'),
                              icon: Icons.campaign_rounded,
                            ),
                            const SizedBox(height: 16),
                            _AnnouncementsList(items: anuncios),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const _AdminMetricsSkeleton(),
                error: (e, _) => Center(
                    child: RvApiErrorState(
                        onRetry: () => ref.invalidate(adminMetricsProvider)
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List items;
  const _MetricsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const RvSurfaceCard(child: Center(child: Text("No hay datos suficientes")));

    final sorted = List.from(items)..sort((a, b) => (b['valor'] as int).compareTo(a['valor'] as int));
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 4 : (width > 800 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 130,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final name = item['nombre'] ?? "Item";
        final count = item['valor'] ?? 0;

        return RvSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -8,
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name.toString().toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).hintColor,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RvBadge(
                    label: context.tr('admin.metrics.bookingsLabel'),
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementsList extends StatelessWidget {
  final List items;
  const _AnnouncementsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const RvSurfaceCard(child: Center(child: Text("Sin visualizaciones")));

    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05)
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.accentPurple.withValues(alpha: 0.1),
              child: const Icon(Icons.remove_red_eye_rounded, size: 18, color: AppColors.accentPurple),
            ),
            title: Text(
              item['nombre'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item['valor']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  context.tr('admin.metrics.viewsLabel').toLowerCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminMetricsSkeleton extends StatelessWidget {
  const _AdminMetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RvSkeleton(width: 200, height: 32, borderRadius: 12),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 130,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const RvSkeleton(width: double.infinity, height: 130, borderRadius: 28),
          ),
        ],
      ),
    );
  }
}