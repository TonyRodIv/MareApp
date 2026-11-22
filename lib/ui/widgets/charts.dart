import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/color_engine.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import 'kit.dart' show MoneyText, Pressable;
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
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
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
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
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

/// Escala monocromática na cor do tema (OKLCH) com passos bem espaçados em
/// luminosidade, da categoria de maior gasto até a menor.
List<Color> categoryMonochromeColors(AppColors c, int count) {
  if (count <= 0) return const [];
  if (count == 1) return [c.primary];
  final seed = toOklch(c.seed);
  final peak = math.max(seed.c, 0.055);
  final startL = c.isDark ? 0.80 : 0.38;
  final endL = c.isDark ? 0.34 : 0.80;
  return List<Color>.generate(count, (i) {
    final t = i / (count - 1);
    final l = startL + (endL - startL) * t;
    final bell = (1 - math.pow((l - 0.60) / 0.52, 2))
        .clamp(0.32, 1.0)
        .toDouble();
    return fromOklch(l, peak * bell, seed.h);
  });
}

/// Waffle 10×10 das categorias (cada célula = 1%).
/// Pintado no sentido monocromático da cor do tema (`categoryMonochromeColors`).
/// Quando [maxCategories] é definido (ex.: 3 no card da Carteira), o restante
/// fica como `c.emptyCell` (correspondendo à linha "Outros").
class CategoryWaffle extends StatelessWidget {
  final List<MapEntry<Category, Cents>> data;
  final double? width;
  final int? maxCategories;
  const CategoryWaffle({
    super.key,
    required this.data,
    this.width,
    this.maxCategories,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final positive = [
      for (final e in data)
        if (e.value > 0) e,
    ];
    final total = positive.fold<int>(0, (s, e) => s + e.value);
    final cells = <Color>[];
    if (total > 0) {
      final limit = maxCategories == null
          ? positive.length
          : math.min(maxCategories!, positive.length);
      final shown = positive.take(limit).toList();
      final mono = categoryMonochromeColors(c, shown.length);
      if (limit == positive.length) {
        // Distribui exatamente 100 células pelo método do maior resto.
        final exact = [for (final e in shown) e.value / total * 100.0];
        final counts = [
          for (final x in exact) x > 0 && x < 1 ? 1 : x.floor(),
        ];
        var sum = counts.fold<int>(0, (a, b) => a + b);
        final order = List<int>.generate(shown.length, (i) => i)
          ..sort((a, b) => (exact[b] - exact[b].floor())
              .compareTo(exact[a] - exact[a].floor()));
        for (var k = 0; sum < 100 && k < order.length; k++) {
          counts[order[k]]++;
          sum++;
        }
        for (var k = order.length - 1; sum > 100 && k >= 0; k--) {
          final idx = order[k];
          if (counts[idx] > 1) {
            counts[idx]--;
            sum--;
          }
        }
        for (var i = 0; i < shown.length; i++) {
          cells.addAll(List.filled(counts[i], mono[i]));
        }
      } else {
        for (var i = 0; i < shown.length; i++) {
          final n = (shown[i].value / total * 100).round().clamp(1, 100);
          cells.addAll(List.filled(n, mono[i]));
        }
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
    final pal = c.palette.primary;
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
        cells.add(_dayColor(c, pal, r));
      }
    }
    while (cells.length % columns != 0) {
      cells.add(c.emptyCell.withValues(alpha: 0.4));
    }
    return _grid(cells, columns, gap: 4, width: width);
  }

  /// Intensidade do dia pela escala da cor do tema: quanto mais perto da meta, mais
  /// forte o tom; passou da meta vira o cinza terciário.
  static Color _dayColor(AppColors c, TonalScale p, double r) {
    if (r <= 0) return c.isDark ? p[200] : p[200];
    if (r <= 0.6) return c.isDark ? p[400] : p[400];
    if (r <= 1.0) return c.isDark ? p[500] : p[700];
    return c.textTertiary;
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
                        ? (c.isDark
                              ? c.palette.companion[900]
                              : c.palette.companion[100])
                        : c.cardAlt,
                    border: isToday
                        ? Border.all(color: c.accentWarm, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    future ? LucideIcons.zapOff : LucideIcons.zap,
                    size: dot * 0.47,
                    color: ok
                        ? (c.isDark
                              ? c.palette.companion[400]
                              : c.palette.companion[700])
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

/// Bolhas proporcionais de assinaturas (tamanho ∝ √valor).
/// Usa a paleta OKLCH ativa com contraste automático, logo da marca (ou ícone
/// contextual) em círculo limpo e tipografia tabular escalável sem cortes.
class SubscriptionBubbles extends StatelessWidget {
  final List<Expense> subs;
  final bool hidden;
  final double? width;
  final double height;
  final ValueChanged<Expense>? onSelect;
  const SubscriptionBubbles({
    super.key,
    required this.subs,
    this.hidden = false,
    this.width,
    this.height = 148,
    this.onSelect,
  });

  static IconData _serviceIcon(Expense e) {
    final n = e.name.toLowerCase();
    if (n.contains('spotify') ||
        n.contains('deezer') ||
        n.contains('music') ||
        n.contains('tidal')) {
      return LucideIcons.music;
    }
    if (n.contains('icloud') ||
        n.contains('drive') ||
        n.contains('one') ||
        n.contains('dropbox') ||
        n.contains('cloud')) {
      return LucideIcons.cloud;
    }
    if (n.contains('gpt') ||
        n.contains('claude') ||
        n.contains('gemini') ||
        n.contains('openai') ||
        n.contains('copilot')) {
      return LucideIcons.sparkles;
    }
    if (n.contains('game') ||
        n.contains('xbox') ||
        n.contains('playstation') ||
        n.contains('nintendo') ||
        n.contains('steam')) {
      return LucideIcons.gamepad2;
    }
    if (n.contains('academia') ||
        n.contains('smartfit') ||
        n.contains('gym') ||
        n.contains('wellhub') ||
        n.contains('totalpass')) {
      return LucideIcons.dumbbell;
    }
    if (n.contains('youtube') ||
        n.contains('netflix') ||
        n.contains('disney') ||
        n.contains('prime') ||
        n.contains('max') ||
        n.contains('hbo') ||
        n.contains('globo')) {
      return LucideIcons.play;
    }
    if (n.contains('figma') ||
        n.contains('adobe') ||
        n.contains('canva') ||
        n.contains('notion') ||
        n.contains('github')) {
      return LucideIcons.layers;
    }
    return e.category.icon;
  }

  /// Posicionamento sem sobreposição para 1 a 5 bolhas dentro de [w] × [h].
  static List<(Offset center, double radius)> _pack(
    List<double> radii,
    double w,
    double h,
  ) {
    final placed = <(Offset, double)>[];
    const pad = 6.0;
    for (var i = 0; i < radii.length; i++) {
      final r = radii[i];
      if (i == 0) {
        final cx = radii.length == 1 ? w * 0.5 : (w * 0.34).clamp(r + 2, w - r - 2);
        placed.add((Offset(cx, h * 0.5), r));
        continue;
      }
      // Testa ângulos em espiral ao redor das bolhas já colocadas para encaixar
      // o mais perto possível do centro sem sobrepor.
      Offset? best;
      var bestScore = double.infinity;
      final centerBias = Offset(w * 0.54, h * 0.5);
      for (final (pc, pr) in placed) {
        final dist = pr + r + pad;
        for (var k = 0; k < 24; k++) {
          final a = -math.pi * 0.35 + k * (2 * math.pi / 24);
          final cand = Offset(pc.dx + math.cos(a) * dist, pc.dy + math.sin(a) * dist);
          if (cand.dx - r < 2 ||
              cand.dx + r > w - 2 ||
              cand.dy - r < 2 ||
              cand.dy + r > h - 2) {
            continue;
          }
          var collides = false;
          for (final (oc, or) in placed) {
            if ((cand - oc).distance < or + r + pad - 0.5) {
              collides = true;
              break;
            }
          }
          if (collides) continue;
          final score = (cand - centerBias).distance;
          if (score < bestScore) {
            bestScore = score;
            best = cand;
          }
        }
      }
      if (best != null) {
        placed.add((best, r));
      } else {
        // Fallback suave: posiciona no espaço livre mais distante dos existentes.
        final fx = (w * (0.2 + 0.65 * (i / math.max(1, radii.length - 1))))
            .clamp(r + 2, math.max(r + 2, w - r - 2))
            .toDouble();
        final fy = (i.isOdd ? h * 0.34 : h * 0.66)
            .clamp(r + 2, math.max(r + 2, h - r - 2))
            .toDouble();
        placed.add((Offset(fx, fy), r));
      }
    }
    // Centraliza o conjunto horizontalmente no container.
    if (placed.isNotEmpty) {
      var minX = double.infinity;
      var maxX = -double.infinity;
      for (final (c, r) in placed) {
        minX = math.min(minX, c.dx - r);
        maxX = math.max(maxX, c.dx + r);
      }
      final shift = (w - (maxX - minX)) / 2 - minX;
      return [
        for (final (c, r) in placed)
          (
            Offset(
              (c.dx + shift).clamp(r + 2, math.max(r + 2, w - r - 2)),
              c.dy,
            ),
            r,
          ),
      ];
    }
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxCount = height >= 180 ? 5 : 4;
    final top = subs.take(maxCount).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxV = math.max(1, top.first.cents).toDouble();
    final pal = c.palette;
    final colors = [
      c.primary,
      c.accentWarm,
      c.isDark ? pal.primary[300] : pal.primary[600],
      c.isDark ? pal.companion[300] : pal.companion[500],
      c.isDark ? pal.primary[700] : pal.primary[300],
    ];

    Widget render(double w) {
      final h = height;
      final maxD = math.min(h * 0.72, w * 0.44).clamp(62.0, 118.0);
      final minD = (maxD * 0.54).clamp(48.0, 68.0);
      final radii = [
        for (final e in top)
          (minD + (maxD - minD) * math.sqrt(e.cents / maxV)) / 2,
      ];
      final packed = _pack(radii, w, h);

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            for (var i = 0; i < top.length; i++)
              _SubBubble(
                expense: top[i],
                center: packed[i].$1,
                diameter: packed[i].$2 * 2,
                color: colors[i % colors.length],
                icon: _serviceIcon(top[i]),
                hidden: hidden,
                onTap: onSelect == null ? null : () => onSelect!(top[i]),
              ),
          ],
        ),
      );
    }

    if (width != null) return SizedBox(width: width, child: render(width!));
    return LayoutBuilder(builder: (ctx, box) => render(box.maxWidth));
  }
}

class _SubBubble extends StatelessWidget {
  final Expense expense;
  final Offset center;
  final double diameter;
  final Color color;
  final IconData icon;
  final bool hidden;
  final VoidCallback? onTap;
  const _SubBubble({
    required this.expense,
    required this.center,
    required this.diameter,
    required this.color,
    required this.icon,
    required this.hidden,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onColor(color);
    final domain = brandDomainFor(expense.name);
    final badgeSize = (diameter * 0.34).clamp(22.0, 34.0);
    final showName = diameter >= 90;
    final priceText = hidden
        ? '•••'
        : fmtMoney(expense.cents).replaceAll('R\$ ', 'R\$');

    final iconWidget = SizedBox(
      width: badgeSize,
      height: badgeSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(icon, size: (badgeSize * 0.72).clamp(15.0, 22.0), color: fg),
          ),
          if (domain != null)
            Image.network(
              brandLogoUrl(domain),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              frameBuilder: (ctx, child, frame, sync) => frame == null && !sync
                  ? const SizedBox.shrink()
                  : Container(
                      padding: EdgeInsets.all(badgeSize * 0.18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: child,
                    ),
            ),
        ],
      ),
    );

    final circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      padding: EdgeInsets.symmetric(
        horizontal: diameter * 0.12,
        vertical: diameter * 0.1,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          SizedBox(height: diameter >= 80 ? 4 : 2),
          if (showName) ...[
            Text(
              expense.name,
              style: T.micro.copyWith(
                color: fg.withValues(alpha: 0.84),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              priceText,
              style: (diameter >= 84 ? T.smallStrong : T.micro).copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    final interactive = onTap == null
        ? circle
        : Pressable(
            scale: 0.94,
            semanticLabel: '${expense.name}, ${fmtMoney(expense.cents)}',
            onTap: onTap,
            child: circle,
          );

    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      child: SpringBuilder(
        value: 1,
        from: 0,
        spring: Springs.bouncy,
        builder: (_, t, _) =>
            Transform.scale(scale: t.clamp(0.0, 1.18), child: interactive),
      ),
    );
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
                                        decoration: ShapeDecoration(
                                          color: light,
                                          shape: const RoundedSuperellipseBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(5),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: height * fixed[i] / top * k,
                                        decoration: ShapeDecoration(
                                          color: dark,
                                          shape: variable[i] == 0
                                              ? const RoundedSuperellipseBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                        top: Radius.circular(5),
                                                      ),
                                                )
                                              : const RoundedSuperellipseBorder(),
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

/// Cor tema da assinatura: usa a cor oficial da marca quando reconhecida
/// (Spotify verde, Netflix vermelho, Prime azul, Claude terracota…) ou uma
/// cor distinta da paleta do app para serviços personalizados.
Color subscriptionBrandColor(AppColors c, Expense e, int index) {
  final brand = brandAccentColorFor(e.name);
  if (brand != null) return brand;
  final fallback = <Color>[
    c.palette.primary[400],
    c.palette.companion[400],
    const Color(0xFF3395FF),
    const Color(0xFFBF75E5),
    const Color(0xFF5DD27A),
    const Color(0xFFFFAA33),
  ];
  return fallback[index % fallback.length];
}

/// Gráfico interativo em anel segmentado (Donut) para Assinaturas:
/// cada serviço aparece na sua própria cor tema, com destaque ao tocar na fatia
/// ou na legenda abaixo e detalhamento proporcional sem sobreposição.
class SubscriptionDonutChart extends StatefulWidget {
  final List<Expense> subs;
  final bool hidden;
  final ValueChanged<Expense>? onSelect;
  const SubscriptionDonutChart({
    super.key,
    required this.subs,
    this.hidden = false,
    this.onSelect,
  });

  @override
  State<SubscriptionDonutChart> createState() => _SubscriptionDonutChartState();
}

class _SubscriptionDonutChartState extends State<SubscriptionDonutChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = [...widget.subs]..sort((a, b) => b.cents.compareTo(a.cents));
    if (list.isEmpty) return const SizedBox.shrink();
    final total = list.fold<int>(0, (t, e) => t + e.cents);
    if (total <= 0) return const SizedBox.shrink();
    final colors = [
      for (var i = 0; i < list.length; i++)
        subscriptionBrandColor(c, list[i], i),
    ];
    final sel = _selected != null && _selected! < list.length ? _selected : null;
    final active = sel != null ? list[sel] : null;
    final activeColor = sel != null ? colors[sel] : c.primary;

    return Column(
      children: [
        // ── Donut segmentado com centro interativo
        Center(
          child: SizedBox(
            width: 196,
            height: 196,
            child: SpringBuilder(
              value: 1.0,
              from: 0.0,
              spring: Springs.settle,
              builder: (_, progress, _) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(196),
                    painter: _DonutPainter(
                      values: [for (final e in list) e.cents / total],
                      colors: colors,
                      selected: sel,
                      progress: progress.clamp(0.0, 1.0),
                      trackColor: c.cardAlt,
                    ),
                  ),
                  SizedBox(
                    width: 124,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (active != null) ...[
                          Text(
                            active.name,
                            style: T.smallStrong.copyWith(color: activeColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: MoneyText(
                              active.cents,
                              hidden: widget.hidden,
                              style: T.cardValue,
                            ),
                          ),
                          Text(
                            '${(active.cents / total * 100).round()}% das assinaturas',
                            style: T.tiny.copyWith(color: c.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          Text(
                            '${list.length} ${list.length == 1 ? 'serviço' : 'serviços'}',
                            style: T.small.copyWith(color: c.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: MoneyText(
                              total,
                              hidden: widget.hidden,
                              style: T.cardValue,
                            ),
                          ),
                          Text(
                            'por ciclo',
                            style: T.tiny.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),

        // ── Barras proporcionais na cor tema de cada assinatura
        Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: Space.md),
              _SubShareRow(
                expense: list[i],
                color: colors[i],
                share: list[i].cents / total,
                hidden: widget.hidden,
                selected: sel == i,
                onTap: () {
                  if (sel == i) {
                    widget.onSelect?.call(list[i]);
                  } else {
                    setState(() => _selected = i);
                  }
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SubShareRow extends StatelessWidget {
  final Expense expense;
  final Color color;
  final double share;
  final bool hidden;
  final bool selected;
  final VoidCallback onTap;
  const _SubShareRow({
    required this.expense,
    required this.color,
    required this.share,
    required this.hidden,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = (share * 100).round();
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: ShapeDecoration(
          color: selected ? color.withValues(alpha: c.isDark ? 0.14 : 0.10) : const Color(0x00000000),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Space.radiusMd),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    expense.name,
                    style: T.labelStrong.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  fmtMoney(expense.cents, hidden: hidden),
                  style: T.labelStrong.copyWith(color: c.text),
                ),
                const SizedBox(width: Space.sm),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SpringBar(
              fraction: share,
              color: color,
              track: c.cardAlt,
              height: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final int? selected;
  final double progress;
  final Color trackColor;
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.selected,
    required this.progress,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseStroke = 20.0;
    const activeStroke = 24.0;
    final radius = (size.width - activeStroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStroke,
    );

    if (values.isEmpty || progress <= 0.001) return;
    final totalSweep = 2 * math.pi * progress;
    final gap = values.length > 1 ? 0.055 : 0.0;
    var start = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final rawSweep = values[i] * totalSweep;
      final sweep = math.max(0.02, rawSweep - gap);
      final isSel = selected == i;
      final dimmed = selected != null && !isSel;
      final paint = Paint()
        ..color = dimmed ? colors[i].withValues(alpha: 0.30) : colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? activeStroke : baseStroke
        ..strokeCap = values.length == 1 ? StrokeCap.butt : StrokeCap.round;

      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += rawSweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.trackColor != trackColor ||
      old.values.length != values.length;
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
                              decoration: ShapeDecoration(
                                color: c.accentWarm,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                    decoration: ShapeDecoration(
                      color: c.cardAlt,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: SpringBuilder(
                      value: maxV == 0 ? 0 : v[i] / maxV,
                      from: 0,
                      spring: Springs.settle,
                      builder: (_, t, _) => Container(
                        height: math.max(14.0, barH * t.clamp(0.0, 1.05)),
                        decoration: ShapeDecoration(
                          color: i == sel ? c.text : c.borderStrong,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
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
