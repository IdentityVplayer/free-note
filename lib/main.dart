import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

/// Free Note — A multifunctional cross-platform note-taking app.
/// Features: Markdown, Plugins, AI Writing, GitHub Sync, i18n, Dark Mode.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FreeNoteApp());
}

class FreeNoteApp extends StatelessWidget {
  const FreeNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Free Note',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(provider.settings.languageCode),
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
              Locale('ja'),
            ],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              // Flutter's built-in localization delegates for material widgets.
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
