# 无边记 (Borderless Notes) — Features & Changelog

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

## 1.8.1

### Fixed
- **上下文文件选择器现在显示所有文件夹** — 之前只把「含有 `.md` 的文件夹」列成分组，空文件夹和尚未放笔记的子目录不显示。现改为直接扫描笔记目录的真实目录树：所有子文件夹（含空文件夹）都会列出，点开才显示其中的 `.md` 文件，顶层 `.md` 仍直接显示。

## 1.8.0

### Changed
- **ai-context 插件改为「任意 md 作上下文」** — 不再仅限于 AI 对话文件：编辑器右上角上传图标对所有笔记开放，AI 助手顶栏也新增附件按钮（回形针），可任选一个 Markdown 文件作为上下文。
- **上下文在发送时前置** — 选定上下文文件后，用户点击发送时，该 `.md` 的**全文内容会自动补在输入前面**一并发给模型，模型据此作答；顶栏显示上下文来源条，可一键清除。
- **AI 对话支持 Markdown 链接与图片** — 助手消息改用 Markdown 渲染：`[文本](链接)` 变为可点击，点击调用默认浏览器打开；`![描述](图片地址)` 图片语法兼容渲染（网络图片直接显示）。

### New Features
- **按文件夹分类选择上下文文件** — 新增 `ContextFilePickerScreen`：罗列笔记文件夹下所有 `.md`，顶层文件直接显示，位于子文件夹的文件归入可展开的文件夹分组（如 `fl` 文件夹点开后才显示其中的 `1.md`），方便按目录挑选。
- **首页加号新增「新建文件夹」** — 右下角悬浮按钮改为可展开菜单：除「新建笔记」外，新增「新建文件夹」，可直接在所选笔记目录下创建文件夹。

## 1.7.0

### Changed
- **配置移出 Markdown 文本，改存 `.config` 文件夹** — 笔记的元数据（标题、标签、置顶、收藏、时间戳、相对路径）不再以 YAML frontmatter 写在 `.md` 顶部，而是单独存到笔记文件夹下的隐藏目录 `.config/<id>.json`；`.md` 文件只保留纯正文。打开/编辑笔记不再被 frontmatter 干扰，目录结构也更干净。旧版带 frontmatter 的 `.md` 会在首次加载时自动迁移。

### New Features
- **AI 对话文件加标记行** — 用 AI 助手保存的对话（`Chat-YYYY-MM-DD-HH-MM-SS.md`）现在文件首行固定写入 `! Free note ai chat`，便于识别与解析。
- **ai-context 插件** — 新增内置插件 `AI Context`。在编辑器中打开由 Free Note 生成的 AI 对话时，右上角会出现一个**上传图标**；点击后，插件解析该文件并把整段对话作为上下文直接填充进 AI 助手，可接着聊。插件在「插件」页可见、可开关。

## 1.6.0

### New Features
- **子文件夹（子目录）保存** — 编辑器新增「保存位置」行，可**在已选笔记文件夹内**挑选或新建子文件夹，把笔记直接存进 `子文件夹/xxx.md`，而**无需回到设置里切换根文件夹**。不切换根文件夹即可读取、写入子目录下的文件。
- **编辑器显示真实保存位置** — 编辑器顶部（保存位置行）实时显示笔记将写入的**根文件夹 + 子文件夹**（如 `根目录` 或 `work/projects`），不再显示 `/data` 等隐藏路径。未选择文件夹时显示「默认（应用私有目录）」。
- **导出写入所选文件夹** — 修复「导出」按钮（右上角下载图标）曾把 `xxx.md` 写进应用私有 `/data/.../exports` 的问题，现在导出文件与笔记一样落在用户选择的笔记文件夹里。

### Changed
- **移动笔记自动清理旧文件** — 当一篇笔记的相对路径（所在子文件夹）发生变化时，`updateNote` 会先删除旧位置的 `.md` 文件，避免移动后在两个目录留下重复副本。

## 1.5.0

### New Features
- **AI 对话可保存为笔记** — 在 AI 助手界面按返回键时，若已有对话，会询问「是否保存为 Markdown 笔记」。选择保存则生成 `Chat-YYYY-MM-DD-HH-MM-SS.md` 写入笔记文件夹，并在笔记列表立即出现。
- **全平台自动构建并发布工作流** — 新增 `auto_build.yml`：每次 push 到 `main` 自动构建全平台产物——Android 用 GitHub Secrets 中的上传密钥**签名** APK，Windows / Web 也一并自动构建，并汇总发布为 GitHub Release（预发布，每次 push 一个，标签 `auto-<commit>`）。正式带版本号的发布仍由打 `v*` 标签触发 `build_release.yml` 完成（代码签名仅需 Android 的上传密钥，Windows 如需 Authenticode 需另备证书）。
- **文件夹选择改为应用内浏览器（修复 Android 无法写入）** — 原先使用 `FilePicker.getDirectoryPath()`，在 Android 11+ 上返回的是 SAF tree-URI 路径，`dart:io` 无法直接读写，导致笔记从不落盘且不报错。现改为应用内文件夹浏览器，浏览**真实文件系统路径**，并申请「所有文件访问」权限（Android）+ 写入探测。所选文件夹可真正写入 `.md` 笔记，并递归识别其及子目录下的 `.md` 文件。
- **保存失败不再静默丢失** — 笔记保存、文件夹写入探测均有错误上报；无写入权限或 SAF 路径会明确提示，而不是悄悄丢笔记。

## 1.4.0

### New Features
- **Sealos AIProxy 服务商** — 新增 `sealos` 预设，Base URL 为 `https://aiproxy.hzh.sealos.run/v1`（如需精确地址可在「自定义」里改）。
- **多模型 + 对话中切换** — 设置里可添加多个模型（保留一个默认模型，并可在「已添加模型」中增删）。AI 对话界面顶部新增模型下拉框，对话过程中可随时切换模型，每条消息使用所选模型。

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
