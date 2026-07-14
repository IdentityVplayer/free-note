# 无边记 (Borderless Notes) — Features & Changelog

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

## 1.9.8

### New Features
- **插件页「+」按钮添加插件** — `PluginsScreen` 右上角新增「+」按钮，点击弹出对话框，可填写名称 / 描述 / 类型（编辑器 / 导出器 / 导入器 / 主题 / 工具）创建**用户插件**。新建的用户插件会即时注册进 `PluginManager` 并持久化（存入 `AppSettings.userPlugins`），重启后自动还原；用户插件在插件卡片标题旁带「个人」图标，**长按卡片即可移除**。
- **`skill/Agents.md` 插件开发指南** — 项目根目录新增 `skill/Agents.md`，面向 AI / 智能体说明如何遵循 `FreeNotePlugin` / `PluginInfo` / `PluginManager` / `GitHubSyncHost` 契约开发并注册一个插件，含最小模板、类型选择、设置页、i18n、测试清单。
- **设置页 导出 / 导入（.fne 归档）** — 设置页新增「数据备份」区块：
  - **导出**：将当前笔记文件夹（含 `.config` 元数据）打包为 `{文件夹名}_export.fne` 文件（实际为 **zip** 归档），通过系统文件选择器保存到用户指定位置。
  - **导入**：从 `.fne` 归档读取并合并回当前文件夹（覆盖同名文件），导入后自动重新加载笔记列表。

### Changed
- **默认语言跟随系统** — `AppSettings.languageCode` 默认值由 `en` 改为空字符串（代表「跟随系统」）。设置页语言选项新增「跟随系统」，并显示当前系统语言；`main.dart` 在语言为空时不强制 `locale`，交由 Flutter 使用设备系统语言。

### Notes
- 导出 / 导入依赖新增的 `archive` 包与已有的 `file_picker` 包（v11 静态 API）。
- `.fne` 本质是标准 zip，可直接用任意解压工具打开查看内部笔记。

## 1.9.7

### Changed
- **OAuth 默认 Client ID** — 内置默认 GitHub OAuth App Client ID（`Ov23liBn5JuhulMcevmz`），GitHub Sync 设置页改为一个醒目的「立即登录」按钮，下方一行小字「使用其他的Oauth登录」用于切换到自定义 OAuth App（展开 Client ID 输入框）。
- **Auto Save 逻辑重构** — 由「仅 dispose 时保存」改为在**返回键（左上返回 / 手机返回 / 系统手势）**与**应用切到后台（paused / detached）**时保存。编辑器接入 `WidgetsBinding` 生命周期监听与 `PopScope`，Auto Save 插件（默认启用）在以上时机自动写入当前 `.md`，且幂等（重复触发不会重复落盘）。

### Fixed
- **插件页开关实时生效** — 之前切换插件开关后界面不刷新；现在 `PluginsScreen` 直接监听 `PluginManager`（`ListenableBuilder`），开关状态即时显示。
- **Word Count / Export Tool 插件生效** — 之前这两个插件开关无实际效果。现编辑器的**字数状态栏**仅在「Word Count」启用时显示，**导出按钮**仅在「Export Tools」启用时显示，关闭即隐藏，开关真正可控。

## 1.9.5

### New Features
- **新增插件：Auto Save（默认启用）** — 退出编辑器前自动保存当前笔记的 `.md` 文件，即使内存中的「已修改」标记未被触发也会写入。可在插件页通过开关临时关闭。
- **GitHub Sync 重构为插件 + Device 登录** — GitHub 同步现在是一个独立插件（在「插件」页中）。登录方式改为 **GitHub Device 登录**：点击登录后弹出验证码与授权链接，复制验证码并在浏览器中授权，后台自动轮询，授权成功后自动关闭弹窗。
- **仓库自动加载（公开 + 私有）** — 登录后仓库选择器自动加载该登录用户的所有仓库（包含 owner 与 collaborator、公开与私有），可直接点选，无需手动输入 `owner/repo`。
- **插件设置可编辑（齿轮图标）** — 支持设置的插件（如 GitHub Sync）在插件卡片**左下角显示齿轮**，点击齿轮或卡片主体即可打开该插件的设置页进行修改。

### Changed
- GitHub 的 Token / 仓库 / Client ID 等配置从「设置」页迁移到 GitHub Sync 插件的设置页内进行，设置页「GitHub 同步」区块已移除。
- `AppSettings` 新增 `githubClientId`、`githubUsername` 字段；`FreeNotePlugin` 新增 `hasSettings` 与 `buildSettings(host)` 钩子，`PluginInfo` 同步携带 `hasSettings`。

### Notes
- Device 登录需要一个 GitHub OAuth App 的 **Client ID**（设置页内可填写，首次使用请自行创建 OAuth App；回调地址任意即可）。未填写 Client ID 时登录会提示先填写。

## 1.9.1

### Fixed
- **修复预览模式空白/崩溃** — v1.9.0 的 LaTeX 渲染因缺少 KaTeX 字体资源导致预览模式完全空白（`Math.tex` 静默失败）。现已在 `pubspec.yaml` 中显式声明全部 KaTeX 字体（20 个 `.ttf` 文件，复制到 `lib/katex_fonts/fonts/`），并给 `MathBuilder` 的 `Math.tex` 调用加了 try-catch 保护——即使字体加载或公式解析异常，也只显示红色原文而非整页崩溃。同时封装了 `safeMarkdown` 统一入口，编辑器预览与 AI 对话共用同一套 LaTeX + 容错逻辑。

## 1.9.0

### New Features
- **LaTeX 数学公式支持** — 笔记预览与 AI 对话现在可渲染 LaTeX：行内公式用 `$...$`，独立公式（居中、独占一行）用 `$$...$$`。渲染基于 `flutter_math_fork`（KaTeX 风格），解析失败的公式会以红色原文显示而不崩溃。
- **独立公式插入页** — 编辑器工具栏新增「公式」按钮（ƒ 图标），点击切换到独立的公式编辑页：上方实时预览渲染效果，中间可手输 LaTeX 源码，底部为**分类的 LaTeX 符号工具栏**（常用 / 希腊字母 / 运算 / 关系 / 括号 / 箭头 / 修饰），点击符号即插入到光标处（空 `{}` 自动定位光标到参数内）。右上角可切换「独立 / 行内」，勾选后把整段公式（自动用 `$` 或 `$$` 包裹）插回编辑器当前光标。

### Changed
- 编辑器预览由 `flutter_html` 切换为 `flutter_markdown`，以原生支持 LaTeX 数学扩展（标准 Markdown / GFM 渲染保持不变，链接点击行为保留）。

## 1.8.3

### Fixed
- **首页文件夹分组现在显示所有文件夹（含空文件夹）** — 之前分组只列出「含有笔记」的文件夹，因此刚用「新建文件夹」建好的空文件夹不会出现在首页，看起来像文件夹功能失效。现改为扫描笔记目录的真实目录树，把**所有**非点文件夹（`.config` 等含点的仍隐藏）都列出来；空文件夹展开后显示「此文件夹暂无笔记」。新建文件夹、切换笔记目录后会自动刷新该列表。

## 1.8.2

### Changed
- **首页笔记按文件夹分组** — 笔记列表不再平铺，改为按顶层文件夹分组：顶层笔记直接显示，位于子文件夹的笔记归入可展开的文件夹分组（文件夹默认折叠，点击展开）。名称含点（`.`）的文件夹（如 `.config` 元数据目录）及其中的文件会被整体隐藏，不出现在首页。

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
