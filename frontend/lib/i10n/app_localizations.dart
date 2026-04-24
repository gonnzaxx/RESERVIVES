import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Carga traducciones desde `assets/lang/{languageCode}.json`.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings;
  final Map<String, String> _fallbackStrings;

  const AppLocalizations({
    required this.locale,
    required Map<String, String> strings,
    required Map<String, String> fallbackStrings,
  })  : _strings = strings,
        _fallbackStrings = fallbackStrings;

  static const supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String translate(String key) {
    return _strings[key] ?? _fallbackStrings[key] ?? key;
  }
}

extension AppLocalizationBuildContextX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).translate(key);
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  static const _fallbackLanguageCode = 'es';
  static final Map<String, Map<String, String>> _cache = {};

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  Future<Map<String, String>> _loadStrings(String languageCode) async {
    if (_cache.containsKey(languageCode)) return _cache[languageCode]!;

    final jsonStr = await rootBundle.loadString('assets/lang/$languageCode.json');
    final decoded = jsonDecode(jsonStr);
    final map = (decoded as Map<String, dynamic>).map<String, String>(
      (key, value) => MapEntry(key, value.toString()),
    );

    _cache[languageCode] = map;
    return map;
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final resolved =
        isSupported(locale) ? locale : const Locale(_fallbackLanguageCode);

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
