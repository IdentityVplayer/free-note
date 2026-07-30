import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Inline HTML support for the note preview (v1.18.2).
///
/// `flutter_markdown` (`MarkdownBody`) does NOT render raw HTML by default —
/// the `markdown` package's `InlineHtmlSyntax` only tokenises tags and
/// `flutter_markdown` renders them as literal text. We replace that with a
/// small whitelist of inline tags so notes can mix Markdown and HTML freely:
///
///   `<font color face size>` — colored / re-faced / re-sized text
///   `<b>` `<strong>`         — bold
///   `<i>` `<em>`             — italic
///   `<u>`                    — underline
///   `<s>` `<strike>` `<del>` — strikethrough
///   `<code>`                 — monospace
///   `<mark>`                 — highlighter background
///   `<span style="...">`     — inline CSS (color / background / font-*)
///   `<a href="...">`         — tappable link
///
/// Both HTML4 (`<font>`) and HTML5 (the deprecated-but-still-working `<font>`
/// plus the semantic tags above) are handled. Nesting of the *same* tag is not
/// supported (the first closing tag wins) — a deliberate simplification for an
/// inline renderer.
class HtmlTagSyntax extends md.InlineSyntax {
  HtmlTagSyntax()
      : super(
          r'<(font|b|strong|i|em|u|s|strike|del|code|mark|span|a)'
          r'(\s+[^>]*)?>(.*?)</\1>',
          startCharacter: 60, // '<'
          caseSensitive: false,
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tag = (match[1] ?? '').toLowerCase();
    final attrsRaw = match[2] ?? '';
    final inner = match[3] ?? '';

    final element = md.Element.text('htmlTag', inner);
    element.attributes['data-tag'] = tag;

    // Minimal attribute parser: name="value" | name='value' | name=value.
    final attrRe = RegExp(
      "([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
    );
    for (final m in attrRe.allMatches(attrsRaw)) {
      final name = (m[1] ?? '').toLowerCase();
      final value = m[3] ?? m[4] ?? m[5] ?? '';
      element.attributes[name] = value;
    }

    parser.addNode(element);
    return true;
  }
}

/// Renders the element produced by [HtmlTagSyntax] as a styled [Text] (or a
/// tappable [GestureDetector] for `<a>`).
class HtmlTagBuilder extends MarkdownElementBuilder {
  /// Set by [safeMarkdown] so `<a>` links can be opened through the same
  /// callback as Markdown links.
  static MarkdownTapLinkCallback? onTapLink;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tag = element.attributes['data-tag'] ?? element.tag;
    final text = element.textContent;
    var style = preferredStyle ?? DefaultTextStyle.of(context).style;

    switch (tag) {
      case 'b':
      case 'strong':
        style = style.copyWith(fontWeight: FontWeight.bold);
      case 'i':
      case 'em':
        style = style.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        style = style.copyWith(decoration: TextDecoration.underline);
      case 's':
      case 'strike':
      case 'del':
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      case 'code':
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        );
      case 'mark':
        style = style.copyWith(backgroundColor: Colors.yellow);
      case 'font':
        final color = parseColor(element.attributes['color']);
        if (color != null) style = style.copyWith(color: color);
        final face = element.attributes['face'];
        if (face != null && face.isNotEmpty) {
          style = style.copyWith(fontFamily: face);
        }
        final size = element.attributes['size'];
        if (size != null) style = _applyFontSize(style, size);
      case 'span':
        final css = element.attributes['style'];
        if (css != null) style = _applyStyleAttr(style, css);
    }

    if (tag == 'a') {
      final href = element.attributes['href'];
      return GestureDetector(
        onTap: href != null
            ? () => onTapLink?.call(
                text,
                href,
                element.attributes['title'] ?? '',
              )
            : null,
        child: Text(text, style: style),
      );
    }
    return Text(text, style: style);
  }
}

/// Common inline-font sizes (HTML `<font size="1..7">`) mapped to px.
const Map<int, double> _fontSizeTable = {
  1: 10,
  2: 13,
  3: 16,
  4: 18,
  5: 24,
  6: 32,
  7: 48,
};

TextStyle _applyFontSize(TextStyle style, String size) {
  final n = int.tryParse(size);
  if (n != null && _fontSizeTable.containsKey(n)) {
    return style.copyWith(fontSize: _fontSizeTable[n]);
  }
  final px = RegExp(r'([\d.]+)px').firstMatch(size);
  if (px != null) return style.copyWith(fontSize: double.parse(px[1]!));
  return style;
}

/// Applies a subset of inline CSS declarations to [style].
TextStyle _applyStyleAttr(TextStyle style, String css) {
  for (final decl in css.split(';')) {
    final parts = decl.split(':');
    if (parts.length != 2) continue;
    final prop = parts[0].trim().toLowerCase();
    final val = parts[1].trim();
    switch (prop) {
      case 'color':
        final c = parseColor(val);
        if (c != null) style = style.copyWith(color: c);
      case 'background-color':
        final c = parseColor(val);
        if (c != null) style = style.copyWith(backgroundColor: c);
      case 'font-family':
        final fam = val
            .split(',')
            .first
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '');
        if (fam.isNotEmpty) style = style.copyWith(fontFamily: fam);
      case 'font-size':
        final px = RegExp(r'([\d.]+)px').firstMatch(val);
        if (px != null) {
          style = style.copyWith(fontSize: double.parse(px[1]!));
        }
      case 'font-weight':
        if (val == 'bold' || val == '700' || val == '600') {
          style = style.copyWith(fontWeight: FontWeight.bold);
        }
      case 'font-style':
        if (val == 'italic') {
          style = style.copyWith(fontStyle: FontStyle.italic);
        }
      case 'text-decoration':
        if (val.contains('underline')) {
          style = style.copyWith(decoration: TextDecoration.underline);
        } else if (val.contains('line-through')) {
          style = style.copyWith(decoration: TextDecoration.lineThrough);
        }
    }
  }
  return style;
}

/// Parses a CSS color into a Flutter [Color].
///
/// Supports `#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()/rgba()`, and a set of common
/// named colors. Returns `null` when the value can't be understood.
Color? parseColor(String? value) {
  if (value == null) return null;
  final v = value.trim().toLowerCase();
  if (v.isEmpty) return null;

  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((c) => c + c).join();
    }
    if (hex.length == 6) hex = 'ff$hex';
    if (hex.length == 8) {
      final n = int.tryParse(hex, radix: 16);
      if (n != null) return Color(n);
    }
    return null;
  }

  final rgb = RegExp(
    r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)',
  ).firstMatch(v);
  if (rgb != null) {
    final r = int.parse(rgb[1]!);
    final g = int.parse(rgb[2]!);
    final b = int.parse(rgb[3]!);
    final a = rgb[4] != null
        ? (double.parse(rgb[4]!) * 255).round().clamp(0, 255)
        : 255;
    return Color.fromARGB(a, r, g, b);
  }

  return _namedColors[v];
}

/// A practical subset of the CSS named colors.
const Map<String, Color> _namedColors = {
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'lime': Color(0xFF00FF00),
  'blue': Color(0xFF0000FF),
  'yellow': Color(0xFFFFFF00),
  'orange': Color(0xFFFFA500),
  'purple': Color(0xFF800080),
  'violet': Color(0xFFEE82EE),
  'pink': Color(0xFFFFC0CB),
  'magenta': Color(0xFFFF00FF),
  'fuchsia': Color(0xFFFF00FF),
  'cyan': Color(0xFF00FFFF),
  'aqua': Color(0xFF00FFFF),
  'teal': Color(0xFF008080),
  'navy': Color(0xFF000080),
  'maroon': Color(0xFF800000),
  'olive': Color(0xFF808000),
  'brown': Color(0xFFA52A2A),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
  'silver': Color(0xFFC0C0C0),
  'gold': Color(0xFFFFD700),
  'indigo': Color(0xFF4B0082),
  'transparent': Color(0x00000000),
};

/// GitHub-flavored syntax with the default [md.InlineHtmlSyntax] removed so our
/// [HtmlTagSyntax] owns inline-HTML parsing (otherwise the built-in would
/// swallow `<font>` etc. as literal text). Strikethrough/emoji are kept.
final md.ExtensionSet htmlFriendlyExtensionSet = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  md.ExtensionSet.gitHubFlavored.inlineSyntaxes
      .where((s) => s is! md.InlineHtmlSyntax)
      .toList(),
);

/// Inline syntaxes to register alongside Markdown math.
final List<md.InlineSyntax> htmlInlineSyntaxes = [HtmlTagSyntax()];

/// Element builders keyed by tag for the HTML elements we emit.
Map<String, MarkdownElementBuilder> get htmlBuilders => {
  'htmlTag': HtmlTagBuilder(),
};
