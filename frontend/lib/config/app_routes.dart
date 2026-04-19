library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/screens/admin/admin_announcements_screen.dart';
import 'package:reservives/screens/admin/admin_bookings_screen.dart';
import 'package:reservives/screens/admin/admin_cafeteria_screen.dart';
import 'package:reservives/screens/admin/admin_dashboard.dart';
import 'package:reservives/screens/admin/admin_services_screen.dart';
import 'package:reservives/screens/admin/admin_shell_screen.dart';
import 'package:reservives/screens/admin/admin_spaces_screen.dart';
import 'package:reservives/screens/admin/admin_users_screen.dart';
import 'package:reservives/screens/admin/admin_settings_screen.dart';
import 'package:reservives/screens/admin/admin_reports_screen.dart';
import 'package:reservives/screens/admin/admin_metrics_screen.dart';
import 'package:reservives/screens/admin/admin_polls_screen.dart';
import 'package:reservives/screens/profile/settings/reports_screen.dart';
import 'package:reservives/screens/home/announcement_detail_screen.dart';
import 'package:reservives/screens/bookings/space_booking_screen.dart';
import 'package:reservives/screens/cafeteria/cafeteria_screen.dart';
import 'package:reservives/screens/home/home_screen.dart';
import 'package:reservives/screens/login_screen.dart';
import 'package:reservives/screens/home/notifications_screen.dart';
import 'package:reservives/screens/profile/settings/about_screen.dart';
import 'package:reservives/screens/profile/activity_history_screen.dart';
import 'package:reservives/screens/profile/favorites_screen.dart';
import 'package:reservives/screens/profile/settings/help_screen.dart';
import 'package:reservives/screens/profile/settings/faq_screen.dart';
import 'package:reservives/screens/profile/settings/ies_info_screen.dart';
import 'package:reservives/screens/profile/settings/notification_preferences_screen.dart';
import 'package:reservives/screens/profile/profile_screen.dart';
import 'package:reservives/screens/profile/settings_screen.dart';
import 'package:reservives/screens/bookings/bookings_screen.dart';
import 'package:reservives/screens/shell_screen.dart';
import 'package:reservives/screens/profile/polls_screen.dart';
import 'package:reservives/screens/welcome_screen.dart';
import 'package:reservives/screens/onboarding_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this.ref) {
    ref.listen<AuthState>(authProvider, (_, _) {
      if (_disposed) return;
      notifyListeners();
    });
  }

  final Ref ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  return _RouterRefreshNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      if (authState.isLoading) return null;

      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = location == '/' ||
          location == '/login' ||
          location == '/welcome' ||
          location == '/onboarding';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'welcome',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: WelcomeScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
            const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/servicios',
            name: 'servicios',
            pageBuilder: (context, state) =>
            const NoTransitionPage(child: ServicesScreen()),
          ),
          GoRoute(
            path: '/cafeteria',
            name: 'cafeteria',
            pageBuilder: (context, state) =>
            const NoTransitionPage(child: CafeteriaScreen()),
          ),
          GoRoute(
            path: '/perfil',
            name: 'perfil',
            pageBuilder: (context, state) =>
            const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/booking/:espacioId',
        name: 'booking',
        pageBuilder: (context, state) => NoTransitionPage(
          child: BookingScreen(
            espacioId: state.pathParameters['espacioId']!,
          ),
        ),
      ),


      // Admin BackOffice Shell
      ShellRoute(
        builder: (context, state, child) => AdminShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            name: 'admin',
            pageBuilder: (context, state) =>
            const NoTransitionPage(child: AdminDashboard()),
            routes: [
              GoRoute(
                path: 'usuarios',
                name: 'admin_usuarios',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminUsersScreen()),
              ),
              GoRoute(
                path: 'reservas',
                name: 'admin_reservas',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminBookingsScreen()),
              ),
              GoRoute(
                path: 'anuncios',
                name: 'admin_anuncios',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminAnnouncementsScreen()),
              ),
              GoRoute(
                path: 'cafeteria',
                name: 'admin_cafeteria',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminCafeteriaScreen()),
              ),
              GoRoute(
                path: 'espacios',
                name: 'admin_espacios',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminSpacesScreen()),
              ),
              GoRoute(
                path: 'servicios',
                name: 'admin_servicios',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminServicesScreen()),
              ),
              GoRoute(
                path: 'configuracion',
                name: 'admin_configuracion',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminSettingsScreen()),
              ),
              GoRoute(
                path: 'incidencias',
                name: 'admin_incidencias',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminIncidentsScreen()),
              ),
              GoRoute(
                path: 'metricas',
                name: 'admin_metricas',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminMetricsScreen()),
              ),
              GoRoute(
                path: 'encuestas',
                name: 'admin_encuestas',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminPollsScreen()),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/reportar-incidencia',
        name: 'reportar_incidencia',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: ReportIncidenciaScreen()),
      ),
      GoRoute(
        path: '/votaciones',
        name: 'votaciones',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: VotacionesScreen()),
      ),
      GoRoute(
        path: '/notificaciones',
        name: 'notificaciones',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: NotificationsScreen()),
      ),
      GoRoute(
        path: '/preferencias',
        name: 'preferencias',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: NotificationPreferencesScreen()),
      ),
      GoRoute(
        path: '/ayuda',
        name: 'ayuda',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: HelpScreen()),
      ),
      GoRoute(
        path: '/faq',
        name: 'faq',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: FaqScreen()),
      ),
      GoRoute(
        path: '/actividad',
        name: 'actividad',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: ActivityHistoryScreen()),
      ),
      GoRoute(
        path: '/anuncios/:anuncioId',
        name: 'anuncio_detalle',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AnnouncementDetailScreen(
            anuncioId: state.pathParameters['anuncioId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/favoritos',
        name: 'favoritos',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: FavoritesScreen()),
      ),
      GoRoute(
        path: '/ajustes',
        name: 'ajustes',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: SettingsScreen()),
      ),
      GoRoute(
        path: '/acerca-de',
        name: 'acerca_de',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: AboutScreen()),
      ),
      GoRoute(
        path: '/ies-info',
        name: 'ies_info',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: IesInfoScreen()),
      ),
    ],
    debugLogDiagnostics: kDebugMode,
  );
});