import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../l10n/app_localizations.dart';

/// A label + the LaTeX snippet it inserts into the formula source.
class _MathSym {
  final String label;
  final String snippet;
  const _MathSym(this.label, this.snippet);
}

/// A group of symbols shown under one category tab.
class _MathGroup {
  final String name;
  final List<_MathSym> symbols;
  const _MathGroup(this.name, this.symbols);
}

/// Symbol palette shown on the math insertion page. Each group becomes a tab;
/// tapping a symbol inserts its LaTeX snippet at the cursor.
const List<_MathGroup> _groups = [
  _MathGroup('常用', [
    _MathSym('a/b', r'\frac{}{}'),
    _MathSym('√', r'\sqrt{}'),
    _MathSym('xⁿ', '^{}'),
    _MathSym('xₙ', '_{}'),
    _MathSym('·', r'\cdot'),
    _MathSym('±', r'\pm'),
    _MathSym('×', r'\times'),
    _MathSym('÷', r'\div'),
    _MathSym('≠', r'\neq'),
    _MathSym('≈', r'\approx'),
    _MathSym('∞', r'\infty'),
    _MathSym('%', r'\pmod{}'),
  ]),
  _MathGroup('希腊', [
    _MathSym('α', r'\alpha'),
    _MathSym('β', r'\beta'),
    _MathSym('γ', r'\gamma'),
    _MathSym('δ', r'\delta'),
    _MathSym('ε', r'\epsilon'),
    _MathSym('θ', r'\theta'),
    _MathSym('λ', r'\lambda'),
    _MathSym('μ', r'\mu'),
    _MathSym('π', r'\pi'),
    _MathSym('ρ', r'\rho'),
    _MathSym('σ', r'\sigma'),
    _MathSym('τ', r'\tau'),
    _MathSym('φ', r'\phi'),
    _MathSym('ω', r'\omega'),
    _MathSym('Γ', r'\Gamma'),
    _MathSym('Δ', r'\Delta'),
    _MathSym('Θ', r'\Theta'),
    _MathSym('Λ', r'\Lambda'),
    _MathSym('Σ', r'\Sigma'),
    _MathSym('Φ', r'\Phi'),
    _MathSym('Ω', r'\Omega'),
  ]),
  _MathGroup('运算', [
    _MathSym('∑', r'\sum'),
    _MathSym('∏', r'\prod'),
    _MathSym('∫', r'\int'),
    _MathSym('∮', r'\oint'),
    _MathSym('lim', r'\lim'),
    _MathSym('∂', r'\partial'),
    _MathSym('∇', r'\nabla'),
    _MathSym('∐', r'\bigoplus'),
    _MathSym('⋂', r'\bigcap'),
    _MathSym('⋃', r'\bigcup'),
  ]),
  _MathGroup('关系', [
    _MathSym('≤', r'\leq'),
    _MathSym('≥', r'\geq'),
    _MathSym('≡', r'\equiv'),
    _MathSym('∈', r'\in'),
    _MathSym('∉', r'\notin'),
    _MathSym('⊂', r'\subset'),
    _MathSym('⊃', r'\supset'),
    _MathSym('⊆', r'\subseteq'),
    _MathSym('⊇', r'\supseteq'),
    _MathSym('∀', r'\forall'),
    _MathSym('∃', r'\exists'),
    _MathSym('∝', r'\propto'),
  ]),
  _MathGroup('括号', [
    _MathSym('( )', r'\left(  \right)'),
    _MathSym('[ ]', r'\left[  \right]'),
    _MathSym('{ }', r'\left\{  \right\}'),
    _MathSym('⌊⌋', r'\lfloor  \rfloor'),
    _MathSym('⌈⌉', r'\lceil  \rceil'),
    _MathSym('⟨⟩', r'\langle  \rangle'),
  ]),
  _MathGroup('箭头', [
    _MathSym('→', r'\rightarrow'),
    _MathSym('←', r'\leftarrow'),
    _MathSym('⇒', r'\Rightarrow'),
    _MathSym('⇐', r'\Leftarrow'),
    _MathSym('↔', r'\leftrightarrow'),
    _MathSym('↦', r'\mapsto'),
    _MathSym('⟹', r'\implies'),
    _MathSym('⇔', r'\iff'),
  ]),
  _MathGroup('修饰', [
    _MathSym('x̂', r'\hat{}'),
    _MathSym('x̄', r'\bar{}'),
    _MathSym('x⃗', r'\vec{}'),
    _MathSym('ẋ', r'\dot{}'),
    _MathSym('x̃', r'\tilde{}'),
    _MathSym('x̅', r'\overline{}'),
    _MathSym('x̲', r'\underline{}'),
    _MathSym('ⁿCᵣ', r'\binom{}{}'),
  ]),
];

/// A dedicated page for composing a LaTeX formula. The bottom toolbar shows
/// categories of LaTeX symbols; tapping one inserts it into the source field,
/// which is rendered live above. "Insert" returns the wrapped formula.
class MathInsertScreen extends StatefulWidget {
  const MathInsertScreen({super.key});

  @override
  State<MathInsertScreen> createState() => _MathInsertScreenState();
}

class _MathInsertScreenState extends State<MathInsertScreen> {
  final TextEditingController _src = TextEditingController();
  int _groupIndex = 0;
  bool _block = false;

  @override
  void initState() {
    super.initState();
    _src.addListener(_onChanged);
  }

  @override
  void dispose() {
    _src.removeListener(_onChanged);
    _src.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Insert a LaTeX snippet at the cursor, placing the caret inside the first
  /// empty `{}` when present (so the user types the argument directly).
  void _insertSymbol(String snippet) {
    final sel = _src.selection;
    final text = _src.text;
    final newText = text.replaceRange(sel.start, sel.end, snippet);
    var caret = sel.start + snippet.length;
    final brace = snippet.indexOf(r'{}');
    if (brace >= 0) caret = sel.start + brace + 1;
    _src.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _insertIntoNote() {
    final tex = _src.text.trim();
    if (tex.isEmpty) return;
    final prefix = _block ? '\n\$\$\n' : '\$';
    final suffix = _block ? '\n\$\$\n' : '\$';
    Navigator.pop(context, '$prefix$tex$suffix');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = _groups[_groupIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('math')),
        actions: [
          IconButton(
            icon: Icon(_block ? Icons.view_agenda : Icons.text_fields),
            tooltip: l10n.t('mathBlock'),
            onPressed: () => setState(() => _block = !_block),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.t('insertMath'),
            onPressed: _insertIntoNote,
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: _src.text.trim().isEmpty
                  ? Text(
                      l10n.t('mathFormulaHint'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : _buildPreview(),
            ),
          ),
          const Divider(height: 1),
          // Source editor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _src,
              decoration: InputDecoration(
                hintText: l10n.t('mathSource'),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText: _block ? r'$$ $$' : r'$ $',
              ),
              autofocus: true,
            ),
          ),
          const Divider(height: 1),
          // Bottom LaTeX symbol toolbar
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // Category tabs
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _groups.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) => ChoiceChip(
                      label: Text(_groups[i].name),
                      selected: i == _groupIndex,
                      onSelected: (_) => setState(() => _groupIndex = i),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Symbol buttons
                SizedBox(
                  height: 132,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: group.symbols
                          .map(
                            (s) => ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(40, 36),
                              ),
                              onPressed: () => _insertSymbol(s.snippet),
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    try {
      return Math.tex(
        _src.text.trim(),
        mathStyle: _block ? MathStyle.display : MathStyle.text,
        textStyle: const TextStyle(fontSize: 22),
      );
    } catch (_) {
      return Text(
        AppLocalizations.of(context)!.t('mathInvalid'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
  }
}
