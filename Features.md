# Free Note — Features & Changelog

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

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
