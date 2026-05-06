import 'package:reservives/models/usuario.dart';

/// Límite máximo de tokens de usuario permitidos.
const int maxUserTokens = 100;

/// Enumeración de todas las secciones disponibles en el Backoffice.
enum BackofficeSection {
  summary,       // Resumen/Dashboard
  users,         // Gestión de usuarios
  bookings,      // Gestión de reservas
  polls,         // Administración de encuestas
  incidents,     // Reportes de incidencias
  metrics,       // Estadísticas y métricas
  spaces,        // Gestión de espacios físicos
  services,      // Gestión de servicios del centro
  announcements, // Publicación de anuncios
  cafeteria,     // Gestión del módulo de cafetería
  configuration, // Ajustes globales del sistema
}

/// Mapea una sección del [BackofficeSection] a su ruta de navegación correspondiente.
String sectionPath(BackofficeSection section) {
  switch (section) {
    case BackofficeSection.summary:
      return '/admin';
    case BackofficeSection.users:
      return '/admin/usuarios';
    case BackofficeSection.bookings:
      return '/admin/reservas';
    case BackofficeSection.polls:
      return '/admin/encuestas';
    case BackofficeSection.incidents:
      return '/admin/incidencias';
    case BackofficeSection.metrics:
      return '/admin/metricas';
    case BackofficeSection.spaces:
      return '/admin/espacios';
    case BackofficeSection.services:
      return '/admin/servicios';
    case BackofficeSection.announcements:
      return '/admin/anuncios';
    case BackofficeSection.cafeteria:
      return '/admin/cafeteria';
    case BackofficeSection.configuration:
      return '/admin/configuracion';
  }
}

/// Identifica la sección del Backoffice a partir de una cadena de [location] (URL/Ruta).
/// Retorna `null` si la ruta no pertenece al área administrativa.
BackofficeSection? sectionFromLocation(String location) {
  if (location == '/admin') return BackofficeSection.summary;
  if (location.startsWith('/admin/usuarios')) return BackofficeSection.users;
  if (location.startsWith('/admin/reservas')) return BackofficeSection.bookings;
  if (location.startsWith('/admin/historial')) return BackofficeSection.bookings;
  if (location.startsWith('/admin/encuestas')) return BackofficeSection.polls;
  if (location.startsWith('/admin/incidencias')) return BackofficeSection.incidents;
  if (location.startsWith('/admin/metricas')) return BackofficeSection.metrics;
  if (location.startsWith('/admin/espacios')) return BackofficeSection.spaces;
  if (location.startsWith('/admin/servicios')) return BackofficeSection.services;
  if (location.startsWith('/admin/anuncios')) return BackofficeSection.announcements;
  if (location.startsWith('/admin/cafeteria')) return BackofficeSection.cafeteria;
  if (location.startsWith('/admin/configuracion')) return BackofficeSection.configuration;
  return null;
}

/// Define la matriz de permisos: Determina si un [role] tiene permiso para ver una [section].
///
/// - [RolUsuario.admin]: Acceso total.
/// - [RolUsuario.cafeteria]: Solo gestión de cafetería.
/// - [RolUsuario.jefeEstudios]: Acceso amplio excepto a sistemas y dashboard principal.
/// - [RolUsuario.secretaria]: Gestión de contenido informativo (encuestas y anuncios).
/// - [RolUsuario.profesorServicio]: Solo gestión de sus propios servicios.
bool canAccessAdminSection(RolUsuario role, BackofficeSection section) {
  switch (role) {
    case RolUsuario.admin:
      return true;
    case RolUsuario.cafeteria:
      return section == BackofficeSection.cafeteria;
    case RolUsuario.jefeEstudios:
      return section != BackofficeSection.summary &&
          section != BackofficeSection.incidents &&
          section != BackofficeSection.configuration;
    case RolUsuario.secretaria:
      return section == BackofficeSection.polls ||
          section == BackofficeSection.announcements;
    case RolUsuario.profesorServicio:
      return section == BackofficeSection.services;
    case RolUsuario.alumno:
    case RolUsuario.profesor:
      return false;
  }
}

/// Verifica si el usuario tiene permiso para entrar a cualquier parte del Backoffice.
bool hasAnyBackofficeAccess(RolUsuario role) {
  return BackofficeSection.values.any((section) => canAccessAdminSection(role, section));
}

/// Define si un rol puede acceder a la aplicación principal.
bool canAccessMainApp(RolUsuario role) => true;

/// Determina la ruta inicial tras el login según el rol del [user].
/// Prioriza el área de usuario (/home) si tiene permiso, de lo contrario busca la primera ruta administrativa permitida.
String defaultAuthenticatedRoute(Usuario user) {
  if (!canAccessMainApp(user.rol)) {
    return firstAllowedAdminRoute(user) ?? '/login';
  }
  return '/home';
}

/// Busca de forma secuencial la primera sección administrativa a la que el usuario tiene permiso.
String? firstAllowedAdminRoute(Usuario user) {
  for (final section in BackofficeSection.values) {
    if (canAccessAdminSection(user.rol, section)) {
      return sectionPath(section);
    }
  }
  return null;
}

/// Valida en tiempo de ejecución si un usuario puede navegar a una ruta de administración específica.
bool canAccessAdminLocation(Usuario user, String location) {
  final section = sectionFromLocation(location);
  // Si no se identifica la sección pero es una ruta /admin, verificamos si tiene algún acceso de backoffice.
  if (section == null) return hasAnyBackofficeAccess(user.rol);
  return canAccessAdminSection(user.rol, section);
}

/// Define la lista blanca de rutas accesibles para usuarios "Invitados" (sin login).
/// Bloquea explícitamente cualquier intento de reserva o acceso a servicios privados.
bool canGuestAccessLocation(String location) {
  const allowedExact = <String>{
    '/home',
    '/servicios',
    '/cafeteria',
    '/perfil',
    '/ajustes',
    '/acerca-de',
    '/faq',
    '/ayuda',
    '/ies-info',
    '/ies-info/quienes-somos',
    '/ies-info/instalaciones',
    '/ies-info/servicios-becas',
    '/ies-info/ensenanzas',
    '/restricted',
    '/login',
    '/welcome',
    '/onboarding',
    '/',
  };
  if (allowedExact.contains(location)) return true;

  // Los anuncios son públicos para lectura.
  if (location.startsWith('/anuncios/')) return true;

  // Las reservas de espacios y servicios están prohibidas para invitados.
  if (location.startsWith('/booking/')) return false;
  if (location.startsWith('/reserva-servicio/')) return false;
  return false;
}
