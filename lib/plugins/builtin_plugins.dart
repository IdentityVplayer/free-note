import 'package:flutter/material.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

/// Built-in word count plugin — shows word and character count.
class WordCountPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.wordcount';

  @override
  String get name => 'Word Count';

  @override
  String get description => 'Displays word and character count for the current note.';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Free Note';

  @override
  PluginType get type => PluginType.utility;

  /// Count words in the given text.
  Map<String, int> count(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = text.length;
    final lines = text.split('\n').length;
    return {'words': words, 'chars': chars, 'lines': lines};
  }

  @override
  Widget? buildWidget(BuildContext context) {
    return const SizedBox.shrink(); // Integrated into editor screen directly.
  }
}

/// Built-in text formatter plugin — provides quick markdown formatting.
class TextFormatterPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.textformatter';

  @override
  String get name => 'Text Formatter';

  @override
  String get description => 'Quick markdown formatting tools (bold, italic, headers, etc.)';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Free Note';

  @override
  PluginType get type => PluginType.editor;

  String wrapSelection(String text, String before, [String? after]) {
    return '$before$text${after ?? before}';
  }
}

/// Built-in export plugin — exports notes in different formats.
class ExportPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.exporter';

  @override
  String get name => 'Export Tools';

  @override
  String get description => 'Export notes as Markdown, HTML, or plain text.';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Free Note';

  @override
  PluginType get type => PluginType.exporter;

  String toPlainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .trim();
  }
}
