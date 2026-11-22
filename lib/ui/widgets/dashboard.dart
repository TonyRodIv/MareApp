import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'motion.dart';

/// Um card da Carteira. [builder] recebe a largura interna real e o span
/// atual, para o conteúdo se reorganizar (estreito × largo).
class DashTile {
  final String id;
  final int defaultSpan;
  final Widget Function(BuildContext context, double innerWidth, int span) builder;
  const DashTile({required this.id, required this.builder, this.defaultSpan = 1});
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

  static int columnsFor(double width) => width >= 1000 ? 6 : (width >= 560 ? 4 : 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        final cols = columnsFor(w);
        final unit = (w - gap * (cols - 1)) / cols;
        double widthOf(int span) => unit * span + gap * (span - 1);

        // Empacota os cards em linhas, mantendo a ordem.
        final rows = <List<(DashTile, int)>>[];
        var current = <(DashTile, int)>[];
        var used = 0;
        for (final t in tiles) {
          final span = (spans[t.id] ?? t.defaultSpan).clamp(1, 2);
          if (used + span > cols) {
            rows.add(current);
            current = [];
            used = 0;
          }
          current.add((t, span));
          used += span;
        }
        if (current.isNotEmpty) rows.add(current);

        return Column(
          children: [
            for (final row in rows) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      SizedBox(
                        width: widthOf(row[i].$2),
                        child: RepaintBoundary(
                          child: _Resizable(
                            key: ValueKey(row[i].$1.id),
                            span: row[i].$2,
                            onToggle: () => onSpanChanged(row[i].$1.id, row[i].$2 == 1 ? 2 : 1),
                            child: row[i].$1.builder(ctx, widthOf(row[i].$2) - 32, row[i].$2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}

/// Envolve o card: segurar → háptico + "respiração" com mola ao trocar o tamanho.
class _Resizable extends StatefulWidget {
  final int span;
  final VoidCallback onToggle;
  final Widget child;
  const _Resizable({super.key, required this.span, required this.onToggle, required this.child});
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
              scaleY: 1 - (1 - t) * 0.4, // estica na horizontal, como a gota do fluid
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Space.radiusCard),
                  boxShadow: _holding ? [BoxShadow(color: c.accent.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 1)] : null,
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
