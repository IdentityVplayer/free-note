import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/folder_picker_screen.dart';

/// Borderless Notes (无边记) — A multifunctional cross-platform note-taking app.
/// Features: Markdown, Plugins, AI Writing, GitHub Sync, i18n, Dark Mode.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FreeNoteApp());
}

class FreeNoteApp extends StatelessWidget {
  const FreeNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const defaultSeed = Color(0xFF6750A4);
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final seed = provider.themeColor ?? defaultSeed;
          return MaterialApp(
            title: 'Borderless Notes',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(seed),
            darkTheme: _buildDarkTheme(seed),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            // Empty languageCode means "follow system" — let Flutter use the
            // platform dispatcher's locale instead of forcing one.
            locale: provider.settings.languageCode.isEmpty
                ? null
                : Locale(provider.settings.languageCode),
            supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: provider.isLoading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : provider.needsFolderSelection
                ? const FolderPickerScreen()
                : const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme(Color seed) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  ThemeData _buildDarkTheme(Color seed) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
