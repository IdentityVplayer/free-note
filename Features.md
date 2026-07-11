# 无边记 (Borderless Notes) — Features & Changelog

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

## 1.3.1

### Fixed
- **AI 与 GitHub 同步在发布版用不了（根因）** — Android 清单缺少 `INTERNET` 权限，导致发布版（release）下所有网络请求（AI 调用、`api.github.com` 同步）一律失败；调试版由 Flutter 自动授予该权限，所以只在真机/发布版暴露。已补上 `android.permission.INTERNET`（及 `ACCESS_NETWORK_STATE`），AI 与 GitHub 同步恢复正常。

## 1.3.0

### New Features
- **递归文件夹扫描** — 选择笔记文件夹后，自动识别该文件夹**及其所有子目录**下的 `.md` 文件。没有 frontmatter 的普通 Markdown 文件也会被识别为笔记（按相对路径生成稳定 id），并保持原有子目录结构。
- **应用改名「无边记」** — 各平台显示名（Android / Windows / Linux / Web / 应用内标题与多语言）统一改为「无边记」(Borderless Notes)。Dart 包名 `free_note` 与 Android 包名 `com.note.apps` 保持不变。

### Fixed
- **AI 功能可用性问题** — 之前任何 API 调用失败（如所选服务商的默认模型不匹配、网络错误）都会被静默当成「未配置」提示，导致填了密钥也像没生效。现在会**如实显示真实错误信息**（HTTP 状态码 + 服务商返回的具体原因）。新增按服务商自动填入默认模型：OpenAI `gpt-3.5-turbo`、DeepSeek `deepseek-chat`、Moonshot `moonshot-v1-8k`、Google `gemini-1.5-flash`、Ollama `llama3`，切到对应服务商即自动带上，开箱即用。
- **GitHub 同步提示修正** — 仓库输入框示例从错误的 `username/free--note` 改为正确的 `username/free-note`，避免用户照抄后 404。

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
