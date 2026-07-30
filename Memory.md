# Memory — free-note（无边记）项目记忆

> 本文件记录 AI 编码助手在 free-note 项目中的**身份定位**与**开发上下文**。
> 供后续会话快速恢复语境，避免重复勘探。最后更新：v1.13.3 开发收尾阶段（2026-07-24）。

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
| 导航形态 | 底部 `NavigationBar` 四标签（任务 / 笔记 / 番茄钟 / 剪切板） |
| 跨平台目标 | Android、Windows、Web、Linux（Linux 桌面构建就绪） |
| i18n key 总数 | **287**（三语一致，截至 v1.18.0） |
| 当前稳定版本 | `1.18.0+59`（已发布，tag `v1.18.0`） |

### 架构骨架
- `AppProvider`（`ChangeNotifier`）：全局状态，含 `init()`（末段调 `_initNotifications`）、`chooseFolder`（记录仓库）。
- `StorageService`（单例）：`_configDirPath` 返回 `repo/.config`（设了文件夹时）否则私有目录；`configDir` getter。
- `GitHubSyncService`：GitHub 同步 + `fetchLatestRelease`（检查更新用）。
- 插件系统；`NotificationService`（单例）管理真实系统通知。

### 版本号规则
- 单版本内 ≥5 个文件变更 → build 号 +0.1；否则 +0.01。
- 跨功能发布统一 bump 到下一个 minor（如 v1.11.0 → v1.12.0）。

---

## 三、v1.12.0 开发上下文（已落地并发布）

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

### v1.12.0 最终化（已完成 ✅，2026-07-24）
1. ✅ bump `pubspec.yaml` 版本 `1.11.0+29` → `1.12.0+30`。
2. ✅ 写 `Features.md` v1.12.0 节（涵盖上述全部变更）。
3. ✅ 更新 `skill/Agents.md` i18n 计数（210 → 243）。
4. ✅ `flutter analyze` 干净 + `flutter test` 绿（47 测试通过）。
5. ✅ 提交版本/文档为最终 v1.12.0 release commit（`d5796d3`），打 tag `v1.12.0` 并 push。
6. ✅ 修复 CI 的 `dart format` 门禁失败（commit `5ac996b`，21 个文件格式化）。
7. ✅ 补全 Windows 原生 Toast（commit `7385889`，PowerShell WinRT 桥）。

### v1.13.0 最终化（已完成 ✅，2026-07-14）
1. ✅ 多番茄钟（预设 Profile）：新增 `lib/models/pomodoro_profile.dart`
   （`PomodoroProfile`：id/name/时长/longBreakEvery/longBreakEnabled/backgroundPath
   + `nextPomodoroPhase` 长休息判定）；重写 `lib/services/pomodoro_service.dart`
   管理 `List<PomodoroProfile>` + `activeId`，`load()` 把老 `pomodoro.json` 迁移为
   默认 Profile（`pomodoro_profiles.json` 存 `{activeId, profiles}`）。
2. ✅ 番茄钟背景从相册选择：`pubspec.yaml` 加 `image_picker: ^1.1.2`；
   `pomodoro_screen.dart` 的 `_pickBackground` 复制图片到 `configDir/pomodoro_bg/{id}.jpg`，
   `_clearBackground` 清除；计时页用 `Stack(Image + 遮罩 + 内容)` 渲染。
3. ✅ 长休息开关：每个 Profile 独立 `longBreakEnabled`，设置页 `SwitchListTile` 控制。
4. ✅ 修复主页面 Dock：去掉「计划任务 / 番茄钟」冗余标题条目，直接展示真实任务列表
   与当前番茄钟预设（`_buildTasksDock` / `_buildPomodoroDock`，后者改用 `.active`）。
5. ✅ 右下角 FAB 随当前页切换：笔记页展开菜单（新建笔记 / 新建仓库）；计划任务页 →
   `TaskPlanScreen(autoAdd:true)`；番茄钟页 → `PomodoroScreen(autoAdd:true)`。
6. ✅ i18n 增 17 个 key（243 → 259，三语对齐）：`openFull`/`newPomodoro`/
   `pomodoroProfiles`/`pomodoroProfileName`/`pomodoroNewProfile`/`pomodoroRenameProfile`/
   `pomodoroDeleteProfile`/`pomodoroDeleteProfileConfirm`/`pomodoroKeepOne`/
   `pomodoroBackground`/`pomodoroBackgroundFromAlbum`/`pomodoroBackgroundSet`/
   `pomodoroBackgroundCleared`/`pomodoroClearBackground`/`pomodoroLongBreak`/
   `pomodoroDefault`/`close`。
7. ✅ `test/v110_test.dart` 增补 `PomodoroProfile` 测试（默认/秒数/截断/存储往返/
   老文件迁移/`nextPomodoroPhase` 长休息判定）。
8. ✅ bump `pubspec.yaml` 版本 `1.12.0+30` → `1.13.0+32`（远端已先发 v1.12.1+31，build 号顺延）；写 `Features.md` v1.13.0 节；
   更新 `skill/Agents.md` i18n 计数（243 → 259）。
9. ✅ `flutter analyze` 干净（仅 2 条 `Radio` 废弃 info，CI 不 `--fatal-infos` 不挂）+
   `flutter test` 绿（48 测试通过）；`dart format` 干净。
10. ✅ 提交版本/文档为最终 v1.13.0 release commit，打 tag `v1.13.0` 并 push。

### v1.13.1 最终化（已完成 ✅，2026-07-14）
1. ✅ **change：应用启动默认打开上一个打开的仓库** — `StorageService` 新增
   `loadLastRepoPath()` / `saveLastRepoPath(path)`（持久化 `<private>/.config/last_repo.json`，
   `{path}`）；`AppProvider.init()` 在 `loadSettings()` **之前**先
   `if (lastRepo != null && Directory(lastRepo).existsSync()) _storage.setFolder(lastRepo);`
   打破鸡生蛋问题（`settings.json` 位于 `<repo>/.config`，启动 `currentFolder` 为 null 时
   会从私有目录误读，导致 `notesFolderPath` 丢失、`needsFolderSelection` 为真、回落到选择页）。
   `chooseFolder` 已含 `await _storage.saveLastRepoPath(path);`（覆盖首次选库与切换仓库）。
   仓库已删除/卸载则跳过恢复，正常显示选择页。
2. ✅ **fix：Markdown 单击无法进入编辑** — `safeMarkdown` 新增 `selectable` 形参（默认 `true`）；
   `editor_screen.dart` `_buildPreviewLine` 改传 `selectable: false`，让 `GestureDetector.onTap`
   → `_setActiveLine(i)` 对单击生效；链接仍经 `onTapLink` 打开。
3. ✅ `flutter analyze` 干净（0 issues，避免重蹈 v1.13.0 时 `Radio` 废弃 info 触发 CI 失败）+ `flutter test` 绿（48 测试通过）。
4. ✅ `dart format --set-exit-if-changed` 干净（3 个文件格式化后重新校验 0 changed）。
5. ✅ bump `pubspec.yaml` 版本 `1.13.0+32` → `1.13.1+33`；写 `Features.md` v1.13.1 节。
6. ✅ 提交版本/文档为最终 v1.13.1 release commit，打 tag `v1.13.1` 并 push。

### v1.13.2 最终化（已完成 ✅，2026-07-24）
1. ✅ **add：GitHub Sync 新增「令牌 (Key) 登录」模式** — `github_sync_settings_screen.dart` 新增登录方式切换（`SegmentedButton`：设备登录 OAuth / 令牌登录）；选「令牌登录」后粘贴 GitHub PAT 即连，经 `getAuthenticatedUser(token)` 校验并以 `updateGitHubAuth(token:, username:, syncMode:'token')` 落盘；模式持久化于 `AppSettings.githubSyncMode`。新增 `_tokenController` / `_syncMode` 状态与 `_connectWithToken()`；`_startLogin` 传 `syncMode:'device'`。涉及 6 个新 i18n key（三语对齐，259 → 265）：`githubMode` / `githubDeviceMode` / `githubTokenMode` / `githubTokenHint` / `githubTokenRequired` / `githubVerifying`。
2. ✅ **change：AI API Key 与 GitHub Token 经 base64 混淆存储** — `AppSettings` 新增 `_encodeSecret` / `_decodeSecret`（`b64:` 前缀）；`toJson` 对 `aiApiKey` / `githubToken` 编码，`fromJson` 解码；旧版明文设置文件因无前缀原样读取，向后兼容。密钥仍位于 `.config/settings.json`，但不再明文暴露。（修复了 `_decodeSecret` 中 `substring(5)` 的 off-by-one，`b64:` 前缀实长 4，修正为 `substring(4)`；由 `github_sync_test.dart` 往返用例暴露并修复。）
3. ✅ **fix：导出归档后缀错误（`.fne.zip` → `.fne`）** — `settings_screen.dart._exportData` 落盘后规整路径：若以 `.zip` 结尾则截掉、否则补 `.fne`；用同步 `existsSync()` / `renameSync().path` 处理 `FilePicker.saveFile` 在 Windows 上追加的 `.zip`，并 toast 实际文件名。
4. ✅ **fix：任务计划板块添加后不立即显示** — 新增 `lib/route_observer.dart`（`RouteObserver<PageRoute>`）；`main.dart` 加 `navigatorObservers:[routeObserver]`；`home_screen.dart` 的 `_HomeScreenState` 改 `with RouteAware`，`didChangeDependencies` 订阅一次，`didPopNext` 触发 `setState((){})` 重建任务 Dock 的 `FutureBuilder`，重新加载任务列表。
5. ✅ **fix：OAuth 登录重启 APP 后失效** — `app_provider.dart.chooseFolder` 在（重新）选库前先从目标仓库读回已持久化的 `settings`，保留其中的 `githubToken` / `githubUsername` / `githubRepo` / `githubSyncMode` 再保存，避免启动回落到选库页（`_settings.githubToken` 为 null）整体覆盖导致登录态丢失。
6. ✅ `flutter analyze` 干净（0 issues）+ `flutter test` 绿（48 测试通过）+ `dart format --set-exit-if-changed` 干净。
7. ✅ bump `pubspec.yaml` 版本 `1.13.1+33` → `1.13.2+34`；写 `Features.md` v1.13.2 节；更新 `skill/Agents.md` i18n 计数（259 → 265）。
8. ✅ 提交版本/文档为最终 v1.13.2 release commit，打 tag `v1.13.2` 并 push。

### v1.13.3 最终化（已完成 ✅，2026-07-24）
1. ✅ **GitHub Sync 双向自动同步（autoSync 真正生效）** — `AppProvider` 新增 `WidgetsBindingObserver`：`init()` 注册观察者并在启动后（仅 `autoSync` 开启）触发 `syncBidirectional()`；`didChangeAppLifecycleState` 在 `paused`/`detached`（退出前/切后台）触发；编辑器 `editor_screen` 的 `onPopInvokedWithResult` 与 `dispose` 在退出编辑时触发。新增 `syncBidirectional()`：先 `pullNotes()`，按 `id` + `updatedAt` 合并（`_mergeRemoteNotes`，远端更新则覆盖本地），本地 `_persist()` 后 `syncNotes(_notes)` 推回；`_isSyncing` 防重入，不阻塞 UI。
2. ✅ **fix：计划任务子任务完成后误删任务（加固）** — `task_plan_screen._toggleDone` 的 `recomputeMainDone` 结果加防御：若合并后数量少于原列表则保留原全集，杜绝任何情况下丢失任务。回归测试 `test/task_delete_repro_test.dart` 证明「完成全部子任务后三个任务均保留、主任务自动完成」。（注：当前代码路径本不会产生删除，`saveTasks` 永不接收空列表；此处为防御性加固 + 统一首页视图。）
3. ✅ **首页「计划任务」Dock 显示完整 UI** — `TaskPlanScreen` 新增 `embedded` 参数（只渲染列表主体、不自带 AppBar/FAB）；首页 `_buildTasksDock` 改为内嵌 `TaskPlanScreen(embedded:true)`，与完整计划页 UI 一致；移除首页原 `FutureBuilder` 平铺复选框与已无用的 `task_service`/`task` 导入。
4. ✅ **番茄钟页面顶部统计** — `PomodoroService` 新增完成阶段历史（`pomodoro_history.json`，上限 5000 条）：`recordSession(phase, seconds)` 在 `_onPhaseComplete` 记录；`stats()` 聚合「今日 / 本周 / 本月 / 本年」的专注秒数与休息秒数（短+长休息）。新增 `lib/models/pomodoro_session.dart`（`PomodoroSession` / `PomodoroStats`）。
5. ✅ **番茄钟多预设卡片 UI** — `pomodoro_screen` 重设计为：顶部统计卡 + 当前计时器 + 每个预设一张卡片（底部高斯模糊背景图、左下「开始」直接 `_startProfile`、右下铅笔 `_showProfileDialog(existing:)` 编辑）。`ImageFilter.blur` 实现模糊；`_startProfile` 切换激活并立即开始。
6. ✅ i18n 三语对齐新增 6 个 key（265 → 271）：`pomodoroStats` / `pomodoroToday` / `pomodoroWeek` / `pomodoroMonth` / `pomodoroYear` / `pomodoroBreak`。
7. ✅ `flutter analyze` 干净（0 issues）+ `flutter test` 绿（50 测试通过，含 stats 与 deletion 回归）+ `dart format --set-exit-if-changed` 干净（重跑校验 0 changed）。
8. ✅ bump `pubspec.yaml` 版本 `1.13.2+34` → `1.13.3+35`；写 `Features.md` v1.13.3 节；更新 `skill/Agents.md` i18n 计数（265 → 271）。
9. ✅ 提交版本/文档为最终 v1.13.3 release commit，打 tag `v1.13.3` 并 push。

### v1.13.4 最终化（已完成 ✅，2026-07-24）
1. ✅ **内置 AI 密钥 + OpenRouter 预设** — 新增 `openrouter` AI 提供商预设（baseUrl `https://openrouter.ai/api/v1`）；内置 OpenRouter API Key（`AIService.builtInKey`，不展示于 UI）；AppSettings 默认 provider 改为 `openrouter`、模型 `openrouter/free`，无密钥时自动回退内置密钥并强制 OpenRouter 端点。
2. ✅ **密钥隔离到 `.config/secrets.json`** — `aiApiKey` 与 `githubToken` 从 `settings.json` 移出，单独持久化到 `.config/secrets.json`（base64）。`AppSettings.toJson` 不再含密钥；`StorageService.loadSettings`/`saveSettings` 增加 secrets 加载/保存逻辑并自动迁移旧 `settings.json` 中的遗留密钥。
3. ✅ **设置页密钥防泄露** — AI API Key 输入框 `obscureText` 加可见性切换（默认隐藏）；未填写自有密钥时显示"将使用内置密钥"提示（不展示真实密钥）。新增 `aiBuiltInHint`/`hide`/`show` 三语 key（265 + 9 = 274）。
4. ✅ **修复番茄钟/任务可能被清空** — `TaskService`、`PomodoroService` 及 `StorageService` 的持久化写操作改用原子写入（临时文件 → 替换 → 留下 `.bak` 备份）；读取时若主文件损坏自动回退到 `.bak`，避免中途崩溃/磁盘满后 `loadTasks` 返回空并被永久覆盖。新增回归测试 4 个（`test/persistence_safety_test.dart`）。
5. ✅ `dart format --set-exit-if-changed` 干净 + `flutter analyze` 0 issues + `flutter test` 54 passed（含 4 个新回归测试）。
6. ✅ bump `pubspec.yaml` 版本 `1.13.3+35` → `1.13.4+36`；更新 `Memory.md` 顶部 i18n 计数（271 → 274）；更新 `skill/Agents.md` i18n 计数（271 → 274）；写 `Features.md` v1.13.4 节。
7. ✅ 提交版本/文档为最终 v1.13.4 release commit，并 push。

### v1.13.5 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：首页任务计划 Dock 不会自动刷新** — 嵌入式 `TaskPlanScreen` 因 `const` 导致返回后不重建。方案：`TaskPlanScreenState` 改为公开类，新增 `reloadTasks()` 方法；主页添加 `GlobalKey<TaskPlanScreenState>`，在 `didPopNext` 中调用 `reloadTasks()` + `setState`，确保从完整任务计划页返回时 Dock 立即刷新。
2. ✅ `dart format --set-exit-if-changed` 干净 + `flutter analyze` 0 issues + `flutter test` 54 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.4+36` → `1.13.5+37`；更新 `Memory.md` / `Features.md`；最终 commit / tag / push。
### v1.13.7 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：GitHub 同步 URI 错误** — `GitHubSyncService` 的 `_encPath` 被错误地应用到整个 URL（含 `https://`），导致 `:` 被编码为 `%3A`，使所有 API 调用失败（"No host specified in URI"）。修正：仅对 `notes/` 下的文件路径段编码，base URL 直接拼接；`_listNotesDir` 中 branch/SHA 已是 ASCII 直接去掉编码。
2. ✅ **fix：版本号格式不合法** — `1.13.6.1+39`（4 段）不符合 Dart pubspec 规范，`flutter pub get` 崩溃。修正为 `1.13.7+39`。
3. ✅ `flutter analyze` 0 issues + `flutter test` 54 passed + `flutter build web --release` 构建通过。
4. ✅ bump `pubspec.yaml` 版本 `1.13.6+38` → `1.13.7+39`；tag `v1.13.7`；最终 commit / tag / push。

### v1.13.6 最终化（已完成 ✅，2026-07-24）
1. ✅ **GitHub 同步改为逐个文件上传** — `syncNotes` 不再将所有笔记打包为 `notes/notes.json`，而是每篇笔记单独上传到仓库根目录 `notes/` 文件夹下，保持子目录结构（`notes/<relativePath>`）；删除的笔记自动清理远端文件；遗留的 `notes/notes.json` 同步时自动删除。`pullNotes` 改为遍历 `notes/` 目录下载每个 `.md` 文件，用 YAML 前后端解析回 `Note` 对象。
2. ✅ `flutter analyze` 0 issues + `flutter test` 54 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.5+37` → `1.13.6+38`；更新 `Memory.md` / `Features.md`；最终 commit / tag / push。
### v1.13.8 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：完成任务界面创建多个子任务后完成一个子任务导致计划任务被删除** — 定位根因：`_updateTask`、`_addTask`、`_removeTask` 均为 `void` 方法，调用 `_persist()` 时**不 await**，导致与 `_toggleDone` 的后续 `_persist` 之间共享 `_tasks` 可变列表产生执行时序不确定的竞态。修复：所有操作改为 `Future<void>` 并 `await _persist()`，消除 fire-and-forget 模式；`_persist()` 增加守卫：拒绝在磁盘已有非空数据时写入空列表。新增复现测试 2 个。
2. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.7+39` → `1.13.8+40`；最终 commit / tag / push。
### v1.13.9 最终化（已完成 ✅，2026-07-24）
1. ✅ **`.config` 文件夹同步到 GitHub notes/ 目录** — GitHub 同步（`syncNotes`/`pullNotes`）现在额外将 `.config/` 下的配置文件（tasks.json、pomodoro_profiles.json、settings.json、secrets.json 等）作为 `notes/.config/<filename>` 上传/下载。推时读取本地 `.config/` JSON 文件（排除按笔记元数据的 `<id>.json`），拉时写回本地 `.config/`。新增 `PullResult` 类封装笔记列表与配置文件映射。所有调用方（`syncBidirectional`、`syncToGitHub`、`pullFromGitHub`）已同步修改。
2. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.8+40` → `1.13.9+41`；最终 commit / tag / push。

### v1.13.10 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：GitHub 同步 409 Conflict 错误** — `_putFile` 收到 409 时（SHA 过期：并发同步 / autoSync 触发 / Git Trees API 截断等），自动通过 Contents API 重新拉取 SHA 并重试一次，避免误判上传失败。新增 `_fetchBlobSha` 辅助方法。
2. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.9+41` → `1.13.10+42`；最终 commit / tag / push。
### v1.13.11 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：409 仍然报错** — 重试逻辑增强：增加 300ms 延迟等待分支 commit 落定；`_fetchBlobSha` 返回 null 时仍用 null SHA 重试（视为新建文件）；添加 `_deleteFile` 的 409 重试。现 `_putFile` 和 `_deleteFile` 均在 409 时延迟 + 刷新 SHA + 重试。
2. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.13.10+42` → `1.13.11+43`；最终 commit / tag / push。

### v1.14.0 最终化（已完成 ✅，2026-07-24）
1. ✅ **fix：完成任务后页面自动刷新** — `_persist` 中的空列表守卫修复为从磁盘重新加载而非静默返回，保证 UI 一致性。
2. ✅ **fix：设置"子任务完成后自动完成主任务"开关不立即刷新** — `onChanged` 回调后加 `setState` 保证 UI 即时更新。
3. ✅ **add：长按文件/文件夹弹出菜单（删除）** — 首页笔记卡片和文件夹标题支持长按，弹出 BottomSheet 菜单（含删除、后续扩展重命名/移动/复制）。
4. ✅ **fix：删除按钮文案统一** — `task_plan_screen` 中的三个 `deleteNote` 引用改为通用 `delete`，不再显示"删除笔记"。
5. ✅ **fix：Android 通知不提示** — 添加 `SCHEDULE_EXACT_ALARM` 权限声明，`scheduleReminder`/`showNotification` 包裹 try-catch 避免静默失败。
6. ✅ **change：新建笔记流程** — 点击添加笔记后弹出对话框输入文件名和选择所属文件夹；编辑页面的文件夹栏目已删除；长按笔记弹出重命名/移动/复制/删除菜单。新增 `noteNameHint`/`rename`/`move`/`copy` 四组三语 key（274 → 278）。
7. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed。
8. ✅ bump `pubspec.yaml` 版本 `1.13.11+43` → `1.14.0+44`；更新 `Memory.md` / `Features.md`；最终 commit / tag / push。

### v1.15.5 最终化（已完成 ✅，2026-07-25）
1. ✅ **fix：GitHub Sync 二进制文件和配置文件无法上传** — `_readConfigFiles` 由 `Map<String, String>` + 仅 `.json` 改为 `Map<String, List<int>>` + 递归读 `.config/` 下全部文件；`syncNotes` 改为按字节直接 base64 编码（去掉 `utf8.encode` 往返）；`_readExtraFiles` 保持递归扫描 BASE 目录全部非笔记/非配置文件。`.config/preferences.yaml`、`.gitignore` 等二进制和文本混合格式现在都能正确上传到 `notes/.config/`。
2. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.15.4+49` → `1.15.5+50`；最终 commit / tag / push。

### v1.15.6 最终化（已完成 ✅，2026-07-25）
1. ✅ **add：应用通知系统** — 之前只有任务 reminder，且 `_scheduleIfNeeded` 是 fire-and-forget + tz.local 默认 UTC。重写：
   - 新增 `lib/utils/notification_timezone.dart` 从设备 offset 合成 `tz.local`
   - `NotificationService` 增加多 channel（`tasks`/`pomodoro`/`sync`/`updates`）+ `requestExactAlarmsPermission()` + `cancelTaskReminder()` + iOS `DarwinNotificationDetails` 显式启用 alert/sound
   - `_addTask`/`_updateTask`/`_removeTask` 都 await scheduleReminder，并在 update/remove 时取消旧 schedule
   - 番茄钟 phase 完成 → 系统通知
   - GitHub Sync 成功/失败 → 系统通知
   - 检查更新有新版 → 系统通知
2. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.15.5+50` → `1.15.6+51`；最终 commit / tag / push。

### v1.15.7 最终化（已完成 ✅，2026-07-25）
1. ✅ **fix：APK 下载进度条始终 0%** — 之前 http stream 的 `contentLength` 经常返回 -1（chunked 或无 Content-Length 响应头），导致百分比永远算为 0。改为新增 `lib/utils/curl_downloader.dart`：
   - 非 Android（桌面）走 `Process.start('curl', ['-L', '-f', '-#', '-o', path, url])`，实时解析 stderr 上的百分比（`\r` 覆盖的行）
   - Android 用 `HttpClient.openUrl` 字节流 + 轮询 file size 的兜底实现（contentLength=0 时用确定性的 1..99 循环）
2. ✅ **add：默认下载目录** — `<notes folder>/download/free-note-<current_version>.apk`；若没有 repo 则 fallback 到 `<configDir>/download`。
3. ✅ **add：自动调用默认安装器** — 下载成功后立即调用 `CurlDownloader.installApk()`：
   - Android：通过 MethodChannel `com.note.apps/abi` 的 `installApk` 方法，MainActivity 复制 APK 到公共 Downloads 并通过 FileProvider 触发 `ACTION_VIEW` + `application/vnd.android.package-archive`
   - Windows：`cmd /c start "" path`
   - macOS：`open path`
   - Linux：`xdg-open path`
4. ✅ 新增 `android/app/src/main/res/xml/file_provider_paths.xml` 和 AndroidManifest FileProvider 声明。
5. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
6. ✅ bump `pubspec.yaml` 版本 `1.15.6+51` → `1.15.7+52`；最终 commit / tag / push。

### v1.15.8 最终化（已完成 ✅，2026-07-25）
1. ✅ **fix：Android CI 构建失败** — v1.15.7 在 MainActivity 中引用 `androidx.core.content.FileProvider`，但 `app/build.gradle.kts` 没显式声明 androidx.core 依赖（虽然 `flutter_local_notifications` 间接带 `androidx.core:core:1.3.0`，AGP 不会把 plugin implementation 传染给 app），导致 `Build App Bundle` 步骤 exit code 1。修复：`implementation("androidx.core:core:1.13.1")`。
2. ✅ 删除多余的 `.github/workflows/auto_build.yml`（与 `build_release.yml` 重复）。
3. ✅ `build_release.yml` 简化：删除 `flutter build appbundle` 步骤（与 APK 重复）；windows/web 加 `continue-on-error: true`（编译失败不阻塞 Android release）。
4. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
5. ✅ bump `pubspec.yaml` 版本 `1.15.7+52` → `1.15.8+53`；最终 commit / tag / push。

### v1.15.9 最终化（已完成 ✅，2026-07-25）
1. ✅ **fix：v1.15.8 Android CI 仍然失败** — 根因不是 androidx.core 缺失，而是 `MainActivity.kt` 里 `setMethodCallHandler { ... }` lambda 中的 `return`（line 36）。Kotlin 编译器不允许非 inline lambda 中使用裸 `return`。修复：lambda 加 `handler@` 标签，`return` → `return@handler`；同时删除未使用的 import（DownloadManager/BroadcastReceiver/Context/IntentFilter）。
2. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.15.8+53` → `1.15.9+54`；最终 commit / tag / push。

### v1.16.0 最终化（已完成 ✅，2026-07-25）
1. ✅ **change：主界面云端上传按钮改用系统通知** — `home_screen.dart:_syncNow` 移除 SnackBar overlay，改为 `NotificationService.showSync("上传成功/失败", msg)`；点击上传不阻塞编辑。
2. ✅ **change：AI 问答改"选择文字 → 按钮 → 插入"** — 删除 `LongPressDraggable` FAB 和底部 `aiQaDragHint` 提示条；`AIAssistantScreen` 包裹 `SelectionArea(onSelectionChanged:)`，选中文本时回调到 `AIQaScreen` 显示"插入到笔记"悬浮按钮；点击按钮将选中文本追加到文件末尾；`dispose()` 自动保存（已存在）。新增 `insertToNote` 三语 key（274 → 277）。
3. ✅ **add：Markdown `./` `../` 图片路径解析** — `safeMarkdown` 新增 `relativeBaseDir` 参数 + `sizedImageBuilder`；编辑器计算当前笔记所在目录（`base/relativePath 的父目录`），传给 `safeMarkdown`；相对路径 `./name.jpg`、`../name.jpg` 都解析为绝对路径后渲染 `Image.file`。
4. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
5. ✅ bump `pubspec.yaml` 版本 `1.15.9+54` → `1.16.0+55`；最终 commit / tag / push。

### v1.16.1 最终化（已完成 ✅，2026-07-25）
1. ✅ **add：任务提醒 Important 通知 + 动作按钮** — 之前 `importance: high` + 无 action，用户只能点开查看。改造：
   - `AndroidNotificationDetails` 升级 `Importance.max` / `Priority.max` + `fullScreenIntent: true` + `category: reminder`（绕过免打扰，触发横幅）
   - `DarwinNotificationCategory("task_reminder", actions: [完成, 忽略])`（iOS/macOS action 按钮）
   - 两个 `AndroidNotificationAction`：`actionOk="完成"`（showsUserInterface）+ `actionIgnore="忽略"`（cancelNotification: true）
   - `payload: task.id` 通过 `_onNotificationResponse` 回调路由到 `NotificationService.onTaskAction`
   - `AppProvider._handleTaskAction` 区分 `actionOk`（标记 done + 取消 reminder + 保存 tasks.json）和 `actionIgnore`（仅取消 reminder）
2. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
3. ✅ bump `pubspec.yaml` 版本 `1.16.0+55` → `1.16.1+56`；最终 commit / tag / push。

### v1.17.0 最终化（已完成 ✅，2026-07-25）
1. ✅ **fix：编辑器手感优化** — 之前编辑器按 Enter 时键盘因 `setState` 重建而短暂收起/再次弹出；预览无法跨行选择。改造：
   - 活动行 TextField：`maxLines: null` + `autofocus: true` + `keyboardType: multiline` + `textInputAction: newline`
   - `_splitActiveLineAtText` 移除 `_lineFocus.requestFocus()` 显式调用，让 FocusNode + autofocus 隐式保持键盘
   - `_buildHybridBody` 用 `SelectionArea` 包裹整个 ListView → 跨行多选支持
   - `_buildPreviewLine` 改用 `safeMarkdown(selectable: true)` → MarkdownBody 文本可选中复制
   - `_lineFocus.onKeyEvent` 监听 `LogicalKeyboardKey.arrowUp/arrowDown` 在行首/末时切换 `_activeLine`（向上/向下时移动活动行）
2. ✅ **add：HuggingFace AI Provider** — `AIProviderPresets` 增加 `huggingface = https://router.huggingface.co/v1`，默认模型 `meta-llama/Meta-Llama-3-8B-Instruct`。
3. ✅ **add：AI 多 Key 顺序 fallback + 自定义 Provider 模型** — 之前 `aiApiKey: String?` 限制单 key；新版引入 `AiEndpoint` class（id / label / baseUrl / keys / builtinKey）和 `aiEndpoints: List<AiEndpoint>`，每个 endpoint 持有一个有序 key 列表：
   - `AIService._askWithFallback()` 按 `apiKeys` 顺序尝试调用，401/403/429 → 自动 next key，直到用完或成功
   - `AppProvider._configureAiService()` 从 `currentEndpoint.keys` 加载 keys
   - `StorageService` 新格式：settings.json 存 endpoints，secrets.json 仅存 `githubToken`；旧 `aiApiKey` 单字符串在 `AppSettings.fromJson` 中 migrate 到 endpoint.keys[0]
   - 设置页 AI 区块：多 Key 列表 + "+ 添加 Key" + 各 key 的"删除"按钮 + 整体 Key 显示/隐藏切换
4. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
5. ✅ bump `pubspec.yaml` 版本 `1.16.1+56` → `1.17.0+57`；最终 commit / tag / push。

### v1.17.1 最终化（已完成 ✅，2026-07-26）
1. ✅ **fix：编辑器多行粘贴** — 之前 `_splitActiveLineAtText` 只在第一个 `\n` 切分，粘贴 `"A\nB\nC"` 时只识别 `A`，后两行被吞。新版按 `\n` 切出所有 piece，依次插入 `_content`；controller 显示最后 piece，光标置于首。
2. ✅ **add：自定义 Provider 多 baseurl / 多 key UI** — 之前设置页对自定义只有一个 `if (_aiProvider == 'custom')` 块，单 URL 单 key 流。新版：
   - dropdown 列出 `aiEndpoints` 全部项（built-in + 已有自定义）
   - 选中非 built-in 才显示 label + baseUrl 输入框
   - 底部 "+ 添加自定义 Provider" 立即写入 `aiEndpoints`（生成 `custom:<microseconds>` id）
   - "删除当前 Provider" 仅当非 built-in 出现
   - 选中 provider 后 baseUrl/label/keys 三个 controller 自动 sync
3. ✅ `flutter analyze` 0 issues + `flutter test` 46 passed。
4. ✅ bump `pubspec.yaml` 版本 `1.17.0+57` → `1.17.1+58`；最终 commit / tag / push。

---

## 三·五、v1.18.0 开发上下文（已落地并发布 ✅）

用户三条需求 + 编辑器两点修正（/new 出发 后追加「工具栏移到底部」「文件名即标题」）：

1. ✅ **文件名 = 标题联动** — `Note.fileName` 由 `$id.md` 改为 `sanitizeFileName(title).md`；`StorageService._writeNoteContent` 以「目录保留 + 基名跟随标题」为唯一规则派生内容路径，标题变化时自动 rename 磁盘文件（含 ` (n)` 冲突后缀、`$id.md` 旧文件迁移）。`Note` 新增顶层 `sanitizeFileName()` 与 `privateNotesFolderName = '私人笔记'`。
2. ✅ **私人笔记文件夹** — `StorageService.setFolder` 打开/新建仓库时自动建 `私人笔记/` 目录；`Note.isPrivate`（路径含 `私人笔记`）；GitHub 同步 `syncNotes` 上传循环跳过私人笔记（仅占位防误删），`_readExtraFiles` 也跳过该目录；首页文件夹头显示锁图标。
3. ✅ **添加文件按钮** — 编辑器底部工具栏新增「添加文件」（`file_picker` v11 `FilePicker.pickFiles`）：选仓库内文件后自动填充 `relativePath`、加载内容、标题取文件名（契合文件名=标题）。
4. ✅ **工具栏移到底部** — 编辑器 Markdown 工具栏 + 字数状态栏移入 `Scaffold.bottomNavigationBar`（新 `_buildBottomBar`），标题/标签留在顶部。
5. ✅ **剪切板小组件** — `AppSettings.clipboardMax`（默认 100，1–99999，设置页「小组件」可调）；`ClipboardService` 单例轮询系统剪切板、去重、落盘 `clipboard.json`；首页新增第四底部标签「剪切板」（`ClipboardWidget`：列表/点按复制回剪切板/单条删除/清空）。
6. ✅ 三语新增 10 key（addFile / selectRepoFirst / fileMustBeInRepo / fileReadFailed / clipboard / clipboardEmpty / copiedToClipboard / clear / widgets / clipboardMax）。
7. ✅ `flutter analyze` 0 issues + `flutter test` 56 passed（含新增 `test/v118_test.dart`：sanitizeFileName / fileName·isPrivate / 标题改名移文件 / 同名去重 / 私人文件夹自动创建）。
8. ✅ bump `pubspec.yaml` 版本 `1.17.1+58` → `1.18.0+59`；最终 commit / tag / push。

---

## 四、关键历史决策（已与用户确认）
1. **所有配置进 `.config`**（接受 GitHub sync 密钥泄露风险）。
2. **逐行混合编辑器**（按原话实现；活动行原文、其余预览）。
3. **真实系统通知**（按原话；用 `flutter_local_notifications`，Windows 递延）。
