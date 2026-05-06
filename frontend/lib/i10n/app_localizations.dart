import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clase principal encargada de gestionar las cadenas de texto traducidas.
///
/// Almacena tanto las cadenas del idioma actual como las del idioma de respaldo
/// para evitar mostrar claves vacías si falta una traducción.
class AppLocalizations {
  final Locale locale;
  final Map<String, dynamic> _strings;
  final Map<String, dynamic> _fallbackStrings;

  const AppLocalizations({
    required this.locale,
    required Map<String, dynamic> strings,
    required Map<String, dynamic> fallbackStrings,
  })  : _strings = strings,
        _fallbackStrings = fallbackStrings;

  /// Lista de idiomas soportados oficialmente por la aplicación.
  static const supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
    Locale('fr'),
  ];

  /// Método para obtener la instancia de [AppLocalizations] desde el árbol de widgets.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Traduce una clave a texto.
  ///
  /// Si la clave no existe en el idioma actual, busca en el idioma de respaldo (es).
  /// Si el valor es una [List], une los elementos con comas.
  String translate(String key) {
    final value = _strings[key] ?? _fallbackStrings[key];
    if (value is List) return value.join(', ');
    return value?.toString() ?? key;
  }

  /// Obtiene el valor crudo (sin formatear) de una traducción.
  dynamic translateRaw(String key) {
    return _strings[key] ?? _fallbackStrings[key];
  }
}

/// Extensión sobre [BuildContext] para simplificar el acceso a las traducciones.
extension AppContextI18nX on BuildContext {
  /// Obtiene la traducción simple de una clave: `context.tr('clave')`.
  String tr(String key) => AppLocalizations.of(this).translate(key);

  /// Obtiene una lista de strings desde una clave JSON: `context.trList('clave_lista')`.
  List<String> trList(String key) {
    final data = AppLocalizations.of(this).translateRaw(key);
    if (data is List) return data.map((e) => e.toString()).toList();
    return [];
  }
}

/// Delegado que Flutter utiliza para cargar los recursos de idioma durante el inicio.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  static const _fallbackLanguageCode = 'es';
  /// Caché en memoria para evitar recargar archivos JSON ya procesados.
  static final Map<String, Map<String, dynamic>> _cache = {};

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  /// Carga y parsea el archivo JSON desde los assets.
  Future<Map<String, dynamic>> _loadStrings(String languageCode) async {
    if (_cache.containsKey(languageCode)) return _cache[languageCode]!;
    Map<String, dynamic> decoded;
    try {
      final jsonStr = await rootBundle.loadString('assets/lang/$languageCode.json');
      decoded = jsonDecode(jsonStr);
    } catch (_) {
      // Permite registrar nuevos idiomas antes de añadir su JSON.
      if (languageCode == _fallbackLanguageCode) rethrow;
      final fallbackStr = await rootBundle.loadString('assets/lang/$_fallbackLanguageCode.json');
      decoded = jsonDecode(fallbackStr);
    }

    _cache[languageCode] = decoded;
    return decoded;
  }

  /// Proceso de carga de la localización.
  /// Carga el idioma seleccionado y el fallback simultáneamente.
  @override
  Future<AppLocalizations> load(Locale locale) async {
    final resolved = isSupported(locale) ? locale : const Locale(_fallbackLanguageCode);
    final primary = await _loadStrings(resolved.languageCode);
    final fallback = await _loadStrings(_fallbackLanguageCode);

    return AppLocalizations(
      locale: resolved,
      strings: primary,
      fallbackStrings: fallback,
    );
  }

  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) => false;
}
