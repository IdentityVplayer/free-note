# 无边记 (Free Notes)

A multifunctional, cross-platform note-taking app built with Flutter.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Web-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

| Feature | Description |
|---------|-------------|
| **Markdown** | Full Markdown editing with live preview, formatting toolbar |
| **Plugins** | Extensible plugin system with built-in word count, formatter, and exporter |
| **AI Writing** | AI-powered writing assistance (continue, improve, summarize, translate, expand) and Q&A chat |
| **GitHub Sync** | Sync notes to a GitHub repository for backup and cross-device access |
| **Multi-Language** | English, 中文, 日本語 |
| **Dark Mode** | Beautiful light and dark themes |

## Screenshots

- Notes list with search, tags, pin/favorite
- Markdown editor with toolbar and live preview
- AI assistant chat interface
- Plugin manager
- Settings (language, AI, GitHub, theme)

## Getting Started

### Prerequisites

- Flutter 3.x (stable channel)
- Dart 3.x
- Android Studio / Xcode (for mobile builds)
- Visual Studio with C++ workload (for Windows builds)

### Install & Run

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/free-note-workbuddy.git
cd free-note-workbuddy

# Get dependencies
flutter pub get

# Run
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

## Configuration

### AI (OpenAI-compatible API)

1. Open **Settings** in the app
2. Enter your API key (e.g., `sk-...`)
3. Select model (default: `gpt-3.5-turbo`)

> The AI service supports any OpenAI-compatible endpoint. You can modify `baseUrl` in `lib/services/ai_service.dart`.

### GitHub Sync

1. Create a GitHub Personal Access Token with `repo` scope
2. Open **Settings** → Enter token and repository (`owner/repo`)
3. Tap **Sync Now** to push notes to GitHub

## Plugin Development

Create a plugin by extending `FreeNotePlugin`:

```dart
import 'package:free_note/plugins/plugin_base.dart';
import 'package:free_note/models/plugin.dart';

class MyPlugin extends FreeNotePlugin {
  @override
  String get id => 'myplugin';
  @override
  String get name => 'My Plugin';
  @override
  String get description => 'Does something cool';
  @override
  String get version => '1.0.0';
  @override
  String get author => 'You';
  @override
  PluginType get type => PluginType.utility;

  @override
  String? processText(String input) {
    // Transform text...
    return input.toUpperCase();
  }
}
```

Register it in `AppProvider.init()`:

```dart
pluginManager.register(MyPlugin());
```

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/                    # Data models
│   ├── note.dart
│   ├── plugin.dart
│   └── settings.dart
├── services/                  # Business logic
│   ├── storage_service.dart
│   ├── ai_service.dart
│   └── github_sync_service.dart
├── providers/                 # State management
│   └── app_provider.dart
├── screens/                   # UI pages
│   ├── home_screen.dart
│   ├── editor_screen.dart
│   ├── settings_screen.dart
│   ├── ai_assistant_screen.dart
│   └── plugins_screen.dart
├── plugins/                   # Plugin system
│   ├── plugin_base.dart
│   ├── plugin_manager.dart
│   └── builtin_plugins.dart
└── l10n/                      # Internationalization
    ├── app_localizations.dart
    ├── app_en.json
    ├── app_zh.json
    └── app_ja.json
```

## CI/CD with GitHub Actions

This project includes two GitHub Actions workflows:

- **CI** (`.github/workflows/ci.yml`): Runs on every push/PR — analyzes code, verifies formatting, runs tests
- **Build & Release** (`.github/workflows/build_release.yml`): Triggered by version tags (`v*`) — builds Android APK, Windows app, and Web bundle, then publishes a GitHub Release

### Creating a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow will automatically build all platforms and create a GitHub Release with downloadable artifacts.

## License

MIT — see [LICENSE](LICENSE)
