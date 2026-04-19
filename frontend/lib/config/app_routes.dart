library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/screens/home/announcement_detail_screen.dart';
import 'package:reservives/screens/bookings/space_booking_screen.dart';
import 'package:reservives/screens/cafeteria/cafeteria_screen.dart';
import 'package:reservives/screens/home/home_screen.dart';
import 'package:reservives/screens/login_screen.dart';
import 'package:reservives/screens/home/notifications_screen.dart';
import 'package:reservives/screens/profile/activity_history_screen.dart';
import 'package:reservives/screens/profile/favorites_screen.dart';
import 'package:reservives/screens/profile/profile_screen.dart';
import 'package:reservives/screens/profile/settings_screen.dart';
import 'package:reservives/screens/bookings/bookings_screen.dart';
import 'package:reservives/screens/shell_screen.dart';
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



      GoRoute(
        path: '/notificaciones',
        name: 'notificaciones',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: NotificationsScreen()),
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
    ],
    debugLogDiagnostics: kDebugMode,
  );
});