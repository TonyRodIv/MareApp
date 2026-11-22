import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/color_engine.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import 'motion.dart';

/// Células que acendem em cascata com mola (base dos gráficos "waffle").
class _Cell extends StatelessWidget {
  final Color color;
  final int index;
  final double size;
  final double radius;
  const _Cell({
    required this.color,
    required this.index,
    required this.size,
    this.radius = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 6),
      curve: Interval(
        math.min(0.8, index * 0.006),
        1,
        curve: Curves.easeOutBack,
      ),
      builder: (_, t, _) => Transform.scale(
        scale: 0.4 + 0.6 * t,
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ),
    );
  }
}

/// [width] explícito permite medir altura intrínseca (grade da Carteira);
/// sem ele, usa a largura disponível.
Widget _grid(List<Color> colors, int columns, {double gap = 3, double? width}) {
  Widget build(double w) {
    final size = (w - gap * (columns - 1)) / columns;
    return SizedBox(
      width: w,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < colors.length; i++)
            _Cell(color: colors[i], index: i, size: size, radius: size * 0.22),
        ],
      ),
    );
  }

  if (width != null) return build(width);
  return LayoutBuilder(builder: (ctx, box) => build(box.maxWidth));
}

/// Tons da cor destaque escolhida para as 3 maiores categorias + neutro para o resto.
List<Color> categoryShades(AppColors c) {
  final s = scaleFor(c.seed);
  return c.isDark ? [s.s500, s.s300, s.s100] : [s.s700, s.s500, s.s200];
}

/// Waffle 10×10 das categorias (cada célula ≈ 1%).
class CategoryWaffle extends StatelessWidget {
  final List<MapEntry<Category, Cents>> data;
  final double? width;
  const CategoryWaffle({super.key, required this.data, this.width});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = data.fold<int>(0, (s, e) => s + math.max(0, e.value));
    final shades = categoryShades(c);
    final cells = <Color>[];
    if (total > 0) {
      for (var i = 0; i < data.length && i < 3; i++) {
        final n = (data[i].value / total * 100).round();
        cells.addAll(List.filled(n, shades[i]));
      }
    }
    while (cells.length < 100) {
      cells.add(c.emptyCell);
    }
    return _grid(cells.take(100).toList(), 10, gap: 3, width: width);
  }
}

/// Calendário do ciclo: um quadrado por dia. Passado = intensidade do gasto,
/// hoje = laranja, futuro = vazio. [highlight] destaca dias (fim de semana).
class CycleGrid extends StatelessWidget {
  final Finance f;
  final Set<DateTime> highlight;
  final int columns;
  final double? width;
  const CycleGrid({
    super.key,
    required this.f,
    this.highlight = const {},
    this.columns = 8,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = dateOnly(f.now);
    final days = f.current.days;
    final cells = <Color>[];
    for (final d in days) {
      if (sameDay(d, today)) {
        cells.add(c.accentWarm);
      } else if (highlight.any((h) => sameDay(h, d))) {
        cells.add(c.accentWarm.withValues(alpha: 0.55));
      } else if (d.isAfter(today)) {
        cells.add(c.emptyCell);
      } else {
        final r = f.dayRatio(d);
        cells.add(_dayColor(c, r));
      }
    }
    while (cells.length % columns != 0) {
      cells.add(c.emptyCell.withValues(alpha: 0.4));
    }
    return _grid(cells, columns, gap: 4, width: width);
  }

  static Color _dayColor(AppColors c, double r) {
    // não gastou: o mais claro
    if (r <= 0) return c.isDark ? Palette.teal100 : Palette.teal200;
    if (r <= 0.6) return c.isDark ? Palette.teal350 : Palette.teal550;
    if (r <= 1.0) return c.isDark ? Palette.teal550 : Palette.teal750;
    return c.isDark
        ? const Color(0xFF5B8087)
        : Palette.neutral400; // estourou a meta
  }
}

/// Linha Dom..Sáb com raio para cada dia dentro da meta (sequência).
class WeekStreak extends StatelessWidget {
  final Finance f;
  final double? width;
  const WeekStreak({super.key, required this.f, this.width});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = dateOnly(f.now);
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    const labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final dot = width == null ? 34.0 : ((width! - 6 * 3) / 7).clamp(20.0, 40.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final d = DateTime(sunday.year, sunday.month, sunday.day + i);
        final future = d.isAfter(today);
        final ok = !future && f.dayOnTrack(d);
        final isToday = sameDay(d, today);
        return Column(
          children: [
            SpringBuilder(
              value: 1,
              from: 0,
              spring: Springs.bouncy,
              builder: (_, t, _) => Transform.scale(
                scale: 0.6 + 0.4 * t.clamp(0.0, 1.2),
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok
                        ? (c.isDark ? Palette.orange900 : Palette.orange250)
                        : c.cardAlt,
                    border: isToday
                        ? Border.all(color: c.accentWarm, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    future ? LucideIcons.zapOff : LucideIcons.zap,
                    size: dot * 0.47,
                    color: ok
                        ? (c.isDark ? Palette.orange400 : Palette.orange900)
                        : c.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dot < 28 ? labels[i].substring(0, 1) : labels[i],
              style: T.small.copyWith(color: c.textSecondary),
            ),
          ],
        );
      }),
    );
  }
}

/// Bolhas de assinaturas (tamanho ∝ valor).
class SubscriptionBubbles extends StatelessWidget {
  final List<Expense> subs;
  final bool hidden;
  final double? width;
  const SubscriptionBubbles({
    super.key,
    required this.subs,
    this.hidden = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = subs.take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxV = top.first.cents.toDouble();
    // posições fixas parecidas com o Figma
    const spots = [
      Offset(0.30, 0.55),
      Offset(0.66, 0.24),
      Offset(0.84, 0.62),
      Offset(0.58, 0.82),
    ];
    final colors = [
      c.primary,
      c.isDark ? Palette.teal950 : Palette.teal200,
      c.isDark ? Palette.teal900 : Palette.teal100,
      c.secondary,
    ];
    Widget build(double w) {
      const h = 120.0;
      return SizedBox(
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < top.length; i++)
              () {
                final d = 44 + 50 * math.sqrt(top[i].cents / maxV);
                final p = spots[i];
                return Positioned(
                  left: (p.dx * w - d / 2).clamp(0.0, w - d),
                  top: (p.dy * h - d / 2).clamp(0.0, h - d),
                  child: SpringBuilder(
                    value: 1,
                    from: 0,
                    spring: Springs.bouncy,
                    builder: (_, t, _) => Transform.scale(
                      scale: t.clamp(0.0, 1.3),
                      child: Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              top[i].category.icon,
                              size: d > 60 ? 16 : 13,
                              color: i == 3 ? c.accentWarm : c.onPrimary,
                            ),
                            if (d > 54)
                              Text(
                                hidden
                                    ? '•••'
                                    : fmtMoney(
                                        top[i].cents,
                                      ).replaceAll('R\$ ', 'R\$'),
                                style: T.tiny.copyWith(
                                  color: c.isDark || i == 0
                                      ? Palette.neutral0
                                      : Palette.neutral800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      );
    }

    if (width != null) return SizedBox(width: width, child: build(width!));
    return LayoutBuilder(builder: (ctx, box) => build(box.maxWidth));
  }
}

/// Histórico: barras empilhadas (fixo embaixo, dia a dia em cima) por ciclo.
class HistoryBars extends StatelessWidget {
  final Finance f;
  final int cycles;
  final double height;
  final bool hidden;
  const HistoryBars({
    super.key,
    required this.f,
    this.cycles = 6,
    this.height = 160,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = f.lastCycles(cycles);
    final fixed = [
      for (final cy in list) f.fixedTotal(cy) + f.contributionsTotal(cy),
    ];
    final variable = [for (final cy in list) f.variableTotal(cy)];
    final maxV = math.max(
      1,
      List.generate(
        list.length,
        (i) => fixed[i] + variable[i],
      ).fold<int>(0, math.max),
    );
    final ticks = _niceTicks(maxV);
    final top = ticks.last;
    final dark = c.primary;
    final light = c.primary.withValues(alpha: c.isDark ? 0.45 : 0.35);
    return SizedBox(
      height: height + 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final t in ticks)
                  Positioned(
                    bottom: (height - 16) * t / top,
                    left: 0,
                    child: Text(
                      hidden ? '•' : fmtCompact(t),
                      style: T.tiny.copyWith(color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SpringBuilder(
                              value: 1,
                              from: 0,
                              spring: Springs.settle,
                              builder: (_, t, _) {
                                final k = t.clamp(0.0, 1.1);
                                // OverflowBox: o overshoot da mola (k > 1) pode passar da altura sem estourar o Column.
                                return OverflowBox(
                                  alignment: Alignment.bottomCenter,
                                  minHeight: 0,
                                  maxHeight: double.infinity,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        height: height * variable[i] / top * k,
                                        decoration: BoxDecoration(
                                          color: light,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(5),
                                              ),
                                        ),
                                      ),
                                      Container(
                                        height: height * fixed[i] / top * k,
                                        decoration: BoxDecoration(
                                          color: dark,
                                          borderRadius: variable[i] == 0
                                              ? const BorderRadius.vertical(
                                                  top: Radius.circular(5),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final cy in list)
                      Expanded(
                        child: Text(
                          cy.shortLabel(),
                          textAlign: TextAlign.center,
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<int> _niceTicks(int maxCents) {
    final maxReais = maxCents / 100;
    final raw = maxReais / 3;
    final mag = math
        .pow(10, (math.log(math.max(raw, 1)) / math.ln10).floor())
        .toDouble();
    final step = ([
      1,
      2,
      2.5,
      5,
      10,
    ].map((m) => m * mag).firstWhere((s) => s >= raw, orElse: () => 10 * mag));
    return [for (var i = 0; i <= 3; i++) (step * i * 100).round()];
  }
}

/// Gastos por dia da semana (Dom–Sáb). A barra mais alta começa selecionada e
/// qualquer barra pode ser tocada; a selecionada fica escura e mostra o valor.
class WeekdayBars extends StatefulWidget {
  final List<Cents> values; // 7 itens, Dom..Sáb
  final bool hidden;
  const WeekdayBars({super.key, required this.values, this.hidden = false});

  @override
  State<WeekdayBars> createState() => _WeekdayBarsState();
}

class _WeekdayBarsState extends State<WeekdayBars> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = widget.values;
    final maxV = v.fold<int>(0, math.max);
    var top = 0;
    for (var i = 1; i < 7; i++) {
      if (v[i] > v[top]) top = i;
    }
    final sel = _sel ?? top;
    const labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    const barH = 110.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _sel = i),
              child: Column(
                children: [
                  SizedBox(
                    height: 30,
                    child: i == sel && v[i] > 0
                        ? OverflowBox(
                            maxWidth: 96,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.accentWarm,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.hidden
                                    ? '•••'
                                    : 'R\$${fmtCompact(v[i])}',
                                style: T.tiny.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: onColor(c.accentWarm),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barH,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: c.cardAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SpringBuilder(
                      value: maxV == 0 ? 0 : v[i] / maxV,
                      from: 0,
                      spring: Springs.settle,
                      builder: (_, t, _) => Container(
                        height: math.max(14.0, barH * t.clamp(0.0, 1.05)),
                        decoration: BoxDecoration(
                          color: i == sel ? c.text : c.borderStrong,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: T.tiny.copyWith(
                      color: i == sel ? c.text : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
