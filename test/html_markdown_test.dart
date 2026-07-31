import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/markdown/html_markdown.dart';
import 'package:free_note/markdown/math_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Pull a single inline HTML element out of a parsed document by its data-tag.
md.Element _parseHtmlTag(String line, String expectedTag) {
  final document = md.Document(
    extensionSet: htmlFriendlyExtensionSet,
    inlineSyntaxes: htmlInlineSyntaxes,
  );
  final nodes = document.parseLines([line]);

  md.Element? found;
  void visit(dynamic node) {
    if (node is md.Element) {
      final tag = node.attributes['data-tag'];
      if (tag == expectedTag) {
        found ??= node;
      }
      node.children?.forEach(visit);
    } else if (node is List) {
      node.forEach(visit);
    }
  }

  nodes.forEach(visit);
  expect(found, isNotNull, reason: 'no <$expectedTag> element parsed');
  return found!;
}

void main() {
  group('parseColor', () {
    test('hex short / long / with alpha', () {
      expect(parseColor('#f00'), equals(const Color(0xFFFF0000)));
      expect(parseColor('#00ff00'), equals(const Color(0xFF00FF00)));
      expect(parseColor('#0000ff80'), equals(const Color(0x0000FF80)));
      expect(parseColor('  #ABC  '), equals(const Color(0xFFAABBCC)));
    });
    test('rgb / rgba', () {
      expect(parseColor('rgb(255, 0, 0)'), equals(const Color(0xFFFF0000)));
      expect(
        parseColor('rgba(0, 128, 0, 0.5)'),
        equals(const Color(0x80008000)),
      );
    });
    test('named colors', () {
      expect(parseColor('red'), equals(const Color(0xFFFF0000)));
      expect(parseColor('BLUE'), equals(const Color(0xFF0000FF)));
      expect(parseColor('grey'), equals(const Color(0xFF808080)));
    });
    test('invalid → null', () {
      expect(parseColor(null), isNull);
      expect(parseColor(''), isNull);
      expect(parseColor('notacolor'), isNull);
      expect(parseColor('#12'), isNull);
    });
  });

  group('HtmlTagSyntax — inline HTML parsing', () {
    test('<font color> keeps color attribute and inner text', () {
      final el = _parseHtmlTag('<font color="red">hello</font>', 'font');
      expect(el.attributes['color'], equals('red'));
      expect(el.textContent, equals('hello'));
    });

    test('<font color face size> captures all three attributes', () {
      final el = _parseHtmlTag(
        "<font color='#00ff00' face='serif' size='5'>x</font>",
        'font',
      );
      expect(el.attributes['color'], equals('#00ff00'));
      expect(el.attributes['face'], equals('serif'));
      expect(el.attributes['size'], equals('5'));
    });

    test('<b> and <i> parse as their semantic tags', () {
      expect(_parseHtmlTag('<b>bold</b>', 'b').textContent, equals('bold'));
      expect(_parseHtmlTag('<i>italic</i>', 'i').textContent, equals('italic'));
    });

    test('<span style> keeps the raw style string', () {
      final el = _parseHtmlTag('<span style="color: blue">t</span>', 'span');
      expect(el.attributes['style'], equals('color: blue'));
      expect(el.textContent, equals('t'));
    });

    test('<a href> keeps the link target', () {
      final el = _parseHtmlTag('<a href="https://example.com">link</a>', 'a');
      expect(el.attributes['href'], equals('https://example.com'));
    });

    test('plain markdown is untouched — no false htmlTag node', () {
      final document = md.Document(
        extensionSet: htmlFriendlyExtensionSet,
        inlineSyntaxes: htmlInlineSyntaxes,
      );
      final nodes = document.parseLines(['**bold** and `code`']);
      var sawHtmlTag = false;
      void visit(dynamic n) {
        if (n is md.Element) {
          if (n.attributes['data-tag'] != null) sawHtmlTag = true;
          n.children?.forEach(visit);
        }
      }

      nodes.forEach(visit);
      expect(sawHtmlTag, isFalse);
    });
  });

  group('HtmlTagBuilder — widget rendering', () {
    Future<Text> renderText(WidgetTester tester, String data) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: safeMarkdown(data: data, selectable: false)),
        ),
      );
      return tester.widget<Text>(find.text('hi'));
    }

    testWidgets('<font color="red"> renders red Text', (tester) async {
      final text = await renderText(tester, '<font color="red">hi</font>');
      expect(text.style?.color, equals(const Color(0xFFFF0000)));
    });

    testWidgets('<font color="#00ff00"> renders green Text', (tester) async {
      final text = await renderText(tester, '<font color="#00ff00">hi</font>');
      expect(text.style?.color, equals(const Color(0xFF00FF00)));
    });

    testWidgets('<b> renders bold Text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: safeMarkdown(data: '<b>hi</b>', selectable: false),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('hi'));
      expect(text.style?.fontWeight, equals(FontWeight.bold));
    });
  });
}
