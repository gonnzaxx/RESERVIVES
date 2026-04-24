import 'package:reservives/models/usuario.dart';

const int maxUserTokens = 100;

enum BackofficeSection {
  summary,
  users,
  bookings,
  polls,
  incidents,
  metrics,
  spaces,
  services,
  announcements,
  cafeteria,
  configuration,
}

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

BackofficeSection? sectionFromLocation(String location) {
  if (location == '/admin') return BackofficeSection.summary;
  if (location.startsWith('/admin/usuarios')) return BackofficeSection.users;
  if (location.startsWith('/admin/reservas')) return BackofficeSection.bookings;
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

bool hasAnyBackofficeAccess(RolUsuario role) {
  return BackofficeSection.values.any((section) => canAccessAdminSection(role, section));
}

bool canAccessMainApp(RolUsuario role) => true;

String defaultAuthenticatedRoute(Usuario user) {
  if (!canAccessMainApp(user.rol)) {
    return firstAllowedAdminRoute(user) ?? '/login';
  }
  return '/home';
}

String? firstAllowedAdminRoute(Usuario user) {
  for (final section in BackofficeSection.values) {
    if (canAccessAdminSection(user.rol, section)) {
      return sectionPath(section);
    }
  }
  return null;
}

bool canAccessAdminLocation(Usuario user, String location) {
  final section = sectionFromLocation(location);
  if (section == null) return hasAnyBackofficeAccess(user.rol);
  return canAccessAdminSection(user.rol, section);
}
