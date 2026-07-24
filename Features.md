# 无边记 (Borderless Notes) — Features & Changelog

## 1.13.6

### Changed
- **GitHub 同步改为逐个文件上传** — 每篇笔记单独上传为 `notes/<relativePath>.md`（YAML 前后端格式），保持子目录结构；删除的笔记自动清理远端；遗留的 `notes/notes.json` 自动删除。拉取时遍历 `notes/` 目录下载每个 `.md` 文件解析回笔记。

## 1.13.5

### Fixed
- **首页任务计划 Dock 不自动刷新** — 嵌入式 `TaskPlanScreen` 在从完整任务计划页返回后不再重建，导致新增/修改的任务未即时显示。修复：`TaskPlanScreenState` 公开化 + `reloadTasks()` 方法 + `GlobalKey` + `didPopNext` 触发刷新。

## 1.13.4

### Added
- **内置 AI 密钥 + OpenRouter 预设** — 新增 `openrouter` AI 提供商预设（baseUrl: `https://openrouter.ai/api/v1`，模型 `openrouter/free`），内置 OpenRouter API Key，新用户无需配置 API Key 即可使用 AI 功能。内置密钥永不展示在 UI 中。
- **`.config/secrets.json` 密钥隔离** — `aiApiKey` 与 `githubToken` 从 `settings.json` 移出，独立持久化到 `.config/secrets.json`（base64 编码），减少密钥意外泄露风险。旧版 `settings.json` 中的密钥在首次加载时自动迁移。

### Changed
- **设置页 API Key 防泄露** — AI API Key 输入框默认隐藏，增加可见性切换（默认隐蔽）；当用户未填写自有密钥时显示"将使用内置密钥"提示（不展示真实密钥）。
- **无密钥时自动走内置 OpenRouter** — 若用户未配置自有 API Key，系统自动使用内置 OpenRouter 密钥，并将端点与模型强制设为 OpenRouter，确保回退链路可用。

### Fixed
- **番茄钟/任务可能被清空** — 持久化改为原子写入（临时文件 → 替换 → 保留 `.bak` 备份）；读取时若主文件损坏自动回退到 `.bak`，避免中途崩溃或磁盘满后 `loadTasks` 返回空并被永久覆盖。新增 4 个回归测试。

## 1.13.3

### Added
- **GitHub Sync 双向自动同步** — 开关 `autoSync` 现在真正生效：应用启动、退出前/切后台（`paused`/`detached`）、退出编辑器时自动同步。同步为双向：先拉取远端 `notes.json`，按 `id` 合并（以较新的 `updatedAt` 为准），本地落盘后再推送，避免互相覆盖丢失。由 `_isSyncing` 防重入，且不阻塞界面。
- **番茄钟统计** — 番茄钟页面顶部展示「今日 / 本周 / 本月 / 本年」的累计专注时长与休息时长（含短休息+长休息），数据来自每次阶段完成的本地历史记录。
- **番茄钟多预设卡片** — 番茄钟页面以卡片展示每个预设：底部高斯模糊背景图、左下角「开始」直接开始该预设计时、右下角铅笔按钮进入编辑。

### Changed
- **首页「计划任务」Dock 显示完整 UI** — 与完整计划页（`TaskPlanScreen`）一致，支持勾选、子任务、新增等完整交互（不再是截断的平铺复选框）。

### Fixed
- **计划任务子任务完成后误删任务（加固）** — 自动完成主任务（子任务全完成时）的合并结果加防御，确保任何情况下都不会丢失任务；并补充回归测试。

## 1.13.2

This file records feature highlights and version history. On each GitHub
Release, the section matching the current version (from `pubspec.yaml`) is
used as the release description.

## 1.13.2

### Added
- **GitHub Sync 新增「令牌 (Key) 登录」模式** — 同步设置页新增登录方式切换（设备登录 OAuth / 令牌登录）。选择「令牌登录」后可直接粘贴 GitHub Personal Access Token (PAT) 连接并同步，无需创建 OAuth App；连接时会校验令牌并拉取仓库列表。模式持久化于 `AppSettings.githubSyncMode`。

### Changed
- **AI API Key 与 GitHub Token 以 base64 混淆后存储** — `AppSettings` 在序列化时对 `aiApiKey` / `githubToken` 做 base64 编码（带 `b64:` 前缀），读回时解码；旧版明文设置文件因无前缀会被原样读取，向后兼容。密钥仍位于 `.config/settings.json`，但不再以明文暴露。

### Fixed
- **导出归档后缀错误（`.fne.zip` → `.fne`）** — 部分平台（如 Windows）的 `FilePicker.saveFile` 会在 `.fne` 文件名后追加 `.zip`；导出后统一把落盘文件规整为以 `.fne` 结尾，避免导入时因扩展名不匹配而选不到文件。
- **任务计划板块添加后不立即显示** — 首页「计划任务」Dock 是 `FutureBuilder`，返回 `TaskPlanScreen` 后不会重建。新增 `RouteObserver`，首页 `RouteAware` 在 `didPopNext` 时触发重建，重新加载任务列表，新增/编辑的任务立即出现。
- **OAuth 登录重启 APP 后失效** — `chooseFolder` 在（重新）选库时会把内存中的 `_settings`（若启动回落到选库页、`githubToken` 可能为 null）整体写回 `<repo>/.config/settings.json`，覆盖此前 OAuth 登录保存的令牌，导致重新打开 APP 后登录丢失。改为选库前先从目标仓库读取已持久化的设置并保留其中的 `githubToken` / `githubUsername` / `githubRepo` / `githubSyncMode` 再保存，确保重新选库不会丢失登录态。

## 1.13.1

### Changed
- **应用启动默认打开上一个打开的仓库** — 新增稳定私有文件 `.config/last_repo.json`，在 `AppProvider.init()` 读取设置**之前**先恢复 `storage.setFolder(lastRepo)`，从而让 `settings.json`（位于 `<repo>/.config`）能被正确读取（此前因启动时 `currentFolder` 为 null，设置会从私有目录读取，导致 `notesFolderPath` 丢失、每次启动都回落到仓库选择页）。`chooseFolder` 在选库/切换仓库时持续写入该路径；若上次仓库已被删除/卸载，则跳过恢复、正常显示选择页。

### Fixed
- **Markdown 单击（非滑动）无法进入编辑** — 预览行原本用 `MarkdownBody(selectable: true)`，可选中文本会吞掉指针事件，导致外层 `GestureDetector.onTap`（激活该行编辑）永不触发。改为渲染不可选中的 markdown（`safeMarkdown(selectable: false)`），单击即可编辑；链接仍通过 `onTapLink` 照常打开。

## 1.12.1

### Fixed
- **Android 发布构建（Build & Release / Auto Build）`checkReleaseAarMetadata` 失败** — `flutter_local_notifications` 要求启用 core library desugaring；在 `android/app/build.gradle.kts` 的 `compileOptions` 开启 `isCoreLibraryDesugaringEnabled = true` 并引入 `com.android.tools:desugar_jdk_libs:2.1.0` 依赖，APK/AAB 重新通过元数据检查。
- **CI `dart format --set-exit-if-changed` 失败** — 重新格式化 `lib/services/windows_notifications.dart`（参数列表换行），与 Flutter 3.44 (Dart 3.12) 格式化规则对齐。

## 1.13.0

### New Features
- **多番茄钟（预设 Profile）** — 番茄钟支持多个预设：每个 Profile 独立保存
  工作/短休息/长休息时长与名称，可一键切换；首个 Profile 为默认预设，老用户
  的 `pomodoro.json` 首次启动自动迁移为默认 Profile（`PomodoroProfile` +
  `PomodoroService` 管理 `List<PomodoroProfile>` + `activeId`）。
- **番茄钟背景可从相册选择** — 番茄钟设置里「从相册选择背景」调用系统相册
  （`image_picker`），图片复制到 `configDir/pomodoro_bg/{id}.jpg`，计时页面以
  半透明遮罩叠加显示；可随时清除换回纯色背景（`_pickBackground` / `_clearBackground`）。
- **长休息开关** — 每个 Profile 独立的长休息开关（`longBreakEnabled`）；关闭后
  永远走短休息。`nextPomodoroPhase` 仅在「长休息开启 && 已完成工作数 % 间隔 == 0」
  时进入长休息，否则短休息（任意休息结束后回到工作）。

### Fixed
- **主页面计划任务/番茄钟 Dock 直接展示内容** — 去掉了 Dock 顶部冗余的
  「计划任务 / 番茄钟」标题条目，现在直接展示用户真实的任务列表与当前番茄钟
  预设（`_buildTasksDock` / `_buildPomodoroDock` 使用 `PomodoroService.instance.active`）。
- **右下角「+」随当前页切换** — 底部 FAB 改为按当前 Tab 上下文添加：笔记页保持
  展开菜单（新建笔记 / 新建仓库）；计划任务页 → 新建计划任务；番茄钟页 → 新建
  番茄钟预设（均通过 `autoAdd` 参数直达对应编辑页）。

### Dependencies
- 新增 `image_picker: ^1.1.2`（相册选背景；Android 已含存储权限，iOS 无构建配置）。

## 1.12.0

### New Features
- **设置 → 关于：给我提 Issue & 检查更新** — 关于页新增「给我提 Issue」按钮（跳转仓库 Issues 新建页），以及「检查更新」：启动时/手动点击会比对 GitHub Releases 最新版本，若大于当前版本则弹窗展示更新内容并给出「下载 / 暂不下载」按钮（`GitHubSyncService.fetchLatestRelease` + `package_info_plus`）。
- **配置统一进 `.config` 并自动迁移** — 所有配置文件（API KEY、GitHub Sync 等）统一存到仓库根目录 `.config` 下；老用户首次启动，`settings.json` / `tasks.json` / `pomodoro.json` 自动从应用私有目录迁入仓库 `.config/`（`StorageService.migrateFileFromPrivate` + 迁移守卫）。
- **「选择文件夹」→「选择仓库」** — 术语统一更名；设置里改用菜单存储打开过的**所有仓库**，可一键切换，当前仓库实时显示（`Settings.repositories` + `chooseFolder` 记录 + 仓库切换对话框）。仅顶层术语改名，真实子文件夹保留原「文件夹」称呼。
- **逐行混合编辑器** — 去除编辑/预览模式切换：文件不编辑时自动预览，编辑时**仅正在编辑的那一行为原文**，其余行均为预览（`editor_screen.dart` + `lib/utils/text_edit.dart`）。
- **AI 写作 → AI 问答（分屏）** — 文件内容缩到上半屏，AI 窗口在下半屏；上半屏长按可选择文本，也可**拖拽到下方 AI 窗口**追加到光标后（`AiQaScreen` + `AIAssistantScreen(embedded:true)` + `LongPressDraggable`/`DragTarget`）。
- **底部 Dock 三栏布局** — 番茄钟与计划任务移到屏幕下方，笔记单独居中一栏：**左计划任务、右番茄钟**（底部 `NavigationBar` 三标签：任务 / 笔记 / 番茄钟）。
- **计划任务：主任务 / 子任务** — 右下角「+」创建主任务，点开主任务后「+」创建子任务；子任务全部完成时主任务自动完成（可在设置中开关 `autoCompleteMainTasks`）。
- **任务提醒 & 重复** — 计划任务新增「提醒」（Android/iOS/macOS/Linux 真实系统通知，`flutter_local_notifications`）与「重复」（按 小时/天/周/月/年 到期后自动重生一份全子任务未完成的副本，`respawnDueRepeats` 应用启动时执行）。

### Fixed
- **主界面「AI 聊天」总显示未配置密钥** — 无论是否配置密钥，提示语都错误地显示未配置；现改为按密钥实际配置状态门控。

### Notes
- i18n 三语对齐：en / zh / ja 各新增约 33 个键（共 **243**），覆盖上述全部界面文案。
- **Windows Toast 递延**：当前 `flutter_local_notifications` 缓存版无 Windows 初始化支持，Windows 端原生通知提醒推迟到后续版本；重复任务因 `respawnDueRepeats` 在应用启动时运行，即使无 OS 投递也能正常重生。

## 1.11.0

### Fixed
- **AI 对话的 md 文件现在真正作为上下文** — 之前 `AIService.ask` 是无状态的：每次调用只把「系统提示 +（上下文 + 最新问题）」发给模型，续聊一个 AI 笔记（以 `! Free note ai chat` 开头的 `.md`）时，界面虽然展示了历史对话，但模型只收到最后一句提问，前面的多轮内容全部丢失。现 `ask` 新增 `history` 参数，把**已保存对话的前几轮**作为历史消息一并回传；`AIAssistantScreen._ask` 在续聊时会从内存里已有消息（除最后一条刚追加的当前提问外）构建 `history` 并传入，模型因此能「记住」整段 md 对话。

### New Features
- **任务计划（Task Plan）** — 首页顶栏新增清单图标入口，进入独立任务页：
  - 新增 / 编辑任务（标题、截止日期、优先级 高/中/低），支持勾选完成、删除（带确认）。
  - 每个任务可**关联一篇笔记**（从笔记列表里选），卡片上显示笔记标题，点击即跳转到对应笔记编辑器。
  - 列表排序：未完成先于已完成，再按优先级（高→低），再到期日（早→晚）。
  - 任务持久化到应用私有目录的 `tasks.json`，重启不丢；新增 `Task` 模型与 `TaskService`。
- **番茄钟（Pomodoro）** — 首页顶栏新增计时器图标入口，进入独立计时页：
  - 自动在「专注 → 短休息 → 专注 → … → 每 N 个专注后长休息」之间循环（默认 N=4），圆形进度环实时显示剩余时间，并统计已完成的专注次数。
  - 时长可在「计时设置」里自定义（专注 / 短休息 / 长休息 分钟数 + 长休息间隔），配置持久化到 `pomodoro.json`；新增 `PomodoroConfig` / `PomodoroService` 与 `nextPomodoroPhase` 阶段推进逻辑。
- **i18n 三语对齐** — en / zh / ja 各新增 30 个键（共 210），覆盖任务计划与番茄钟的全部界面文案。

## 1.10.0

### New Features
- **用户插件真正挂载 UI** — 在「插件」页用「+」添加的**编辑器类（editor）**用户插件，现在可以填写一段「插入片段」文本。启用后，编辑器工具栏会渲染一个**真实按钮**，点击即把该片段插入到光标处（经由新增的 `PluginHost` 回调，插件无需依赖 `AppProvider`）。`PluginInfo` 新增 `snippet` 字段并随 `userPlugins` 持久化；`WordCountPlugin.buildWidget` 改回 `null`，让 `PluginManager.buildWidgets` 只产出用户插件按钮。
- **首页 AI 笔记标识与续聊** — 首页笔记列表中，内容以 `! Free note ai chat` 开头的 **AI 笔记**现在显示 **AI 图标 + 「AI」徽标**；在 AI 插件（builtin.aicontext）启用时，卡片右侧出现「继续对话」按钮（并加入长按菜单），可直接打开文件内对话界面，关闭后对话自动回存该笔记。

## 1.9.9

### Changed
- **AI 正式成为插件（可开关）** — 原 `AiContextPlugin` 重命名为 **AI Assistant** 插件，现在它是编辑器里**所有 AI 功能的唯一开关**：AI 写作菜单（续写/润色/总结/翻译/扩写）与「AI 对话」入口都受 `builtin.aicontext` 启用状态控制。在「插件」页关闭该插件，编辑器的所有 AI 按钮即消失。
- **AI 对话改为文件内对话框** — 编辑器顶栏的「AI 对话」按钮（ upload 图标）现在以 `showGeneralDialog` 的形式**在文件内直接唤醒 AI 对话界面**（当前笔记内容自动作为上下文），而非整页跳转。

### Added
- **AI 笔记自动续接** — 打开一个 AI 生成的笔记（内容以 `! Free note ai chat` 开头的聊天存档）时：
  1. 自动把对话解析为上下文并**自动打开 AI 对话界面**；
  2. 关闭对话时**对话内容自动保存**回该笔记（不再弹「是否保存」询问），并在编辑器内提示「对话已自动保存到笔记」。
  手动从普通笔记发起的 AI 对话仍保持原行为（离开时询问是否另存为新的 Chat 笔记）。

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
