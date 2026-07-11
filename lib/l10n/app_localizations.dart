import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

/// Simple JSON-based internationalization support.
/// Loads translations from assets and provides lookup by key.
class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Load the JSON file for the current locale.
  Future<void> load() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString('lib/l10n/app_${locale.languageCode}.json');
    } catch (_) {
      jsonString = await rootBundle.loadString('lib/l10n/app_en.json');
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  /// Translate a key.
  String t(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// Translate with optional plural/parameter support.
  String tArgs(String key, List<String> args) {
    String value = _localizedStrings[key] ?? key;
    for (var i = 0; i < args.length; i++) {
      value = value.replaceAll('{$i}', args[i]);
    }
    return value;
  }
}

/// Delegate for loading AppLocalizations.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
