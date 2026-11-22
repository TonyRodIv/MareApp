import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'motion.dart';

/// Um card da Carteira. [builder] recebe a largura interna real e o span
/// atual, para o conteúdo se reorganizar (estreito × largo).
class DashTile {
  final String id;
  final int defaultSpan;
  final Widget Function(BuildContext context, double innerWidth, int span)
  builder;
  const DashTile({
    required this.id,
    required this.builder,
    this.defaultSpan = 1,
  });
}

/// Grade adaptável: 2 colunas no celular, 4 no tablet, 6 em telas grandes.
/// Segurar um card alterna entre 1 e 2 blocos de largura (com mola).
class DashboardGrid extends StatelessWidget {
  final List<DashTile> tiles;
  final Map<String, int> spans;
  final void Function(String id, int span) onSpanChanged;
  final double gap;
  final int startIndex; // posição na cascata de entrada
  const DashboardGrid({
    super.key,
    required this.tiles,
    required this.spans,
    required this.onSpanChanged,
    this.gap = 10,
    this.startIndex = 0,
  });

  static int columnsFor(double width) =>
      width >= 1000 ? 6 : (width >= 560 ? 4 : 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        final cols = columnsFor(w);
        final unit = (w - gap * (cols - 1)) / cols;
        double widthOf(int span) => unit * span + gap * (span - 1);

        // Alvenaria: cada card vai para a faixa de colunas mais baixa naquele
        // momento, mantendo a ordem. Cada card tem a altura que o conteúdo pede,
        // então nada estica nem sobra espaço vazio dentro dos cards.
        final spanOf = [
          for (final t in tiles)
            (spans[t.id] ?? t.defaultSpan).clamp(1, 2).clamp(1, cols),
        ];
        return _Masonry(
          columns: cols,
          gap: gap,
          spans: spanOf,
          children: [
            for (var i = 0; i < tiles.length; i++)
              RepaintBoundary(
                key: ValueKey('tile-${tiles[i].id}'),
                child: _Resizable(
                  span: spanOf[i],
                  onToggle: () =>
                      onSpanChanged(tiles[i].id, spanOf[i] == 1 ? 2 : 1),
                  child: tiles[i].builder(
                    ctx,
                    widthOf(spanOf[i]) - 32,
                    spanOf[i],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Masonry extends MultiChildRenderObjectWidget {
  final int columns;
  final double gap;
  final List<int> spans;
  const _Masonry({
    required this.columns,
    required this.gap,
    required this.spans,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMasonry(columns, gap, spans);

  @override
  void updateRenderObject(BuildContext context, _RenderMasonry renderObject) {
    renderObject
      ..columns = columns
      ..gap = gap
      ..spans = spans;
  }
}

class _MasonryParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMasonry extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MasonryParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MasonryParentData> {
  _RenderMasonry(this._columns, this._gap, this._spans);

  int _columns;
  double _gap;
  List<int> _spans;

  set columns(int v) {
    if (v == _columns) return;
    _columns = v;
    markNeedsLayout();
  }

  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  set spans(List<int> v) {
    _spans = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryParentData)
      child.parentData = _MasonryParentData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final unit = (w - _gap * (_columns - 1)) / _columns;
    final heights = List<double>.filled(_columns, 0);
    var child = firstChild;
    var i = 0;
    while (child != null) {
      final span = (i < _spans.length ? _spans[i] : 1).clamp(1, _columns);
      var bestCol = 0;
      var bestY = double.infinity;
      for (var j = 0; j <= _columns - span; j++) {
        var y = 0.0;
        for (var k = j; k < j + span; k++) {
          if (heights[k] > y) y = heights[k];
        }
        if (y < bestY - 0.5) {
          bestY = y;
          bestCol = j;
        }
      }
      final cw = unit * span + _gap * (span - 1);
      child.layout(BoxConstraints.tightFor(width: cw), parentUsesSize: true);
      (child.parentData! as _MasonryParentData).offset = Offset(
        bestCol * (unit + _gap),
        bestY,
      );
      for (var k = bestCol; k < bestCol + span; k++) {
        heights[k] = bestY + child.size.height + _gap;
      }
      child = childAfter(child);
      i++;
    }
    var h = 0.0;
    for (final x in heights) {
      if (x > h) h = x;
    }
    size = constraints.constrain(Size(w, h > 0 ? h - _gap : 0));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      Size(constraints.maxWidth, 0);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Envolve o card: segurar → háptico + "respiração" com mola ao trocar o tamanho.
class _Resizable extends StatefulWidget {
  final int span;
  final VoidCallback onToggle;
  final Widget child;
  const _Resizable({
    required this.span,
    required this.onToggle,
    required this.child,
  });
  @override
  State<_Resizable> createState() => _ResizableState();
}

class _ResizableState extends State<_Resizable> {
  bool _holding = false;
  int _pulse = 0;

  @override
  void didUpdateWidget(_Resizable old) {
    super.didUpdateWidget(old);
    if (old.span != widget.span) _pulse++;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      onLongPressHint: widget.span == 1 ? 'Expandir card' : 'Diminuir card',
      child: GestureDetector(
        onLongPressStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _holding = true);
          widget.onToggle();
        },
        onLongPressEnd: (_) => setState(() => _holding = false),
        onLongPressCancel: () => setState(() => _holding = false),
        child: SpringBuilder(
          key: ValueKey(_pulse),
          value: 1,
          from: _pulse == 0 ? 1 : 0.9,
          spring: Springs.bouncy,
          builder: (_, t, _) => AnimatedScale(
            scale: _holding ? 0.97 : 1,
            duration: const Duration(milliseconds: 160),
            child: Transform.scale(
              scaleX: t,
              scaleY:
                  1 -
                  (1 - t) * 0.4, // estica na horizontal, como a gota do fluid
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Space.radiusCard),
                  boxShadow: _holding
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// usado no rodapé da Carteira
class DashHint extends StatelessWidget {
  const DashHint({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      'Segure um card para deixá-lo mais largo ou mais estreito.',
      textAlign: TextAlign.center,
      style: T.small.copyWith(color: context.c.textTertiary),
    ),
  );
}
