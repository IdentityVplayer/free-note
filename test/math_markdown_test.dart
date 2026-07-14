import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:free_note/markdown/math_markdown.dart';

List<md.Element> _findAllElements(List<md.Node> nodes, String tag) {
  final result = <md.Element>[];
  void walk(List<md.Node> ns) {
    for (final n in ns) {
      if (n is md.Element) {
        if (n.tag == tag) result.add(n);
        walk(n.children ?? const []);
      }
    }
  }

  walk(nodes);
  return result;
}

void main() {
  late md.Document doc;

  setUp(() {
    doc = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: mathInlineSyntaxes,
      blockSyntaxes: mathBlockSyntaxes,
    );
  });

  test('inline LaTeX is parsed into a math element', () {
    final nodes = doc.parse('能量公式 \$E=mc^2\$ 很重要。');
    final maths = _findAllElements(nodes, 'math');
    expect(maths, isNotEmpty);
    expect(maths.first.textContent, 'E=mc^2');
  });

  test('block LaTeX is parsed into a mathBlock element', () {
    final nodes = doc.parse(r'$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$');
    final blocks = _findAllElements(nodes, 'mathBlock');
    expect(blocks, isNotEmpty);
    expect(blocks.first.textContent, r'\sum_{i=1}^{n} i = \frac{n(n+1)}{2}');
  });

  test('multiple inline formulas on one line', () {
    final nodes = doc.parse(r'$a$ and $b$');
    final maths = _findAllElements(nodes, 'math');
    expect(maths.length, 2);
  });

  test('multiline block LaTeX is captured', () {
    final nodes = doc.parse(
      r'$$'
      '\n'
      r'\int_0^1 x^2 \, dx'
      '\n'
      r'$$',
    );
    final blocks = _findAllElements(nodes, 'mathBlock');
    expect(blocks, isNotEmpty);
    expect(blocks.first.textContent, r'\int_0^1 x^2 \, dx');
  });
}
