import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/providers/admin_websocket_provider.dart';
import 'package:reservives/providers/auth_provider.dart';

class AdminShellScreen extends ConsumerWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminWebSocketProvider).connect();
    final user = ref.watch(authProvider).user;

    final location = GoRouterState.of(context).uri.path;
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1100;

    final allItems = [
      (BackofficeSection.summary, '/admin', context.tr('admin.shell.summary'), Icons.dashboard_rounded),
      (BackofficeSection.users, '/admin/usuarios', context.tr('admin.shell.users'), Icons.people_alt_rounded),
      (BackofficeSection.bookings, '/admin/reservas', context.tr('admin.shell.bookings'), Icons.approval_rounded),
      (BackofficeSection.polls, '/admin/encuestas', context.tr('admin.shell.polls'), Icons.how_to_vote_rounded),
      (BackofficeSection.incidents, '/admin/incidencias', context.tr('admin.shell.incidents'), Icons.report_problem_rounded),
      (BackofficeSection.metrics, '/admin/metricas', context.tr('admin.shell.metrics'), Icons.bar_chart_rounded),
      (BackofficeSection.spaces, '/admin/espacios', context.tr('admin.shell.spaces'), Icons.grid_view_rounded),
      (BackofficeSection.services, '/admin/servicios', context.tr('admin.shell.services'), Icons.build_circle_rounded),
      (BackofficeSection.announcements, '/admin/anuncios', context.tr('admin.shell.announcements'), Icons.campaign_rounded),
      (BackofficeSection.cafeteria, '/admin/cafeteria', context.tr('admin.shell.cafeteria'), Icons.local_cafe_rounded),
      (BackofficeSection.configuration, '/admin/configuracion', context.tr('admin.shell.configuration'), Icons.settings_rounded),
    ];
    final items = user == null
        ? <(BackofficeSection, String, String, IconData)>[]
        : allItems.where((item) => canAccessAdminSection(user.rol, item.$1)).toList();

    Widget buildSidebarContent({required bool isDrawer}) {
      return Container(
        width: 280,
        color: Theme.of(context).cardColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        if (user != null && canAccessMainApp(user.rol)) {
                          Future.microtask(() => context.goNamed('home'));
                          return;
                        }
                        final fallback = user == null ? '/login' : firstAllowedAdminRoute(user) ?? '/login';
                        Future.microtask(() => context.go(fallback));
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('admin.shell.backoffice'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(context.tr('admin.shell.navigation'),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: items.map((item) {
                  final selected = location == item.$2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (isDrawer) Navigator.pop(context);
                          Future.microtask(() => context.go(item.$2));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                item.$4,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.$3,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: !isDesktop
          ? Builder(builder: (context) {
        return FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          onPressed: () => Scaffold.of(context).openDrawer(),
          child: const Icon(Icons.menu_rounded),
        );
      })
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      drawer: !isDesktop ? Drawer(child: buildSidebarContent(isDrawer: true)) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: buildSidebarContent(isDrawer: false),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
