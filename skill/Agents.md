# skill/Agents.md — 为 Free Note（无边记）开发插件

> 本文档面向 **AI 助手 / 智能体**，告诉你在 Free Note 代码库里该如何**新增一个插件**。
> 当你接到「加一个插件」的需求时，按本文的契约来写代码，保证能与现有插件系统无缝集成。

---

## 0. 一句话契约

一个插件 = 一个继承 `FreeNotePlugin` 的 Dart 类 + 在 `AppProvider.init()` 里 `register()`。
插件通过 `PluginInfo` 描述自己的元信息，通过 `PluginManager` 被统一管理、开关、构建 UI。

---

## 1. 核心 API（必须掌握的 4 个类型）

| 类型 | 文件 | 作用 |
| --- | --- | --- |
| `FreeNotePlugin` | `lib/plugins/plugin_base.dart` | 所有插件的抽象基类，你要继承它 |
| `PluginInfo` | `lib/models/plugin.dart` | 插件的元信息（id/名称/类型等），可 JSON 序列化 |
| `PluginManager` | `lib/plugins/plugin_manager.dart` | 注册中心：`register / enable / disable / toggle / buildWidgets` |
| `PluginType` | `lib/models/plugin.dart` | 枚举：`editor / exporter / importer / theme / utility` |
| `GitHubSyncHost` | `lib/plugins/github_sync_host.dart` | 带「设置页」的插件用它回调 App 状态（见 §5） |

---

## 2. 最小插件模板

新建文件 `lib/plugins/my_plugin.dart`：

```dart
import 'package:flutter/material.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

class MyPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.myplugin';          // 全局唯一，建议 builtin.<名>

  @override
  String get name => 'My Plugin';               // 展示名

  @override
  String get description => '一句话说明它做什么。';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Borderless Notes';

  @override
  PluginType get type => PluginType.utility;    // 选最贴近的一种

  /// 默认开启；想默认关闭就改成 `bool get isEnabled => false;`
  @override
  bool isEnabled = true;

  /// 开启时调用（初始化资源、注册监听等）。
  @override
  void onEnable() {}

  /// 关闭时调用（释放资源）。
  @override
  void onDisable() {}

  /// 文本处理钩子：所有启用的插件会依次收到笔记正文，可改写后返回。
  /// 不处理就返回 null（原始文本原样透传）。
  @override
  String? processText(String input) => input;

  /// 在编辑器/工具栏提供 UI；没有就返回 null。
  @override
  Widget? buildWidget(BuildContext context) => null;
}
```

### 注册（关键一步，别漏）

打开 `lib/providers/app_provider.dart`，在 `init()` 的注册区加上一行：

```dart
pluginManager.register(MyPlugin());
```

```dart
// lib/providers/app_provider.dart  (init 内)
pluginManager.register(WordCountPlugin());
pluginManager.register(TextFormatterPlugin());
pluginManager.register(ExportPlugin());
pluginManager.register(AiContextPlugin());
pluginManager.register(AutoSavePlugin());
pluginManager.register(GitHubSyncPlugin());
pluginManager.register(MyPlugin());   // ← 新增
```

⚠️ 注册后插件会自动出现在「插件」页面，并受开关控制。**不要**手动改 `SettingsScreen` 或 `PluginsScreen` 来「写死」展示——它们都从 `PluginManager` 读取。

---

## 3. 插件类型该怎么选

- `editor`：在编辑器里提供格式/插入能力（如 Text Formatter、AI 上下文）。
- `exporter` / `importer`：导出或导入笔记（如 Export Tools）。
- `theme`：改变外观/主题。
- `utility`：通用工具（如 Word Count、AutoSave、GitHub Sync）。

类型只影响「插件」页里的图标（`plugins_screen.dart` 的 `typeIcons` 映射），不影响功能，但请选语义最贴近的。

---

## 4. 提供「设置页」

如果插件有可配置项：

```dart
@override
bool get hasSettings => true;

@override
Widget? buildSettings(BuildContext context, [GitHubSyncHost? host]) {
  return MyPluginSettingsScreen(host: host);   // 你自己写的 Widget
}
```

- 设了 `hasSettings => true` 后，「插件」卡片左下角会显示齿轮图标，点击卡片或齿轮都会打开该页面。
- 设置页里**不要**直接 import `AppProvider`（会造成循环依赖）。需要回写 App 状态时，通过 `host` 参数（`GitHubSyncHost` 接口）回调：`host?.updateGitHubAuth(...)` 等。

---

## 5. 与 GitHub / 全局状态交互（GitHubSyncHost）

带登录/同步的插件（如 GitHub Sync）通过 `GitHubSyncHost` 接口拿到 App 接线，而非直接依赖 `AppProvider`：

```dart
abstract class GitHubSyncHost {
  AppSettings get settings;
  GitHubSyncService get githubService;
  Future<void> updateGitHubAuth({String? token, String? username, String? repo, String? clientId, bool? autoSync});
  Future<String> syncToGitHub();
  Future<String> pullFromGitHub();
}
```

在 `buildSettings` 里用 `host?.updateGitHubAuth(...)` 把登录结果写回 App。

---

## 6. 在编辑器/工具栏里显示 UI

`PluginManager.buildWidgets(context)` 会收集所有**已启用**插件的 `buildWidget()` 结果。
编辑器（`lib/screens/editor_screen.dart`）在合适位置调用它来渲染插件按钮。
你的插件想出现按钮就实现 `buildWidget`，想纯后台运行就返回 `null`。

---

## 7. 国际化

插件里所有**面向用户**的字符串都走 i18n，不要硬编码英文：

1. 在 `lib/l10n/app_en.json` / `app_zh.json` / `app_ja.json` 各加一个 key。
2. 用 `AppLocalizations.of(context)!.t('yourKey')` 取文案。
3. 三个文件必须**同步**保持 key 数量一致（当前 148 个），否则 CI 会挂。

---

## 8. 测试 & 检查清单

写完插件后，务必运行：

```bash
flutter analyze      # 0 issues
flutter test         # 全绿
```

提交前自检：

- [ ] 继承 `FreeNotePlugin`，`id` 全局唯一
- [ ] `init()` 里已 `register()`
- [ ] 面向用户文案已加进 en/zh/ja 三个 l10n 文件
- [ ] 有设置页时实现了 `hasSettings` + `buildSettings`，且不 import `AppProvider`
- [ ] `processText` 不处理时返回 `null`
- [ ] `flutter analyze` 与 `flutter test` 均通过
- [ ] 在 `Features.md` 补一行版本说明

---

## 9. 用户自建插件（运行时添加）

「插件」页右上角的 **+** 按钮允许用户在运行时添加**用户插件**（轻量级描述型插件）。
它们存于 `AppSettings.userPlugins`，`AppProvider` 在 `init()` 时复原并注册，可长按卡片删除。
这类插件是 `UserPlugin` 实例（见 `lib/plugins/user_plugin.dart`），目前仅承载元信息展示与开关——
若要让用户插件承载真实逻辑，需扩展 `UserPlugin`（例如加载脚本/模板），本文档聚焦「代码级内置插件」。
