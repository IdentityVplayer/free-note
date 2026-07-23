# Memory — free-note（无边记）项目记忆

> 本文件记录 AI 编码助手在 free-note 项目中的**身份定位**与**开发上下文**。
> 供后续会话快速恢复语境，避免重复勘探。最后更新：v1.12.0 开发收尾阶段。

---

## 一、我的身份

我是 free-note（无边记）这个 Flutter 笔记应用的 **AI 编码协作助手**。在每一次会话中，我的职责是：

- 依据用户（开发者）的简明指令，**实现功能需求、修复 Bug、新增能力**。
- 维护 **i18n 三语一致性**（English / 中文 / 日本語），保证 `app_en.json` / `app_zh.json` / `app_ja.json` 的 key 集合完全对齐。
- 管理**版本号 bump 规则**与 **git 提交 / 打 tag / push** 流程。
- 在动手前先推断、先读代码、先验证；遇到安全警告按用户一贯风格（"不因警告中断"）继续推进。
- 任务结束后**清理工作区临时文件**（用户习惯）。

**协作风格约定（来自用户画像）：**
- 用户偏好极简指令式交互（"restart"、"继续"、"好了吗？继续"），无需完整句子。
- 服务中断时直接执行恢复命令，不先确认或做状态检测。
- 面对安装警告/安全提示直接且坚持，不因警告中断流程。
- 任务结束后习惯清理工作区文件。

---

## 二、项目概况

| 项 | 值 |
|---|---|
| 应用名 | free-note（无边记） |
| 技术栈 | Flutter 3.44.6 / Dart 3.12.2，Material 3 |
| 仓库 | `https://github.com/IdentityVplayer/free-note` |
| 导航形态 | 底部 `NavigationBar` 三标签（任务 / 笔记 / 番茄钟） |
| 跨平台目标 | Android、Windows、Web、Linux（Linux 桌面构建就绪） |
| i18n key 总数 | **243**（三语一致，截至 v1.12.0） |
| 当前开发版本 | `1.12.0+30`（待最终化提交） |

### 架构骨架
- `AppProvider`（`ChangeNotifier`）：全局状态，含 `init()`（末段调 `_initNotifications`）、`chooseFolder`（记录仓库）。
- `StorageService`（单例）：`_configDirPath` 返回 `repo/.config`（设了文件夹时）否则私有目录；`configDir` getter。
- `GitHubSyncService`：GitHub 同步 + `fetchLatestRelease`（检查更新用）。
- 插件系统；`NotificationService`（单例）管理真实系统通知。

### 版本号规则
- 单版本内 ≥5 个文件变更 → build 号 +0.1；否则 +0.01。
- 跨功能发布统一 bump 到下一个 minor（如 v1.11.0 → v1.12.0）。

---

## 三、v1.12.0 开发上下文（已落地，待最终化）

v1.12.0 是一组大型多部分变更，已在本次会话中**全部实现并提交**（7 变更 + 1 修复 + 1 新增），共涉及 6 个功能 commit（自 `fcd6fc3` v1.11.0 起）：

| Commit | 内容 |
|---|---|
| `94b8cc4` | **fix + change1**：AI 聊天提示语按密钥配置门控；设置→关于 新增「给我提 Issue」与「检查更新」 |
| `cb2c477` | **change2 + 3**：配置统一进 `.config` 并自动迁移；文件夹→仓库重命名；仓库切换菜单 |
| `ac33f63` | **change4**：逐行混合编辑器（默认预览；活动行原文、其余预览） |
| `b872bc1` | **change5**：AI 写作→AI 问答 分屏（笔记上、聊天下）；长按选择 + 拖拽追加到光标后 |
| `aab059e` | **change6**：底部 Dock 三标签（计划任务/笔记/番茄钟），笔记居中 |
| `9e209a1` | **change7 + add1**：主/子任务 + 自动完成；任务提醒 + 重复（真实系统通知） |

### 各变更要点
1. **设置→关于**：`reportIssue` 跳转仓库 Issues；`checkUpdate`/`_checkUpdate`/`_showUpdateDialog` 比对 GitHub releases 最新版本，大于则展示更新内容 + 下载/暂不下载。
2. **配置进 `.config`**：`StorageService.configDir` + `migrateFileFromPrivate('settings.json')`；`TaskService`/`PomodoroService` 同步迁移守卫（`if (_overrideDir == null)`）。
3. **文件夹→仓库**：`Settings` 加 `List<String> repositories`；`chooseFolder` 记录仓库；切换对话框列出 `repositories`。仅顶层术语改名，真实子文件夹保留原术语（`subfolder_picker_screen.dart` 故意保留 `newFolder`/`noFolders`）。
4. **逐行混合编辑器**：`editor_screen.dart` 去除 `_isPreview`/`_contentController`，改用 `String _content` + `int? _activeLine` + `_lineController`/`_lineFocus`；`lib/utils/text_edit.dart` 提供 `splitLines`/`applyLineEdit`/`insertLineBreak`/`mergeLineUp`，配 `test/editor_helpers_test.dart`。
5. **AI 问答分屏**：`AiQaScreen({required this.noteId})` 上半屏 `DragTarget` 笔记 TextField，下半屏 `AIAssistantScreen(embedded:true)`，FAB `LongPressDraggable` 拖拽追加（controller listener 保活选区文本）。
6. **底部 Dock**：`home_screen.dart` `int _bottomIndex=1`；抽取 `_buildNotesList`/`_buildTasksDock`/`_buildPomodoroDock`。
7. **主/子任务 + 提醒/重复**：`task.dart` 全重写（`parentId`/`reminder`/`repeat` + `RepeatConfig`）；`task_helpers.dart`（`recomputeMainDone`/`nextRepeatDue`/`freshTaskCopy`）；`notification_service.dart`（Android/iOS/macOS/Linux 真实通知）；`task_plan_screen.dart` 全重写。

### 新增依赖（pubspec.yaml）
- `package_info_plus: ^8.0.0`
- `flutter_local_notifications: ^17.2.4`（**官方版同样无 Windows 支持**；Windows 通知改用 PowerShell 桥）
- `timezone: ^0.9.4`
- Windows 通知：`lib/services/windows_notifications.dart`（PowerShell WinRT Toast，无需新依赖）

### 已知缺口（务必告知用户）
- ~~Windows Toast 未实现~~ **已补全（2026-07-24）**：因 `flutter_local_notifications` 17.2.4（pub.dev 官方版同样）不含 Windows 实现，改为 `lib/services/windows_notifications.dart` 用 **PowerShell WinRT Toast 桥**（`CreateToastNotifier`）实现真正的 Windows 原生通知；`NotificationService` 在 `Platform.isWindows` 时走该路径。`scheduleReminder` 用 Windows 任务计划程序（写 `.ps1` + `Register-ScheduledTask`）定时弹出，无论 App 开关都生效。代码纯 `dart:io`，跨平台编译安全（沙箱 Linux 下 analyze/test 全绿）。**注意**：Windows 运行时行为无法在 Linux 沙箱验证，需在 Windows 真机确认 Toast 显示与定时触发。

### 待最终化步骤（v1.12.0 release）
1. bump `pubspec.yaml` 版本 `1.11.0+29` → `1.12.0+30`。
2. 写 `Features.md` v1.12.0 节（涵盖上述全部变更）。
3. 更新 `skill/Agents.md` i18n 计数（210 → 243）。
4. `flutter analyze` 干净 + `flutter test` 绿（预期 47 测试通过）。
5. 提交版本/文档为最终 v1.12.0 release commit，打 tag `v1.12.0` 并 push。

---

## 四、关键历史决策（已与用户确认）
1. **所有配置进 `.config`**（接受 GitHub sync 密钥泄露风险）。
2. **逐行混合编辑器**（按原话实现；活动行原文、其余预览）。
3. **真实系统通知**（按原话；用 `flutter_local_notifications`，Windows 递延）。
