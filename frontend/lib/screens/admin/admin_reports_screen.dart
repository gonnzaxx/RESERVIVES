import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/incidencia.dart';
import 'package:reservives/providers/reports_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:intl/intl.dart';

class AdminIncidentsScreen extends ConsumerStatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  ConsumerState<AdminIncidentsScreen> createState() => _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends ConsumerState<AdminIncidentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidenciasAsync = ref.watch(todasIncidenciasProvider);
    final theme = Theme.of(context);

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
                      title: context.tr('incidents.admin.title'),
                      eyebrow: 'Reportes',
                    ),
                  ),
                  RvGhostIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref.invalidate(todasIncidenciasProvider),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.hintColor,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  tabs: [
                    Tab(text: context.tr('incidents.admin.pending')),
                    Tab(text: context.tr('incidents.admin.resolved')),
                  ],
                ),
              ),
            ),

            Expanded(
              child: incidenciasAsync.when(
                data: (incidencias) {
                  final pendientes = incidencias.where((i) => i.estado == EstadoIncidencia.pendiente).toList();
                  final resueltas = incidencias.where((i) => i.estado == EstadoIncidencia.resuelta).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _IncidentsGrid(incidencias: pendientes),
                      _IncidentsGrid(incidencias: resueltas),
                    ],
                  );
                },
                loading: () => const _AdminIncidentsSkeleton(),
                error: (e, _) => Center(
                  child: RvApiErrorState(onRetry: () => ref.invalidate(todasIncidenciasProvider)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentsGrid extends StatelessWidget {
  final List<Incidencia> incidencias;

  const _IncidentsGrid({required this.incidencias});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    double spacing = 16;
    double extent = 180;

    if (width > 1200) {
      crossAxisCount = 3;
    } else if (width > 800) {
      crossAxisCount = 2;
    }

    if (incidencias.isEmpty) {
      return RvEmptyState(
        icon: Icons.assignment_turned_in_rounded,
        title: context.tr('incidents.admin.empty'),
        subtitle: context.tr('common.emptySubtitle'),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 12, 20, width > 700 ? 40 : 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: extent,
      ),
      itemCount: incidencias.length,
      itemBuilder: (context, index) {
        return _IncidentCard(incidencia: incidencias[index]);
      },
    );
  }
}

class _IncidentCard extends ConsumerWidget {
  final Incidencia incidencia;
  const _IncidentCard({required this.incidencia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RvSurfaceCard(
      onTap: () => _showDetail(context, ref, incidencia),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RvBadge(
                label: incidencia.estado.name.toUpperCase(),
                color: incidencia.estado == EstadoIncidencia.pendiente ? Colors.orange : AppColors.success,
              ),
              Text(
                DateFormat('dd/MM HH:mm').format(incidencia.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(
              incidencia.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.3),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  (incidencia.nombreUsuario ?? 'U')[0].toUpperCase(),
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  incidencia.nombreUsuario ?? context.tr('admin.bookings.unknown'),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (incidencia.imagenUrl != null)
                Icon(Icons.image_rounded, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, Incidencia inc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IncidentDetail(incidencia: inc),
    );
  }
}

class _IncidentDetail extends ConsumerStatefulWidget {
  final Incidencia incidencia;
  const _IncidentDetail({required this.incidencia});

  @override
  ConsumerState<_IncidentDetail> createState() => _IncidentDetailState();
}

class _IncidentDetailState extends ConsumerState<_IncidentDetail> {
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inc = widget.incidencia;
    final width = MediaQuery.of(context).size.width;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('incidents.admin.detail'),
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMMM, yyyy • HH:mm').format(inc.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                RvBadge(
                  label: inc.estado.name.toUpperCase(),
                  color: inc.estado == EstadoIncidencia.pendiente ? Colors.orange : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    inc.nombreUsuario ?? context.tr('admin.bookings.unknown'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              inc.descripcion,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            if (inc.imagenUrl != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: RvImage(
                  imageUrl: AppConstants.resolveApiUrl(inc.imagenUrl),
                  height: width > 600 ? 400 : 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.broken_image_outlined,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (inc.estado == EstadoIncidencia.pendiente) ...[
              const Divider(),
              const SizedBox(height: 24),
              Text(
                context.tr('incidents.admin.commentLabel'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr('incidents.admin.commentHint'),
                  filled: true,
                  fillColor: theme.dividerColor.withValues(alpha: 0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              RvPrimaryButton(
                onTap: () async {
                  setState(() => _isSaving = true);
                  final success = await ref.read(todasIncidenciasProvider.notifier).resolver(
                    inc.id,
                    _commentController.text.trim(),
                  );
                  if (mounted) {
                    setState(() => _isSaving = false);
                    if (success) {
                      Navigator.pop(context);
                      RvAlerts.success(context, context.tr('incidents.admin.resolvedSuccess'));
                    }
                  }
                },
                label: context.tr('incidents.admin.markResolved'),
                isLoading: _isSaving,
                icon: Icons.check_circle_rounded,
              ),
            ] else if (inc.comentarioAdmin != null) ...[
              const Divider(),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('incidents.admin.resolution'),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(inc.comentarioAdmin!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminIncidentsSkeleton extends StatelessWidget {
  const _AdminIncidentsSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 3 : (width > 800 ? 2 : 1);

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 180,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const RvSkeleton(
        width: double.infinity,
        height: 180,
        borderRadius: 28,
      ),
    );
  }
}