import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'theme.dart';

/// Motor de paletas do maré.
///
/// Parte da paleta do Figma (10 famílias iOS + neutros) e gera tudo o que falta
/// em OKLCH, o espaço em que "mesma luminosidade" significa mesma luminosidade
/// para o olho. No HSL, o complementar do teal cai em vermelho; no OKLCH cai no
/// laranja, que é o que a roda do Adobe Color mostra.
///
/// Etapas, em ordem:
/// 1. [Harmony] decide os matizes companheiros (ângulos da roda cromática).
/// 2. O companheiro é "encaixado" na família do Figma mais próxima, então o app
///    continua usando as cores da marca.
/// 3. [TonalScale] completa as escalas (50–950), inclusive para cores livres.
/// 4. [ensureContrast] corrige qualquer par texto/fundo abaixo do mínimo WCAG.

// ── OKLCH ───────────────────────────────────────────────────

class Oklch {
  final double l;
  final double c;
  final double h; // graus, 0–360
  const Oklch(this.l, this.c, this.h);
}

double _toLinear(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
double _fromLinear(double v) => v <= 0.0031308
    ? v * 12.92
    : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;

Oklch toOklch(Color color) {
  final r = _toLinear(color.r), g = _toLinear(color.g), b = _toLinear(color.b);
  final l = math
      .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
      .toDouble();
  final m = math
      .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
      .toDouble();
  final s = math
      .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
      .toDouble();
  final lab = (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
  final c = math.sqrt(lab.$2 * lab.$2 + lab.$3 * lab.$3);
  var h = math.atan2(lab.$3, lab.$2) * 180 / math.pi;
  if (h < 0) h += 360;
  return Oklch(lab.$1, c, c < 1e-4 ? 0 : h);
}

/// Converte OKLCH em sRGB. Se a cor sai da gama, reduz o croma (nunca o matiz
/// nem a luminosidade) até caber.
Color fromOklch(double l, double c, double h) {
  Color? tryC(double chroma) {
    final a = chroma * math.cos(h * math.pi / 180);
    final b = chroma * math.sin(h * math.pi / 180);
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final lc = l_ * l_ * l_, mc = m_ * m_ * m_, sc = s_ * s_ * s_;
    final r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
    final g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
    final bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;
    const e = 0.0005;
    if (r < -e || r > 1 + e || g < -e || g > 1 + e || bl < -e || bl > 1 + e)
      return null;
    double q(double v) => _fromLinear(v.clamp(0.0, 1.0));
    return Color.from(alpha: 1, red: q(r), green: q(g), blue: q(bl));
  }

  final ll = l.clamp(0.0, 1.0);
  if (ll >= 0.9999) return const Color(0xFFFFFFFF);
  if (ll <= 0.0001) return const Color(0xFF000000);
  var chroma = math.max(0.0, c);
  final direct = tryC(chroma);
  if (direct != null) return direct;
  var lo = 0.0, hi = chroma;
  Color best = tryC(0) ?? const Color(0xFF808080);
  for (var i = 0; i < 18; i++) {
    final mid = (lo + hi) / 2;
    final t = tryC(mid);
    if (t != null) {
      best = t;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return best;
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Ajusta só a luminosidade de [fg] até ter contraste ≥ [min] contra TODOS os
/// fundos de [bgs]. Preserva matiz e croma (a cor continua "a mesma").
Color ensureContrast(Color fg, List<Color> bgs, double min) {
  bool ok(Color c) => bgs.every((b) => contrastRatio(c, b) >= min);
  if (ok(fg)) return fg;
  final o = toOklch(fg);
  final lighten =
      bgs.map((b) => b.computeLuminance()).reduce((a, b) => (a + b) / 2) < 0.35;
  var l = o.l;
  for (var i = 0; i < 100; i++) {
    l += lighten ? 0.01 : -0.01;
    final c = fromOklch(l, o.c, o.h);
    if (ok(c)) return c;
    if (l <= 0 || l >= 1) break;
  }
  return lighten ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
}

/// Preto ou branco (levemente tingido) conforme o que contrasta mais com [bg].
Color onColor(
  Color bg, {
  Color light = const Color(0xFFFFFFFF),
  Color dark = const Color(0xFF0A0A0A),
}) => contrastRatio(light, bg) >= contrastRatio(dark, bg) ? light : dark;

double hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

// ── Harmonias da roda cromática ─────────────────────────────

enum Harmony {
  complementary('Complementar', [180]),
  splitComplementary('Complementar dividida', [150, 210]),
  analogous('Análoga', [30, -30]),
  triadic('Tríade', [120, 240]),
  tetradic('Tetrádica', [90, 180, 270]),
  monochromatic('Monocromática', []);

  final String label;
  final List<double> offsets;
  const Harmony(this.label, this.offsets);

  List<double> hues(double base) => [for (final o in offsets) (base + o) % 360];
}

// ── Escalas tonais ──────────────────────────────────────────

class TonalScale {
  final Map<int, Color> tones;
  const TonalScale(this.tones);
  Color operator [](int tone) => tones[tone]!;

  static const steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];
  static const _lightness = [
    0.975,
    0.935,
    0.87,
    0.80,
    0.72,
    0.64,
    0.55,
    0.46,
    0.37,
    0.29,
    0.21,
  ];

  /// Escala gerada a partir de qualquer cor. O croma segue uma curva em sino:
  /// máximo nos tons médios, suave nos extremos (evita 50 "rosado" e 950 "lama").
  factory TonalScale.generate(Color seed) {
    final o = toOklch(seed);
    final peak = math.max(o.c, 0.045);
    final map = <int, Color>{};
    for (var i = 0; i < steps.length; i++) {
      final l = _lightness[i];
      final bell = (1 - math.pow((l - 0.64) / 0.50, 2))
          .clamp(0.18, 1.0)
          .toDouble();
      map[steps[i]] = fromOklch(l, peak * bell, o.h);
    }
    // O tom mais próximo da cor original passa a ser exatamente ela.
    var nearest = 0;
    for (var i = 1; i < steps.length; i++) {
      if ((_lightness[i] - o.l).abs() < (_lightness[nearest] - o.l).abs())
        nearest = i;
    }
    map[steps[nearest]] = seed;
    return TonalScale(map);
  }

  /// Escala oficial do Figma (50–900) + 950 gerado, para a marca não mudar.
  factory TonalScale.fromFigma(ColorScale s) {
    final deep = toOklch(s.s900);
    return TonalScale({
      50: s.s50,
      100: s.s100,
      200: s.s200,
      300: s.s300,
      400: s.s400,
      500: s.s500,
      600: s.s600,
      700: s.s700,
      800: s.s800,
      900: s.s900,
      950: fromOklch(math.max(0.16, deep.l - 0.08), deep.c * 0.9, deep.h),
    });
  }
}

/// Família do Figma cuja cor 500 está mais perto do [hue] (em OKLCH).
ColorScale nearestFigmaScale(double hue, {Set<ColorScale> exclude = const {}}) {
  ColorScale? best;
  var bestD = 999.0;
  for (final s in Palette.allScales) {
    if (exclude.contains(s)) continue;
    final d = hueDistance(toOklch(s.s500).h, hue);
    if (d < bestD) {
      bestD = d;
      best = s;
    }
  }
  return best ?? Palette.teal;
}

/// Tudo o que as paletas do app precisam saber sobre uma cor-semente.
class PaletteSet {
  final Color seed;
  final Harmony harmony;
  final double hue;
  final TonalScale primary;
  final TonalScale companion;
  final List<double> companionHues;

  const PaletteSet._(
    this.seed,
    this.harmony,
    this.hue,
    this.primary,
    this.companion,
    this.companionHues,
  );

  factory PaletteSet.build(
    Color seed, {
    Harmony harmony = Harmony.complementary,
    bool snapToFigma = true,
  }) {
    final o = toOklch(seed);
    final hue = o.h;

    // Primária: se for uma cor do Figma, usa a escala oficial.
    ColorScale? official;
    for (final s in Palette.allScales) {
      if (s.s500.toARGB32() == seed.toARGB32()) official = s;
    }
    final primary = official != null
        ? TonalScale.fromFigma(official)
        : TonalScale.generate(seed);

    final hues = harmony.hues(hue);
    if (hues.isEmpty)
      return PaletteSet._(seed, harmony, hue, primary, primary, hues);

    // Companheira: primeiro matiz da harmonia que não colida com a própria
    // família nem com as cores semânticas (vermelho = erro, verde = ok).
    final own = official ?? nearestFigmaScale(hue);
    final banned = <ColorScale>{own, Palette.red, Palette.green};
    TonalScale? comp;
    for (final h in hues) {
      if (!snapToFigma) {
        comp = TonalScale.generate(fromOklch(0.64, math.max(o.c, 0.09), h));
        break;
      }
      final fam = nearestFigmaScale(h, exclude: banned);
      if (hueDistance(toOklch(fam.s500).h, h) <= 55) {
        comp = TonalScale.fromFigma(fam);
        break;
      }
    }
    comp ??= TonalScale.fromFigma(
      nearestFigmaScale(hues.first, exclude: banned),
    );
    return PaletteSet._(seed, harmony, hue, primary, comp, hues);
  }
}

/// Aproxima [color] do matiz da marca em até [maxShift]° — mantém verde como
/// verde e vermelho como vermelho, mas com o "sotaque" do tema (Material 3 faz
/// o mesmo com as cores semânticas).
Color harmonize(Color color, double towardHue, {double maxShift = 10}) {
  final o = toOklch(color);
  var diff = towardHue - o.h;
  while (diff > 180) {
    diff -= 360;
  }
  while (diff < -180) {
    diff += 360;
  }
  final shift = (diff.abs() * 0.12).clamp(0.0, maxShift) * diff.sign;
  return fromOklch(o.l, o.c, (o.h + shift + 360) % 360);
}
