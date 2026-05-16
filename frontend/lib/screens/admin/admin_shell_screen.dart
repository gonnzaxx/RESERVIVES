import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/admin_websocket_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/role_permissions_provider.dart';
import 'package:reservives/widgets/app_logo.dart';

class AdminShellScreen extends ConsumerWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminWebSocketProvider).connect();
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final location = GoRouterState.of(context).uri.path;
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1100;

    final allItems = [
      _NavSection(context.tr('admin.shell.section.overview'), [
        _NavItem(BackofficeSection.summary, '/admin', context.tr('admin.shell.summary'), Icons.dashboard_rounded),
        _NavItem(BackofficeSection.metrics, '/admin/metricas', context.tr('admin.shell.metrics'), Icons.insights_rounded),
      ]),
      _NavSection(context.tr('admin.shell.section.management'), [
        _NavItem(BackofficeSection.users, '/admin/usuarios', context.tr('admin.shell.users'), Icons.people_alt_rounded),
        _NavItem(BackofficeSection.bookings, '/admin/reservas', context.tr('admin.shell.bookings'), Icons.approval_rounded),
        _NavItem(BackofficeSection.history, '/admin/historial', context.tr('admin.shell.record'), Icons.history_rounded),
        _NavItem(BackofficeSection.polls, '/admin/encuestas', context.tr('polls.user.title'), Icons.how_to_vote_rounded),
        _NavItem(BackofficeSection.incidents, '/admin/incidencias', context.tr('admin.shell.incidents'), Icons.report_problem_rounded),
      ]),
      _NavSection(context.tr('admin.shell.section.content'), [
        _NavItem(BackofficeSection.spaces, '/admin/espacios', context.tr('admin.shell.spaces'), Icons.grid_view_rounded),
        _NavItem(BackofficeSection.services, '/admin/servicios', context.tr('admin.shell.services'), Icons.build_circle_rounded),
        _NavItem(BackofficeSection.announcements, '/admin/anuncios', context.tr('admin.shell.announcements'), Icons.campaign_rounded),
        _NavItem(BackofficeSection.cafeteria, '/admin/cafeteria', context.tr('admin.shell.cafeteria'), Icons.local_cafe_rounded),
      ]),
      _NavSection(context.tr('admin.shell.section.system'), [
        _NavItem(BackofficeSection.configuration, '/admin/configuracion', context.tr('admin.shell.configuration'), Icons.settings_rounded),
        _NavItem(BackofficeSection.azure, '/admin/azure', context.tr('admin.shell.azure'), Icons.cloud_rounded),
        _NavItem(BackofficeSection.configuration, '/admin/personalizacion', context.tr('admin.shell.personalization'), Icons.palette_rounded),
      ]),
    ];

    final customSections = ref.watch(rolePermissionsProvider).maybeWhen(
      data: (v) => v,
      orElse: () => <String, List<String>>{},
    );

    final filteredSections = user == null
        ? <_NavSection>[]
        : allItems
            .map((section) => _NavSection(
                  section.title,
                  section.items
                      .where((item) => canAccessAdminSectionDynamic(user.rol, item.section, customSections, rolRaw: user.rolRaw))
                      .toList(),
                ))
            .where((section) => section.items.isNotEmpty)
            .toList();

    // Construye el contenido del sidebar lateral (o del drawer en móvil)
    Widget buildSidebarContent({required bool isDrawer}) {
      return Container(
        width: 280,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: isDrawer
              ? null
              : Border(
            right: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (isDrawer) Navigator.pop(context);
                          if (user != null && canAccessMainApp(user.rol)) {
                            Future.microtask(() => context.goNamed('perfil'));
                            return;
                          }
                          final fallback = user == null ? '/login' : firstAllowedAdminRoute(user) ?? '/login';
                          Future.microtask(() => context.go(fallback));
                        },
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AppLogo(height: 36),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('admin.shell.backoffice'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: filteredSections.map((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Text(
                          section.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isDark
                                ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                                : AppColors.lightTextSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      ...section.items.map((item) {
                        final selected = location == item.path;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: selected
                                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (isDrawer) Navigator.pop(context);
                                Future.microtask(() => context.go(item.path));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                            : (isDark
                                            ? Colors.white.withValues(alpha: 0.04)
                                            : Colors.black.withValues(alpha: 0.03)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 17,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: selected ? theme.colorScheme.primary : null,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Container(
                                        width: 4,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
            if (user != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                      backgroundImage: user.fullAvatarUrl != null
                          ? NetworkImage(user.fullAvatarUrl!)
                          : null,
                      child: user.fullAvatarUrl == null
                          ? Text(
                        user.nombre[0].toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nombre,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
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
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => Scaffold.of(context).openDrawer(),
          child: const Icon(Icons.menu_rounded, size: 24),
        );
      })
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      drawer: !isDesktop ? Drawer(child: buildSidebarContent(isDrawer: true)) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop) buildSidebarContent(isDrawer: false),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _NavSection {
  final String title;
  final List<_NavItem> items;
  _NavSection(this.title, this.items);
}

class _NavItem {
  final BackofficeSection section;
  final String path;
  final String label;
  final IconData icon;
  _NavItem(this.section, this.path, this.label, this.icon);
}
