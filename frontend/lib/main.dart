/// Punto de entrada de la aplicación Flutter.
///
/// Configura el entorno global de la aplicación, incluyendo la inicialización
/// de servicios asíncronos (notificaciones, localización) y la gestión
/// de estados globales mediante Riverpod.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reservives/config/app_routes.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/branding_provider.dart';
import 'package:reservives/providers/locale_provider.dart';
import 'package:reservives/providers/theme_provider.dart';
import 'package:reservives/services/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de Localización y Tema
  final initialLocale = await loadInitialLocale();
  Intl.defaultLocale = initialLocale.languageCode;
  await initializeDateFormatting(initialLocale.languageCode, null);
  final initialTheme = await loadInitialTheme();

  // Inicializa el servicio de notificaciones Push.
  await initializePushNotificationsBootstrap();
  runApp(
    ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWithValue(initialLocale),
        initialThemeModeProvider.overrideWithValue(initialTheme),
      ],
      child: const ReservivesApp(),
    ),
  );
}

/// Widget raíz de la aplicación.
///
/// Utiliza [ConsumerWidget] para reaccionar a cambios en el tema,
/// el idioma y la configuración de rutas de forma reactiva.
class ReservivesApp extends ConsumerWidget {
  const ReservivesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observadores de estado global.
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final branding = ref.watch(brandingProvider);
    final seedColor = branding.effectivePrimaryColor;
    // Preferencia del usuario tiene prioridad; si no hay, se usa el tema del admin.
    final userTheme = ref.watch(themeProvider);
    final themeMode = userTheme ?? branding.effectiveThemeMode;

    return MaterialApp.router(
      title: 'IES Luis Vives',
      debugShowCheckedModeBanner: false,

      // Configuración de UI y Estilos.
      theme: AppTheme.lightThemeFor(seedColor),
      darkTheme: AppTheme.darkThemeFor(seedColor),
      themeMode: themeMode,

      // Configuración de internacionalización.
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Configuración de navegación basada en GoRouter.
      routerConfig: router,
    );
  }
}
