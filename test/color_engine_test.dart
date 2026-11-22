import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mare/core/color_engine.dart';
import 'package:mare/core/theme.dart';

void main() {
  test('OKLCH: ida e volta preserva a cor', () {
    for (final s in Palette.allScales) {
      final c = s.s500;
      final o = toOklch(c);
      final back = fromOklch(o.l, o.c, o.h);
      expect((back.r - c.r).abs(), lessThan(0.01), reason: s.name);
      expect((back.g - c.g).abs(), lessThan(0.01), reason: s.name);
      expect((back.b - c.b).abs(), lessThan(0.01), reason: s.name);
    }
  });

  test('complementar do teal cai no laranja (no HSL cairia no vermelho)', () {
    final comp = PaletteSet.build(Palette.teal.s500).companion[500];
    final orangeHue = toOklch(Palette.orange.s500).h;
    expect(hueDistance(toOklch(comp).h, orangeHue), lessThan(40));
  });

  test('ângulos das harmonias', () {
    expect(Harmony.complementary.hues(30), [210]);
    expect(Harmony.splitComplementary.hues(30), [180, 240]);
    expect(Harmony.analogous.hues(10), [40, 340]);
    expect(Harmony.triadic.hues(300), [60, 180]);
    expect(Harmony.tetradic.hues(0), [90, 180, 270]);
    expect(Harmony.monochromatic.hues(100), isEmpty);
  });

  test('companheira nunca cai em vermelho ou verde (cores de erro/sucesso)', () {
    for (final s in Palette.allScales) {
      for (final h in Harmony.values) {
        final pal = PaletteSet.build(s.s500, harmony: h);
        if (h == Harmony.monochromatic) continue;
        expect(pal.companion[500] == Palette.red.s500 || pal.companion[500] == Palette.green.s500, isFalse, reason: '${s.name} ${h.label}');
      }
    }
  });

  test('escala gerada é monotônica em luminosidade e cobre 50–950', () {
    for (final seed in [const Color(0xFF8A3FFC), const Color(0xFFE6A23C), const Color(0xFF2F9E44)]) {
      final sc = TonalScale.generate(seed);
      final ls = [for (final t in TonalScale.steps) sc[t].computeLuminance()];
      for (var i = 1; i < ls.length; i++) {
        expect(ls[i], lessThanOrEqualTo(ls[i - 1] + 1e-6), reason: 'tom ${TonalScale.steps[i]}');
      }
    }
  });

  group('contraste WCAG em todas as combinações', () {
    final seeds = [for (final s in Palette.allScales) s.s500, const Color(0xFF8A3FFC), const Color(0xFFFFE600), const Color(0xFF101820)];
    for (final seed in seeds) {
      for (final harmony in Harmony.values) {
        for (final b in Brightness.values) {
          test('#${seed.toARGB32().toRadixString(16)} ${harmony.name} ${b.name}', () {
            final c = AppColors.fromSeed(seed, b, harmony: harmony);
            final surfaces = [c.bg, c.card, c.cardAlt];
            for (final s in surfaces) {
              expect(contrastRatio(c.text, s), greaterThanOrEqualTo(12), reason: 'text');
              expect(contrastRatio(c.textSecondary, s), greaterThanOrEqualTo(7), reason: 'textSecondary');
              expect(contrastRatio(c.textTertiary, s), greaterThanOrEqualTo(4.5), reason: 'textTertiary');
              expect(contrastRatio(c.accent, s), greaterThanOrEqualTo(4.5), reason: 'accent');
              expect(contrastRatio(c.accentWarm, s), greaterThanOrEqualTo(3), reason: 'accentWarm');
              expect(contrastRatio(c.positive, s), greaterThanOrEqualTo(4.5), reason: 'positive');
              expect(contrastRatio(c.negative, s), greaterThanOrEqualTo(4.5), reason: 'negative');
            }
            expect(contrastRatio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5), reason: 'onPrimary');
            expect(contrastRatio(c.onSecondary, c.secondary), greaterThanOrEqualTo(4.5), reason: 'onSecondary');
          });
        }
      }
    }
  });

  test('claro e escuro não se invertem: fundo claro é mais claro que o texto, e vice-versa', () {
    for (final s in Palette.allScales) {
      final l = AppColors.fromSeed(s.s500, Brightness.light);
      final d = AppColors.fromSeed(s.s500, Brightness.dark);
      expect(l.bg.computeLuminance(), greaterThan(l.text.computeLuminance()), reason: s.name);
      expect(d.bg.computeLuminance(), lessThan(d.text.computeLuminance()), reason: s.name);
      expect(l.card.computeLuminance(), greaterThan(d.card.computeLuminance()), reason: s.name);
    }
  });
}
