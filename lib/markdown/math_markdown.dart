import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import 'html_markdown.dart';

/// Inline LaTeX: `$...$` (single line, no nested `$`).
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

/// Block LaTeX: `$$ ... $$` (may span multiple lines).
class BlockMathSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*\$\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final buffer = StringBuffer();
    final first = parser.current.content;
    final open = RegExp(r'^\s*\$\$\s?(.*)$').firstMatch(first);
    final rest = open?.group(1) ?? '';

    // `$$ ... $$` on a single line.
    final closeSame = RegExp(r'^(.*?)\s*\$\$\s*$').firstMatch(rest);
    if (closeSame != null) {
      buffer.write(closeSame.group(1));
      parser.advance();
      return md.Element('mathBlock', [
        md.Element.text('math', buffer.toString().trim()),
      ]);
    }

    if (rest.trim().isNotEmpty) buffer.writeln(rest);
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      final close = RegExp(r'^(.*?)\s*\$\$\s*$').firstMatch(line);
      if (close != null) {
        buffer.writeln(close.group(1));
        parser.advance();
        break;
      }
      buffer.writeln(line);
      parser.advance();
    }
    return md.Element('mathBlock', [
      md.Element.text('math', buffer.toString().trim()),
    ]);
  }
}

/// Renders a `math` / `mathBlock` element with flutter_math_fork.
///
/// Wraps [Math.tex] in a try-catch so that font-loading errors, parse failures,
/// or any other internal exception never bubble up and blank the whole page.
class MathBuilder extends MarkdownElementBuilder {
  final bool display;
  MathBuilder({this.display = false});

  @override
  bool isBlockElement() => display;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return const SizedBox.shrink();
    final baseStyle = preferredStyle ?? DefaultTextStyle.of(context).style;
    try {
      return Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: baseStyle,
        onErrorFallback: (error) => Text(
          tex,
          style: baseStyle.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      );
    } catch (_) {
      // Fallback for any unhandled exception (e.g. missing fonts).
      return Text(
        display ? '$tex\n' : tex,
        style: baseStyle.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontFamily: 'monospace',
        ),
      );
    }
  }
}

/// Plug these into any `Markdown` / `MarkdownBody` widget to enable LaTeX.
final List<md.InlineSyntax> mathInlineSyntaxes = [InlineMathSyntax()];
final List<md.BlockSyntax> mathBlockSyntaxes = [BlockMathSyntax()];
Map<String, MarkdownElementBuilder> get mathBuilders => {
  'math': MathBuilder(),
  'mathBlock': MathBuilder(display: true),
};

/// A safe [MarkdownBody] pre-configured with LaTeX support so that a note
/// never goes blank on a parse/render fault.
///
/// [relativeBaseDir] is the absolute directory under which `./name.jpg` and
/// `../name.jpg` style image references are resolved. If null, only
/// absolute paths (or HTTP URLs) are rendered.
Widget safeMarkdown({
  required String data,
  MarkdownTapLinkCallback? onTapLink,
  bool selectable = true,
  String? relativeBaseDir,
}) {
  // Let `<a>` links reuse the same open handler as Markdown links.
  HtmlTagBuilder.onTapLink = onTapLink;
  return Padding(
    padding: const EdgeInsets.all(16),
    child: MarkdownBody(
      data: data,
      selectable: selectable,
      // Excludes the default InlineHtmlSyntax so our HtmlTagSyntax owns
      // inline-HTML parsing (v1.18.2).
      extensionSet: htmlFriendlyExtensionSet,
      inlineSyntaxes: [...mathInlineSyntaxes, ...htmlInlineSyntaxes],
      blockSyntaxes: mathBlockSyntaxes,
      builders: {...mathBuilders, ...htmlBuilders},
      sizedImageBuilder: relativeBaseDir == null
          ? null
          : (config) => _buildLocalImage(config.uri, relativeBaseDir),
      onTapLink: (text, href, title) => onTapLink?.call(text, href, title),
    ),
  );
}

/// Build an `Image` widget for `<img src="./foo.jpg">` style references.
/// Resolves `./` and `../` relative to [baseDir] (the note's parent folder).
/// Falls back to a broken-image placeholder when the file is missing.
Widget _buildLocalImage(Uri uri, String baseDir) {
  String path = uri.toFilePath();
  if (path.isEmpty) return const _MissingImage();
  // Strip a leading '/' that Uri.toFilePath() leaves on absolute paths.
  if (path.startsWith('/')) path = path.substring(1);
  // Resolve relative to the note's directory.
  if (path.startsWith('./') ||
      path.startsWith('../') ||
      !path.startsWith('/')) {
    final normalized = path.replaceFirst(RegExp(r'^\./'), '');
    final resolved =
        Directory(baseDir).path +
        (normalized.startsWith('/') ? normalized : '/$normalized');
    final file = File(resolved);
    if (!file.existsSync()) return const _MissingImage();
    return Image.file(file, fit: BoxFit.contain);
  }
  // Absolute path — use as-is.
  final file = File('/$path');
  if (!file.existsSync()) return const _MissingImage();
  return Image.file(file, fit: BoxFit.contain);
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();
  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    alignment: Alignment.center,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.broken_image_outlined),
  );
}
