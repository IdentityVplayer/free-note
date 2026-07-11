# Free Note — Features & Changelog

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

## 1.2.0

### Bug Fixes
- **Android build finally green (AGP downgrade)** — The root cause was
  `file_picker` 11.x skipping the Kotlin Gradle Plugin whenever it detects
  AGP 9 (`isAgp9OrAbove` guard), so its `FilePickerPlugin.kt` was never
  compiled and the APK/AAB build failed with `cannot find symbol
  FilePickerPlugin`. External Kotlin injection (app-module plugin,
  `afterEvaluate`, `gradle.allprojects`, Gradle init script) all failed
  because the Flutter plugin loader evaluates plugin modules during Gradle's
  init/settings phase, before any such hook can run. The reliable fix is to
  drop AGP to **8.11.1** + Gradle **8.9** (within Flutter's supported range
  8.6.0–8.11.1), which makes `file_picker` apply Kotlin itself. The
  `android/gradle/init.gradle` hack and its CI step have been removed.

## 1.1.4

### Bug Fixes
- **Android build fixed (Kotlin timing)** — Apply Built-in Kotlin to the
  `file_picker` module from `settings.gradle.kts` (`gradle.allprojects`) during
  its configuration, so `FilePickerPlugin.kt` compiles on AGP 9 (previous
  `afterEvaluate` hook ran too late).

## 1.1.3

### Bug Fixes
- **Android build fixed (correctly this time)** — file_picker 11.x ships Kotlin
  sources but skips applying the Kotlin Gradle Plugin on AGP 9, so
  `FilePickerPlugin` was never compiled (build failed with
  `cannot find symbol FilePickerPlugin`). Forcing Built-in Kotlin onto the
  `file_picker` module from the root `build.gradle.kts` makes it compile.

## 1.1.2

### Bug Fixes
- **Android build fixed** — Applied the Built-in Kotlin Gradle Plugin to the
  app module so `file_picker` 11.x Kotlin sources compile under AGP 9. The
  Android APK / App Bundle build now succeeds (was failing with
  `cannot find symbol FilePickerPlugin`).

## 1.1.1

### New Features
- **Local folder as your notes repository** — On first launch you now pick a
  folder; every note is stored as a standalone `.md` file (with YAML
  frontmatter), so you can manage them with any tool or sync them yourself.
- **HTML rendering in preview** — Markdown preview now renders embedded HTML.
- **Click-to-open links** — Tapping a link in the preview opens it in your
  default browser.
- **Custom AI providers** — Choose OpenAI, DeepSeek, Moonshot (Kimi), Google
  Gemini, Ollama (local), or a fully custom OpenAI-compatible endpoint with
  your own Base URL.
- **Theme color** — Pick a primary color for the app (6 presets + default).
- **GitHub "Sync Now"** — One-tap immediate sync from the home screen, plus
  clearer error messages (invalid token, missing repo, no permission).

### Changed
- Package name changed to `com.note.apps`.
- GitHub sync reworked for reliability (base64 normalization, status feedback).

### Fixed
- Android build failure caused by `file_picker` compileSdk mismatch — upgraded
  `file_picker` to 11.x to satisfy `compileSdk = 36`.

## 1.0.0

### Initial Release
- Markdown editing with live preview and formatting toolbar.
- Extensible plugin system (word count, text formatter, exporter).
- AI writing assistant (continue, improve, summarize, translate, expand) + Q&A.
- GitHub notes sync (push / pull).
- Multi-language (English, 中文, 日本語).
- Dark mode with Material 3 themes.
- Cross-platform: Android, Windows, Web (Linux/Linux desktop build ready).
