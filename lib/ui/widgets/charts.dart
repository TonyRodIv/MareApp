import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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
              cacheWidth: (badgeSize * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(32, 160),
              cacheHeight: (badgeSize * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(32, 160),
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

// ── Barra segmentada em cápsulas (estilo pílulas lado a lado) ─

class CapsuleSegment {
  final double value;
  final Color color;
  final String? label;
  const CapsuleSegment({required this.value, required this.color, this.label});
}

/// Barra horizontal grossa composta por cápsulas arredondadas lado a lado,
/// sem container nem fundo atrás — flutua diretamente sobre a superfície.
class SegmentedCapsuleBar extends StatelessWidget {
  final List<CapsuleSegment> segments;
  final double height;
  final double gap;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  const SegmentedCapsuleBar({
    super.key,
    required this.segments,
    this.height = 34,
    this.gap = 4,
    this.selectedIndex,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final positive = [
      for (var i = 0; i < segments.length; i++)
        if (segments[i].value > 0) (i, segments[i]),
    ];
    if (positive.isEmpty) {
      return SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: c.cardAlt,
            shape: const StadiumBorder(),
          ),
        ),
      );
    }

    final total = positive.fold<double>(0, (s, e) => s + e.$2.value);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (_, box) {
          final n = positive.length;
          final totalGap = gap * (n - 1);
          final avail = math.max(0.0, box.maxWidth - totalGap);
          // Mínimo enxuto (8px) preserva a proporção real mesmo com 10 itens.
          final minW = math.min(8.0, avail / n);

          final widths = [
            for (final item in positive) avail * (item.$2.value / total),
          ];
          var deficit = 0.0;
          var surplus = 0.0;
          for (var i = 0; i < n; i++) {
            if (widths[i] < minW) {
              deficit += minW - widths[i];
              widths[i] = minW;
            } else {
              surplus += widths[i] - minW;
            }
          }
          if (deficit > 0 && surplus > 0) {
            final scale = (surplus - deficit).clamp(0.0, surplus) / surplus;
            for (var i = 0; i < n; i++) {
              if (widths[i] > minW) {
                widths[i] = minW + (widths[i] - minW) * scale;
              }
            }
          }

          return Row(
            children: [
              for (var k = 0; k < n; k++) ...[
                if (k > 0) SizedBox(width: gap),
                Builder(
                  builder: (_) {
                    final origIdx = positive[k].$1;
                    final seg = positive[k].$2;
                    final dimmed =
                        selectedIndex != null && selectedIndex != origIdx;
                    final pill = AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: dimmed ? 0.28 : 1.0,
                      child: SizedBox(
                        width: widths[k],
                        height: height,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: seg.color,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    );
                    if (onSelect == null) return pill;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect!(origIdx),
                      child: pill,
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Arco aberto segmentado (estilo gauge) desenhado diretamente sobre o fundo,
/// com valor centralizado, linha guia interna delicada e legenda de pontos.
class SubscriptionArcGauge extends StatefulWidget {
  final List<Expense> subs;
  final bool hidden;
  final String? footer;
  final ValueChanged<Expense>? onSelect;
  const SubscriptionArcGauge({
    super.key,
    required this.subs,
    this.hidden = false,
    this.footer,
    this.onSelect,
  });

  @override
  State<SubscriptionArcGauge> createState() => _SubscriptionArcGaugeState();
}

class _SubscriptionArcGaugeState extends State<SubscriptionArcGauge> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = [...widget.subs]..sort((a, b) => b.cents.compareTo(a.cents));
    if (list.isEmpty) return const SizedBox.shrink();
    final total = list.fold<int>(0, (t, e) => t + e.cents);
    if (total <= 0) return const SizedBox.shrink();

    // Mostra as 3 principais assinaturas e agrupa as demais em "Outros".
    final topCount = list.length > 3 ? 3 : list.length;
    final entries = <(String, int, Color, Expense?)>[
      for (var i = 0; i < topCount; i++)
        (
          list[i].name,
          list[i].cents,
          subscriptionBrandColor(c, list[i], i),
          list[i],
        ),
    ];
    if (list.length > topCount) {
      final othersTotal = list
          .skip(topCount)
          .fold<int>(0, (t, e) => t + e.cents);
      entries.add(('Outros', othersTotal, c.emptyCell, null));
    }

    final sel = _selected != null && _selected! < entries.length
        ? _selected
        : null;
    final active = sel != null ? entries[sel] : null;
    final displayCents = active?.$2 ?? total;
    final formatted = fmtMoney(displayCents, hidden: widget.hidden);
    final hasPrefix = !widget.hidden && formatted.startsWith('R\$ ');
    final numberPart = hasPrefix ? formatted.substring(3) : formatted;

    void handleTap(int i) {
      if (sel == i) {
        final exp = entries[i].$4;
        if (exp != null) {
          widget.onSelect?.call(exp);
        } else {
          setState(() => _selected = null);
        }
      } else {
        setState(() => _selected = i);
      }
    }

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: sel != null ? () => setState(() => _selected = null) : null,
          child: SizedBox(
            width: 264,
            height: 204,
            child: SpringBuilder(
              value: 1.0,
              from: 0.0,
              spring: Springs.settle,
              builder: (_, progress, _) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(264, 204),
                    painter: _OpenArcGaugePainter(
                      values: [for (final e in entries) e.$2 / total],
                      colors: [for (final e in entries) e.$3],
                      selected: sel,
                      progress: progress.clamp(0.0, 1.0),
                      guideColor: c.border.withValues(
                        alpha: c.isDark ? 0.55 : 0.85,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (hasPrefix) ...[
                              Text(
                                'R\$',
                                style: T.title.copyWith(
                                  color: c.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              numberPart,
                              style: T.displayLg.copyWith(color: c.text),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          active != null
                              ? '${active.$1} · ${(active.$2 / total * 100).round()}%'
                              : 'Custo mensal',
                          style: T.label.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (active == null && widget.footer != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.footer!,
                            style: T.small.copyWith(color: c.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: Space.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.base,
          runSpacing: Space.sm,
          children: [
            for (var i = 0; i < entries.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => handleTap(i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: sel == null || sel == i ? 1.0 : 0.32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: entries[i].$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entries[i].$1,
                        style: (sel == i ? T.smallStrong : T.small).copyWith(
                          color: sel == i ? c.text : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OpenArcGaugePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final int? selected;
  final double progress;
  final Color guideColor;

  _OpenArcGaugePainter({
    required this.values,
    required this.colors,
    required this.selected,
    required this.progress,
    required this.guideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Arco aberto de ~230° (155° até 385°), centrado ligeiramente abaixo do meio.
    const stroke = 15.0;
    const startDeg = 155.0;
    const sweepDeg = 230.0;
    const startRad = startDeg * math.pi / 180.0;
    const totalRad = sweepDeg * math.pi / 180.0;

    final radius = (size.width - stroke) / 2 - 4;
    final center = Offset(size.width / 2, radius + stroke / 2 + 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Linha guia interna super delicada (igual à referência)
    final guideRect = Rect.fromCircle(center: center, radius: radius - 14);
    canvas.drawArc(
      guideRect,
      startRad - 0.04,
      totalRad + 0.08,
      false,
      Paint()
        ..color = guideColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (values.isEmpty) return;
    final n = values.length;
    // Espaço angular entre segmentos compensando as pontas arredondadas (stroke/r).
    final capPad = (stroke / radius) * 0.92;
    final gapRad = n > 1 ? capPad + 0.06 : 0.0;
    final usable = math.max(0.1, totalRad - gapRad * (n - 1));

    var cursor = startRad;
    for (var i = 0; i < n; i++) {
      final segSweep = usable * values[i] * progress;
      final isSel = selected == i;
      final dimmed = selected != null && !isSel;
      final paint = Paint()
        ..color = dimmed ? colors[i].withValues(alpha: 0.24) : colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 2.5 : stroke
        ..strokeCap = StrokeCap.round;

      if (segSweep > 0.005) {
        canvas.drawArc(rect, cursor, segSweep, false, paint);
      }
      cursor += usable * values[i] + gapRad;
    }
  }

  @override
  bool shouldRepaint(_OpenArcGaugePainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.guideColor != guideColor ||
      old.values.length != values.length;
}

// ── Sparkline translúcido de fundo (card Seus Gastos) ───────

/// Curva suave bem transparente desenhada por trás de cards de resumo
/// (verde para gastos controlados, vermelho para tendência de alta).
class SparklineBackground extends StatelessWidget {
  final List<double> values;
  final Color color;
  const SparklineBackground({
    super.key,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.c.isDark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SparklineBgPainter(
          values: values,
          color: color,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _SparklineBgPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool isDark;
  _SparklineBgPainter({
    required this.values,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pts = values.length >= 2 ? values : const [0.35, 0.62, 0.44, 0.72, 0.50, 0.64];
    final minV = pts.reduce(math.min);
    final maxV = pts.reduce(math.max);
    final span = (maxV - minV).abs();

    // Centralizado na faixa vazia entre o cabeçalho e o valor embaixo, com
    // margem confortável nas laterais para o ponto não encostar na borda.
    final topY = size.height * 0.34;
    final botY = size.height * 0.62;
    final usableH = math.max(1.0, botY - topY);

    final coords = <Offset>[];
    final padX = 16.0;
    final usableW = math.max(1.0, size.width - padX * 2);
    for (var i = 0; i < pts.length; i++) {
      final x = padX + usableW * (i / (pts.length - 1));
      final norm = span < 0.0001 ? 0.5 : (pts[i] - minV) / span;
      final y = botY - norm * usableH;
      coords.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fadeBottom = math.min(size.height, botY + size.height * 0.24);
    final areaPath = Path.from(linePath)
      ..lineTo(coords.last.dx, fadeBottom)
      ..lineTo(coords.first.dx, fadeBottom)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: isDark ? 0.10 : 0.09),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topY, size.width, fadeBottom - topY)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.22 : 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = coords.last;
    canvas.drawCircle(
      last,
      3.0,
      Paint()..color = color.withValues(alpha: isDark ? 0.42 : 0.38),
    );
  }

  @override
  bool shouldRepaint(_SparklineBgPainter old) =>
      old.color != color ||
      old.isDark != isDark ||
      old.values.length != values.length ||
      (values.isNotEmpty &&
          old.values.isNotEmpty &&
          old.values.last != values.last);
}

// ── Histórico visual em linha/área interativa ───────────────

/// Gráfico de área e linha suave por ciclo, com eixo Y à direita, grade sutil
/// pontilhada e toque/arraste interativo com tooltip flutuante.
class HistoryLineChart extends StatefulWidget {
  final Finance f;
  final int cycles;
  final double height;
  final bool hidden;
  final bool interactive;
  final bool showAxis;
  final ValueChanged<int?>? onSelect;

  const HistoryLineChart({
    super.key,
    required this.f,
    this.cycles = 6,
    this.height = 180,
    this.hidden = false,
    this.interactive = true,
    this.showAxis = true,
    this.onSelect,
  });

  @override
  State<HistoryLineChart> createState() => _HistoryLineChartState();
}

class _HistoryLineChartState extends State<HistoryLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(HistoryLineChart old) {
    super.didUpdateWidget(old);
    if (old.cycles != widget.cycles) _selected = null;
  }

  void _pickAt(double localX, double plotW, int n) {
    if (!widget.interactive || n <= 1 || plotW <= 0) return;
    const padX = 10.0;
    final usable = math.max(1.0, plotW - padX * 2);
    final raw = ((localX - padX) / usable * (n - 1)).round().clamp(0, n - 1);
    if (_selected != raw) {
      HapticFeedback.selectionClick();
      setState(() => _selected = raw);
      widget.onSelect?.call(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = widget.f.lastCycles(widget.cycles);
    final values = [for (final cy in list) widget.f.expensesTotal(cy)];
    final maxRaw = values.fold<int>(0, math.max);
    final ticks = HistoryBars._niceTicks(math.max(10000, maxRaw));
    final top = math.max(1, ticks.last);
    final sel = _selected != null && _selected! < list.length ? _selected : null;
    final lineColor = c.isDark
        ? Palette.neutral0.withValues(alpha: 0.90)
        : c.primary;
    final axisW = widget.showAxis ? 44.0 : 0.0;

    return SizedBox(
      height: widget.height + 26,
      child: LayoutBuilder(
        builder: (_, box) {
          final plotW = math.max(60.0, box.maxWidth - axisW);
          return Column(
            children: [
              SizedBox(
                height: widget.height,
                child: Row(
                  children: [
                    SizedBox(
                      width: plotW,
                      height: widget.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: widget.interactive
                            ? (d) => _pickAt(d.localPosition.dx, plotW, list.length)
                            : null,
                        onHorizontalDragStart: widget.interactive
                            ? (d) => _pickAt(d.localPosition.dx, plotW, list.length)
                            : null,
                        onHorizontalDragUpdate: widget.interactive
                            ? (d) => _pickAt(d.localPosition.dx, plotW, list.length)
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _HistoryLinePainter(
                                    values: values,
                                    maxValue: top,
                                    lineColor: lineColor,
                                    accentColor: c.primary,
                                    gridColor: c.border.withValues(
                                      alpha: c.isDark ? 0.42 : 0.65,
                                    ),
                                    cursorColor: c.textTertiary.withValues(
                                      alpha: 0.55,
                                    ),
                                    bgColor: c.bg,
                                    selected: sel,
                                    isDark: c.isDark,
                                  ),
                                ),
                              ),
                            ),
                            if (sel != null)
                              _buildTooltip(
                                c,
                                plotW,
                                widget.height,
                                sel,
                                list.length,
                                values[sel],
                                top,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.showAxis)
                      SizedBox(
                        width: axisW,
                        height: widget.height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final t in ticks)
                              Positioned(
                                right: 0,
                                bottom:
                                    ((widget.height - 24) * (t / top) + 4)
                                        .clamp(0.0, widget.height - 14),
                                child: Text(
                                  widget.hidden ? '••' : fmtCompact(t),
                                  style: T.tiny.copyWith(color: c.textTertiary),
                                  maxLines: 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: plotW,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < list.length; i++)
                          if (list.length <= 6 ||
                              i == 0 ||
                              i == list.length - 1 ||
                              i % 2 == 0)
                            Text(
                              list[i].shortLabel(),
                              style: T.tiny.copyWith(
                                color: sel == i ? c.text : c.textSecondary,
                                fontWeight: sel == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                      ],
                    ),
                  ),
                  if (widget.showAxis) SizedBox(width: axisW),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltip(
    AppColors c,
    double plotW,
    double plotH,
    int idx,
    int n,
    int cents,
    int top,
  ) {
    const padX = 10.0;
    const topPad = 24.0;
    const botPad = 10.0;
    final usableW = math.max(1.0, plotW - padX * 2);
    final usableH = math.max(1.0, plotH - topPad - botPad);
    final x = n <= 1 ? plotW / 2 : padX + usableW * (idx / (n - 1));
    final y = topPad + usableH * (1.0 - (cents / top).clamp(0.0, 1.0));
    const pillW = 86.0;
    final left = (x - pillW / 2)
        .clamp(0.0, math.max(0.0, plotW - pillW))
        .toDouble();
    final topPos = math.max(0.0, y - 34.0);

    return Positioned(
      left: left,
      top: topPos,
      child: IgnorePointer(
        child: Container(
          width: pillW,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.isDark ? c.cardAlt : c.text,
            shape: const StadiumBorder(),
          ),
          child: Text(
            widget.hidden ? '•••' : fmtMoney(cents),
            style: T.tiny.copyWith(
              color: c.isDark ? c.text : Palette.neutral0,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _HistoryLinePainter extends CustomPainter {
  final List<int> values;
  final int maxValue;
  final Color lineColor;
  final Color accentColor;
  final Color gridColor;
  final Color cursorColor;
  final Color bgColor;
  final int? selected;
  final bool isDark;

  _HistoryLinePainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
    required this.accentColor,
    required this.gridColor,
    required this.cursorColor,
    required this.bgColor,
    required this.selected,
    required this.isDark,
  });

  void _drawDashedH(Canvas canvas, double y, double w, Paint p) {
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < w) {
      canvas.drawLine(Offset(x, y), Offset(math.min(w, x + dash), y), p);
      x += dash + gap;
    }
  }

  void _drawDashedV(Canvas canvas, double x, double y0, double y1, Paint p) {
    const dash = 4.0;
    const gap = 4.0;
    var y = y0;
    while (y < y1) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y1, y + dash)), p);
      y += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    const padX = 10.0;
    const topPad = 24.0;
    const botPad = 10.0;
    final usableW = math.max(1.0, size.width - padX * 2);
    final usableH = math.max(1.0, size.height - topPad - botPad);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    _drawDashedH(canvas, topPad, size.width, gridPaint);
    _drawDashedH(canvas, topPad + usableH * 0.5, size.width, gridPaint);

    final coords = <Offset>[];
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = n <= 1 ? size.width / 2 : padX + usableW * (i / (n - 1));
      final norm = (values[i] / maxValue).clamp(0.0, 1.0);
      final y = topPad + usableH * (1.0 - norm);
      coords.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final baseY = size.height - botPad;
    final areaPath = Path.from(linePath)
      ..lineTo(coords.last.dx, baseY)
      ..lineTo(coords.first.dx, baseY)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: isDark ? 0.18 : 0.15),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPad, size.width, baseY - topPad)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Ponto branco/destaque no último ciclo
    canvas.drawCircle(coords.last, 4.0, Paint()..color = lineColor);

    if (selected != null && selected! < coords.length) {
      final p = coords[selected!];
      _drawDashedV(
        canvas,
        p.dx,
        p.dy + 6,
        baseY,
        Paint()
          ..color = cursorColor
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(p, 6.0, Paint()..color = bgColor);
      canvas.drawCircle(p, 4.2, Paint()..color = accentColor);
    }
  }

  @override
  bool shouldRepaint(_HistoryLinePainter old) =>
      old.selected != selected ||
      old.maxValue != maxValue ||
      old.isDark != isDark ||
      old.lineColor != lineColor ||
      old.values.length != values.length;
}

/// Gráfico de linha/área acumulada ao longo dos dias do ciclo para o Extrato,
/// seguindo a mesma estética limpa do [HistoryLineChart].
class CycleExpenseLineChart extends StatefulWidget {
  final Cycle cycle;
  final List<Expense> items;
  final double height;
  final bool hidden;

  const CycleExpenseLineChart({
    super.key,
    required this.cycle,
    required this.items,
    this.height = 124,
    this.hidden = false,
  });

  @override
  State<CycleExpenseLineChart> createState() => _CycleExpenseLineChartState();
}

class _CycleExpenseLineChartState extends State<CycleExpenseLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(CycleExpenseLineChart old) {
    super.didUpdateWidget(old);
    if (old.cycle.key != widget.cycle.key) _selected = null;
  }

  void _pickAt(double localX, double plotW, int n) {
    if (n <= 1 || plotW <= 0) return;
    const padX = 10.0;
    final usable = math.max(1.0, plotW - padX * 2);
    final raw = ((localX - padX) / usable * (n - 1)).round().clamp(0, n - 1);
    if (_selected != raw) {
      HapticFeedback.selectionClick();
      setState(() => _selected = raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = widget.cycle.days;
    if (days.isEmpty || widget.items.isEmpty) return const SizedBox.shrink();

    // Limita ao dia de hoje quando estamos no ciclo atual, para a curva parar
    // no presente em vez de estender uma linha reta até o fim do mês.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrent = widget.cycle.contains(today);
    final visibleDays = isCurrent
        ? [
            for (final d in days)
              if (!d.isAfter(today)) d,
          ]
        : days;
    final plotDays = visibleDays.length >= 2 ? visibleDays : days.take(2).toList();

    // Soma gastos por dia (recorrentes contam no dia 0 do ciclo; únicos no seu dia).
    final perDay = List<int>.filled(plotDays.length, 0);
    for (final e in widget.items) {
      if (e.cents <= 0) continue;
      if (e.isRecurring) {
        perDay[0] += e.cents;
      } else {
        final diff = e.date.difference(plotDays.first).inDays;
        final idx = diff.clamp(0, plotDays.length - 1);
        perDay[idx] += e.cents;
      }
    }
    var running = 0;
    final cumulative = [for (final v in perDay) running += v];
    final maxRaw = cumulative.fold<int>(0, math.max);
    if (maxRaw <= 0) return const SizedBox.shrink();

    final ticks = HistoryBars._niceTicks(math.max(10000, maxRaw));
    final top = math.max(1, ticks.last);
    final sel = _selected != null && _selected! < plotDays.length
        ? _selected
        : null;
    final lineColor = c.isDark
        ? Palette.neutral0.withValues(alpha: 0.88)
        : c.primary;
    const axisW = 44.0;

    return SizedBox(
      height: widget.height + 24,
      child: LayoutBuilder(
        builder: (_, box) {
          final plotW = math.max(60.0, box.maxWidth - axisW);
          return Column(
            children: [
              SizedBox(
                height: widget.height,
                child: Row(
                  children: [
                    SizedBox(
                      width: plotW,
                      height: widget.height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            _pickAt(d.localPosition.dx, plotW, plotDays.length),
                        onHorizontalDragStart: (d) =>
                            _pickAt(d.localPosition.dx, plotW, plotDays.length),
                        onHorizontalDragUpdate: (d) =>
                            _pickAt(d.localPosition.dx, plotW, plotDays.length),
                        onTapUp: (_) {},
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _HistoryLinePainter(
                                    values: cumulative,
                                    maxValue: top,
                                    lineColor: lineColor,
                                    accentColor: c.primary,
                                    gridColor: c.border.withValues(
                                      alpha: c.isDark ? 0.36 : 0.58,
                                    ),
                                    cursorColor: c.textTertiary.withValues(
                                      alpha: 0.55,
                                    ),
                                    bgColor: c.bg,
                                    selected: sel,
                                    isDark: c.isDark,
                                  ),
                                ),
                              ),
                            ),
                            if (sel != null)
                              _buildTooltip(
                                c,
                                plotW,
                                widget.height,
                                sel,
                                plotDays,
                                cumulative[sel],
                                top,
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: axisW,
                      height: widget.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final t in ticks)
                            Positioned(
                              right: 0,
                              bottom:
                                  ((widget.height - 24) * (t / top) + 4)
                                      .clamp(0.0, widget.height - 14),
                              child: Text(
                                widget.hidden ? '••' : fmtCompact(t),
                                style: T.tiny.copyWith(color: c.textTertiary),
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: plotW,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${plotDays.first.day.toString().padLeft(2, '0')}/${plotDays.first.month.toString().padLeft(2, '0')}',
                          style: T.tiny.copyWith(color: c.textTertiary),
                        ),
                        if (plotDays.length >= 6)
                          Text(
                            '${plotDays[plotDays.length ~/ 2].day.toString().padLeft(2, '0')}/${plotDays[plotDays.length ~/ 2].month.toString().padLeft(2, '0')}',
                            style: T.tiny.copyWith(color: c.textTertiary),
                          ),
                        Text(
                          '${plotDays.last.day.toString().padLeft(2, '0')}/${plotDays.last.month.toString().padLeft(2, '0')}',
                          style: T.tiny.copyWith(color: c.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: axisW),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltip(
    AppColors c,
    double plotW,
    double plotH,
    int idx,
    List<DateTime> days,
    int cents,
    int top,
  ) {
    const padX = 10.0;
    const topPad = 24.0;
    const botPad = 10.0;
    final n = days.length;
    final usableW = math.max(1.0, plotW - padX * 2);
    final usableH = math.max(1.0, plotH - topPad - botPad);
    final x = n <= 1 ? plotW / 2 : padX + usableW * (idx / (n - 1));
    final y = topPad + usableH * (1.0 - (cents / top).clamp(0.0, 1.0));
    const pillW = 112.0;
    final left = (x - pillW / 2)
        .clamp(0.0, math.max(0.0, plotW - pillW))
        .toDouble();
    final topPos = math.max(0.0, y - 34.0);
    final d = days[idx];
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    return Positioned(
      left: left,
      top: topPos,
      child: IgnorePointer(
        child: Container(
          width: pillW,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.isDark ? c.cardAlt : c.text,
            shape: const StadiumBorder(),
          ),
          child: Text(
            widget.hidden ? dateStr : '$dateStr · ${fmtMoney(cents)}',
            style: T.tiny.copyWith(
              color: c.isDark ? c.text : Palette.neutral0,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Anel segmentado compacto com pontas arredondadas e gaps limpos,
/// ideal para o card "Por categoria" na Carteira.
class MiniDonutRing extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget? center;

  const MiniDonutRing({
    super.key,
    required this.values,
    required this.colors,
    this.size = 86,
    this.stroke = 10,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(size),
              painter: _MiniDonutPainter(
                values: values,
                colors: colors,
                stroke: stroke,
                trackColor: context.c.cardAlt,
              ),
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}

/// Faixa limpa dos 7 dias da semana (S T Q Q S S D) para os cards
/// "Para hoje" e "Fim de semana" — substitui a grade apertada de 31 pontos.
class MiniWeekStrip extends StatelessWidget {
  final Set<int> highlightedWeekdays; // 1 = seg .. 7 = dom
  final Color? highlightColor;
  const MiniWeekStrip({
    super.key,
    required this.highlightedWeekdays,
    this.highlightColor,
  });

  static const _labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final activeColor = highlightColor ?? c.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (_) {
              final active = highlightedWeekdays.contains(i + 1);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: active ? 10 : 7,
                    height: active ? 10 : 7,
                    decoration: BoxDecoration(
                      color: active ? activeColor : c.cardAlt,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _labels[i],
                    style: T.tiny.copyWith(
                      color: active ? c.text : c.textTertiary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _MiniDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double stroke;
  final Color trackColor;

  _MiniDonutPainter({
    required this.values,
    required this.colors,
    required this.stroke,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      return;
    }

    final n = values.length;
    final capPad = (stroke / radius) * 0.92;
    final gapRad = n > 1 ? capPad + 0.08 : 0.0;
    final usable = math.max(0.2, 2 * math.pi - gapRad * n);
    var cursor = -math.pi / 2 + gapRad / 2;

    for (var i = 0; i < n; i++) {
      final frac = values[i] / total;
      final sweep = usable * frac;
      if (sweep > 0.01) {
        canvas.drawArc(
          rect,
          cursor,
          sweep,
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      cursor += sweep + gapRad;
    }
  }

  @override
  bool shouldRepaint(_MiniDonutPainter old) =>
      old.values.length != values.length ||
      old.stroke != stroke ||
      old.trackColor != trackColor;
}
