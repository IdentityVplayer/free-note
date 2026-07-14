import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

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
    return Math.tex(
      tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: baseStyle,
      onErrorFallback: (error) => Text(
        tex,
        style: baseStyle.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// Plug these into any `Markdown` / `MarkdownBody` widget to enable LaTeX.
final List<md.InlineSyntax> mathInlineSyntaxes = [InlineMathSyntax()];
final List<md.BlockSyntax> mathBlockSyntaxes = [BlockMathSyntax()];
Map<String, MarkdownElementBuilder> get mathBuilders => {
  'math': MathBuilder(),
  'mathBlock': MathBuilder(display: true),
};
