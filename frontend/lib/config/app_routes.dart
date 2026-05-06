/// Define la estructura de rutas, las reglas de redirección basadas en
/// autenticación y los permisos de acceso por roles.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/screens/chat/chat_screen.dart';
import 'package:reservives/screens/admin/admin_announcements_screen.dart';
import 'package:reservives/screens/admin/admin_bookings_screen.dart';
import 'package:reservives/screens/admin/admin_historial_screen.dart';
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
import 'package:reservives/screens/home/detail_announcement_screen.dart';
import 'package:reservives/screens/bookings/space_booking_screen.dart';
import 'package:reservives/screens/bookings/detail_booking_screen.dart';
import 'package:reservives/screens/cafeteria/cafeteria_screen.dart';
import 'package:reservives/screens/home/home_screen.dart';
import 'package:reservives/screens/login_screen.dart';
import 'package:reservives/screens/home/notifications_screen.dart';
import 'package:reservives/screens/profile/settings/about_screen.dart';
import 'package:reservives/screens/profile/activity_history_screen.dart';
import 'package:reservives/screens/profile/favorites_screen.dart';
import 'package:reservives/screens/profile/settings/help_screen.dart';
import 'package:reservives/screens/profile/settings/faq_screen.dart';
import 'package:reservives/screens/profile/ies_info/ies_facilities_screen.dart';
import 'package:reservives/screens/profile/ies_info/ies_services_scholarships_screen.dart';
import 'package:reservives/screens/profile/ies_info/ies_studies_screen.dart';
import 'package:reservives/screens/profile/ies_info/ies_who_we_are_screen.dart';
import 'package:reservives/screens/profile/settings/notification_preferences_screen.dart';
import 'package:reservives/screens/profile/profile_screen.dart';
import 'package:reservives/screens/profile/settings_screen.dart';
import 'package:reservives/screens/bookings/bookings_screen.dart';
import 'package:reservives/screens/shell_screen.dart';
import 'package:reservives/screens/profile/polls_screen.dart';
import 'package:reservives/screens/restricted_feature_screen.dart';
import 'package:reservives/screens/welcome_screen.dart';
import 'package:reservives/screens/onboarding/onboarding_screen.dart';

import '../screens/bookings/service_booking_screen.dart';
import 'package:reservives/screens/bookings/recurring_booking_screen.dart';
import 'package:reservives/screens/bookings/calendar_space_screen.dart';

import '../screens/profile/ies_info/ies_info_screen.dart';

/// Un [ChangeNotifier] que reacciona a los cambios en el estado de autenticación.
///
/// Escucha al [authProvider] y notifica al [GoRouter] para que revalide
/// las reglas de redirección cuando un usuario inicia o cierra sesión.
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

/// Provider que gestiona la señal de refresco para el router.
final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  return _RouterRefreshNotifier(ref);
});

/// Provider principal que configura y expone la instancia de [GoRouter].
///
/// Implementa la lógica de seguridad y el árbol de navegación completo:
/// 1. Redirección: Controla que usuarios no autenticados no accedan a zonas privadas.
/// 2. Roles: Protege las rutas de `/admin` y restringe funciones para invitados.
/// 3. Estructura: Utiliza [ShellRoute] para mantener barras de navegación persistentes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,

    /// Lógica de redirección dinámica basada en el estado del usuario.
    ///
    /// Evalúa la [location] actual y determina si el usuario tiene permiso
    /// de acceso o si debe ser enviado al Login o a una ruta por defecto.
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final user = authState.user;
      final isGuest = authState.isGuest;

      // Si la app está cargando el estado de sesión, no redirigir todavía.
      if (authState.isLoading) return null;

      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = location == '/' ||
          location == '/login' ||
          location == '/welcome' ||
          location == '/onboarding';

      // --- FLUJO DE AUTENTICACIÓN ---
      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) {
        if (isGuest) return '/home';
        if (user == null) return '/home';
        return defaultAuthenticatedRoute(user);
      }

      if (!isAuthenticated) return null;

      // --- FLUJO DE INVITADOS (GUEST) ---
      if (isGuest) {
        if (!canGuestAccessLocation(location)) {
          return '/restricted';
        }
        return null;
      }

      // --- FLUJO DE ADMINISTRACIÓN ---
      if (user != null && location.startsWith('/admin')) {
        // Valida si el rol del usuario permite entrar en la ruta admin específica.
        if (!canAccessAdminLocation(user, location)) {
          final fallback = firstAllowedAdminRoute(user) ??
              (canAccessMainApp(user.rol) ? '/home' : '/login');
          return fallback;
        }

        // Si intenta entrar a /admin a secas, redirigir a su panel preferido.
        if (location == '/admin') {
          final preferred = firstAllowedAdminRoute(user);
          if (preferred != null && preferred != '/admin') {
            return preferred;
          }
        }
      }

      // Evita que usuarios con roles solo administrativos accedan a la parte pública.
      if (user != null && !location.startsWith('/admin') && !canAccessMainApp(user.rol)) {
        return firstAllowedAdminRoute(user) ?? '/login';
      }

      return null;
    },
    routes: [
      /// Ruta de bienvenida inicial.
      GoRoute(
        path: '/',
        name: 'welcome',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: WelcomeScreen()),
      ),

      /// Zona Principal con Barra de Navegación ([ShellScreen]).
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
      GoRoute(
        path: '/restricted',
        name: 'restricted',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: RestrictedFeatureScreen()),
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
          GoRoute(
            path: '/ai-chat',
            name: 'ai_chat',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AiChatScreen()),
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
        path: '/reserva-servicio/:servicioId',
        name: 'reserva_servicio',
        pageBuilder: (context, state) => NoTransitionPage(
          child: ServiceBookingScreen(
            servicioId: state.pathParameters['servicioId']!,
          ),
        ),
      ),

      GoRoute(
        path: '/reserva-recurrente/:espacioId',
        name: 'reserva_recurrente',
        pageBuilder: (context, state) => NoTransitionPage(
          child: RecurringBookingScreen(
            espacioId: state.pathParameters['espacioId']!,
          ),
        ),
      ),

      GoRoute(
        path: '/calendario/:espacioId',
        name: 'calendario_espacio',
        pageBuilder: (context, state) => NoTransitionPage(
          child: CalendarSpaceScreen(
            espacioId: state.pathParameters['espacioId']!,
          ),
        ),
      ),

      GoRoute(
        path: '/reservas/:reservaId',
        name: 'reserva_detalle',
        pageBuilder: (context, state) {
          final reserva = state.extra is Reserva ? state.extra as Reserva : null;
          final tipoEspacio = state.uri.queryParameters['tipo'];
          return NoTransitionPage(
            child: ReservaDetalleScreen(
              reservaId: state.pathParameters['reservaId']!,
              reservaInicial: reserva,
              tipoEspacio: tipoEspacio,
            ),
          );
        },
      ),


      /// Zona de Administración BackOffice ([AdminShellScreen]).
      ///
      /// Contiene sub-rutas para gestión de usuarios, espacios, métricas y configuración.
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
                path: 'historial',
                name: 'admin_historial',
                pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminHistorialScreen()),
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
      GoRoute(
        path: '/ies-info/quienes-somos',
        name: 'ies_info_who',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: IesWhoWeAreScreen()),
      ),
      GoRoute(
        path: '/ies-info/instalaciones',
        name: 'ies_info_facilities',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: IesFacilitiesScreen()),
      ),
      GoRoute(
        path: '/ies-info/servicios-becas',
        name: 'ies_info_services',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: IesServicesScholarshipsScreen()),
      ),
      GoRoute(
        path: '/ies-info/ensenanzas',
        name: 'ies_info_studies',
        pageBuilder: (context, state) =>
        const NoTransitionPage(child: IesStudiesScreen()),
      ),
    ],
    debugLogDiagnostics: kDebugMode, 
  );
});
