import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import 'kit.dart' show Pressable;
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
  final bool editing;
  final void Function(String fromId, String toId)? onReorder;
  final void Function(String id)? onRemove;
  final double gap;
  final int startIndex; // posição na cascata de entrada
  const DashboardGrid({
    super.key,
    required this.tiles,
    required this.spans,
    required this.onSpanChanged,
    this.editing = false,
    this.onReorder,
    this.onRemove,
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

        // Empacota em linhas na ordem escolhida: cada linha comporta até [cols]
        // blocos de largura. Se a soma dos spans da linha for menor que [cols],
        // preenche o espaço lateral restante com [Expanded] vazio para que um
        // card 1x realmente ocupe meia largura e nunca mude de posição.
        int spanOf(DashTile t) =>
            (spans[t.id] ?? t.defaultSpan).clamp(1, 2).clamp(1, cols);
        final rows = <List<DashTile>>[];
        var current = <DashTile>[];
        var used = 0;
        for (final t in tiles) {
          final sp = spanOf(t);
          if (current.isNotEmpty && used + sp > cols) {
            rows.add(current);
            current = [];
            used = 0;
          }
          current.add(t);
          used += sp;
        }
        if (current.isNotEmpty) rows.add(current);

        return Column(
          children: [
            for (final row in rows) ...[
              () {
                final rowUsed = row.fold<int>(0, (s, t) => s + spanOf(t));
                final leftover = (cols - rowUsed).clamp(0, cols);
                final slots = row.length + (leftover > 0 ? 1 : 0);
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        Expanded(
                          flex: spanOf(row[i]),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: _minHeightFor(row[i].id, spanOf(row[i])),
                            ),
                            child: RepaintBoundary(
                              child: editing
                                  ? _EditableTile(
                                      key: ValueKey('edit-${row[i].id}'),
                                      id: row[i].id,
                                      span: spanOf(row[i]),
                                      canResize: cols > 1,
                                      onToggleSpan: () => onSpanChanged(
                                        row[i].id,
                                        spanOf(row[i]) == 1 ? 2 : 1,
                                      ),
                                      onRemove: onRemove == null
                                          ? null
                                          : () => onRemove!(row[i].id),
                                      onAcceptDrop: (fromId) {
                                        if (fromId != row[i].id) {
                                          HapticFeedback.selectionClick();
                                          onReorder?.call(fromId, row[i].id);
                                        }
                                      },
                                      child: row[i].builder(
                                        ctx,
                                        _innerWidth(
                                          w,
                                          gap,
                                          cols,
                                          slots,
                                          spanOf(row[i]),
                                        ),
                                        spanOf(row[i]),
                                      ),
                                    )
                                  : _Resizable(
                                      key: ValueKey(row[i].id),
                                      span: spanOf(row[i]),
                                      enabled: cols > 1,
                                      onToggle: () => onSpanChanged(
                                        row[i].id,
                                        spanOf(row[i]) == 1 ? 2 : 1,
                                      ),
                                      child: row[i].builder(
                                        ctx,
                                        _innerWidth(
                                          w,
                                          gap,
                                          cols,
                                          slots,
                                          spanOf(row[i]),
                                        ),
                                        spanOf(row[i]),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                      if (leftover > 0) ...[
                        SizedBox(width: gap),
                        Expanded(flex: leftover, child: const SizedBox()),
                      ],
                    ],
                  ),
                );
              }(),
              SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }

  static double _innerWidth(
    double w,
    double gap,
    int cols,
    int slots,
    int tileSpan,
  ) {
    return (w - gap * (slots - 1)) * tileSpan / cols - 32;
  }
}

class _EditableTile extends StatelessWidget {
  final String id;
  final int span;
  final bool canResize;
  final VoidCallback onToggleSpan;
  final VoidCallback? onRemove;
  final void Function(String fromId) onAcceptDrop;
  final Widget child;

  const _EditableTile({
    super.key,
    required this.id,
    required this.span,
    required this.canResize,
    required this.onToggleSpan,
    required this.onRemove,
    required this.onAcceptDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) => onAcceptDrop(d.data),
      builder: (ctx, candidates, _) {
        final hovered = candidates.isNotEmpty;
        final card = AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Space.radiusCard),
              side: BorderSide(
                color: hovered
                    ? c.primary
                    : c.primary.withValues(alpha: 0.42),
                width: hovered ? 2.2 : 1.2,
              ),
            ),
          ),
          child: Stack(
            children: [
              AbsorbPointer(child: child),
              if (onRemove != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Pressable(
                    semanticLabel: 'Remover card',
                    scale: 0.9,
                    onTap: onRemove,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.negative,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.minus,
                        size: 15,
                        color: Palette.neutral0,
                      ),
                    ),
                  ),
                ),
              if (canResize)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Pressable(
                    semanticLabel: 'Alternar tamanho',
                    scale: 0.9,
                    onTap: onToggleSpan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: ShapeDecoration(
                        color: c.cardAlt,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '${span}x',
                        style: T.micro.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Draggable<String>(
          data: id,
          feedback: Opacity(
            opacity: 0.88,
            child: SizedBox(
              width: span == 2 ? 300 : 168,
              child: card,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.32, child: card),
          child: card,
        );
      },
    );
  }
}

/// Altura mínima por card conforme o span (1x ou 2x).
double _minHeightFor(String id, int span) {
  if (id == 'assinaturas') return span == 1 ? 156 : 128;
  if (id == 'categorias') return span == 1 ? 156 : 140;
  if (id == 'caixinhas') return 132;
  if (id == 'contas') return 132;
  if (id == 'historico') return span == 1 ? 156 : 184;
  return _minHeight[id] ?? 132;
}

const _minHeight = <String, double>{
  'gastos': 132,
  'caixinhas': 132,
  'contas': 132,
  'categorias': 140,
  'assinaturas': 128,
  'historico': 184,
};

/// Envolve o card: segurar → háptico + "respiração" com mola ao trocar o tamanho.
class _Resizable extends StatefulWidget {
  final int span;
  final bool enabled;
  final VoidCallback onToggle;
  final Widget child;
  const _Resizable({
    super.key,
    required this.enabled,
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

  Future<void> _openResizeMenu() async {
    if (!widget.enabled || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final expand = widget.span == 1;

    HapticFeedback.mediumImpact();
    setState(() => _holding = true);

    const menuWidth = 176.0;
    const menuHeight = 52.0;

    // Posiciona ao lado do widget quando houver espaço; senão acima/abaixo alinhado à borda.
    double left;
    double top;
    if (rect.right + 10 + menuWidth <= screen.width - 12) {
      left = rect.right + 10;
      top = (rect.center.dy - menuHeight / 2).clamp(
        pad.top + 12,
        screen.height - pad.bottom - menuHeight - 12,
      );
    } else if (rect.left - 10 - menuWidth >= 12) {
      left = rect.left - 10 - menuWidth;
      top = (rect.center.dy - menuHeight / 2).clamp(
        pad.top + 12,
        screen.height - pad.bottom - menuHeight - 12,
      );
    } else {
      left = (rect.center.dx - menuWidth / 2).clamp(
        12.0,
        screen.width - menuWidth - 12.0,
      );
      top = rect.top - menuHeight - 10 >= pad.top + 12
          ? rect.top - menuHeight - 10
          : (rect.bottom + 10).clamp(
              pad.top + 12,
              screen.height - pad.bottom - menuHeight - 12,
            );
    }

    final picked = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar menu',
      barrierColor: const Color(0x38000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) {
        final c = ctx.c;
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Pressable(
                scale: 0.96,
                onTap: () => Navigator.of(ctx).pop(true),
                child: Container(
                  width: menuWidth,
                  height: menuHeight,
                  padding: const EdgeInsets.symmetric(horizontal: Space.base),
                  decoration: ShapeDecoration(
                    color: c.card,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Space.radiusField),
                      side: BorderSide(color: c.borderStrong),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x38000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        expand ? LucideIcons.maximize2 : LucideIcons.minimize2,
                        size: 18,
                        color: c.primary,
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        expand ? 'Expandir (2x)' : 'Recolher (1x)',
                        style: T.labelStrong.copyWith(
                          color: c.text,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, _, child) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: easeOutExpo,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );

    if (mounted) setState(() => _holding = false);
    if (picked == true) widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      onLongPressHint: widget.span == 1 ? 'Expandir card' : 'Recolher card',
      child: GestureDetector(
        onLongPress: _openResizeMenu,
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
                decoration: ShapeDecoration(
                  shadows: _holding
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(Space.radiusCard),
                  ),
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
