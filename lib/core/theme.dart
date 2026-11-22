import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_engine.dart';

/// Escala tonal completa (50–900) da paleta iOS com contraste WCAG verificado.
class ColorScale {
  final String name;
  final Color s50, s100, s200, s300, s400, s500, s600, s700, s800, s900;
  const ColorScale({
    required this.name,
    required this.s50,
    required this.s100,
    required this.s200,
    required this.s300,
    required this.s400,
    required this.s500,
    required this.s600,
    required this.s700,
    required this.s800,
    required this.s900,
  });
}

/// Paleta oficial (50–900) baseada no sistema iOS de alto contraste.
class Palette {
  // Extremos do preto e do branco, para variações além da escala do Figma.
  static const neutral1000 = Color(0xFF000000);
  static const neutral25 = Color(0xFFF9F9FB);
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF2F2F7);
  static const neutral100 = Color(0xFFE5E5EA);
  static const neutral300 = Color(0xFFAEAEB8);
  static const neutral400 = Color(0xFF63636E);
  static const neutral450 = Color(0xFF8A8A96);
  static const neutral650 = Color(0xFF2C2C30);
  static const neutral700 = Color(0xFF222226);
  static const neutral750 = Color(0xFF1A1A1E);
  static const neutral800 = Color(0xFF131316);
  static const neutral950 = Color(0xFF050507);

  static const red = ColorScale(
    name: 'Vermelho',
    s50: Color(0xFFFFEBEA),
    s100: Color(0xFFFFC2BF),
    s200: Color(0xFFFFA5A0),
    s300: Color(0xFFFF7C74),
    s400: Color(0xFFFF6259),
    s500: Color(0xFFFF3B30),
    s600: Color(0xFFE8362C),
    s700: Color(0xFFB52A22),
    s800: Color(0xFF8C201A),
    s900: Color(0xFF6B1914),
  );

  static const orange = ColorScale(
    name: 'Laranja',
    s50: Color(0xFFFFF4E6),
    s100: Color(0xFFFFDEB0),
    s200: Color(0xFFFFCE8A),
    s300: Color(0xFFFFB854),
    s400: Color(0xFFFFAA33),
    s500: Color(0xFFFF9500),
    s600: Color(0xFFE88800),
    s700: Color(0xFFB56A00),
    s800: Color(0xFF8C5200),
    s900: Color(0xFF6B3F00),
  );

  static const yellow = ColorScale(
    name: 'Amarelo',
    s50: Color(0xFFFFFAE6),
    s100: Color(0xFFFFEFB0),
    s200: Color(0xFFFFE88A),
    s300: Color(0xFFFFDD54),
    s400: Color(0xFFFFD633),
    s500: Color(0xFFFFCC00),
    s600: Color(0xFFE8BA00),
    s700: Color(0xFFB59100),
    s800: Color(0xFF8C7000),
    s900: Color(0xFF6B5600),
  );

  static const green = ColorScale(
    name: 'Verde',
    s50: Color(0xFFEBF9EE),
    s100: Color(0xFFC0EECC),
    s200: Color(0xFFA2E5B3),
    s300: Color(0xFF77D990),
    s400: Color(0xFF5DD27A),
    s500: Color(0xFF34C759),
    s600: Color(0xFF2FB551),
    s700: Color(0xFF258D3F),
    s800: Color(0xFF1D6D31),
    s900: Color(0xFF165425),
  );

  static const mint = ColorScale(
    name: 'Menta',
    s50: Color(0xFFE6F9F9),
    s100: Color(0xFFB0EEEB),
    s200: Color(0xFF8AE5E1),
    s300: Color(0xFF54D9D3),
    s400: Color(0xFF33D2CB),
    s500: Color(0xFF00C7BE),
    s600: Color(0xFF00B5AD),
    s700: Color(0xFF008D87),
    s800: Color(0xFF006D69),
    s900: Color(0xFF005450),
  );

  static const teal = ColorScale(
    name: 'Maré',
    s50: Color(0xFFEAF7F9),
    s100: Color(0xFFBFE7EE),
    s200: Color(0xFFA0DBE5),
    s300: Color(0xFF74CAD9),
    s400: Color(0xFF59C0D2),
    s500: Color(0xFF30B0C7),
    s600: Color(0xFF2CA0B5),
    s700: Color(0xFF227D8D),
    s800: Color(0xFF1A616D),
    s900: Color(0xFF144A54),
  );

  static const cyan = ColorScale(
    name: 'Ciano',
    s50: Color(0xFFEBF7FD),
    s100: Color(0xFFBFE6F7),
    s200: Color(0xFFA1D9F4),
    s300: Color(0xFF76C8EE),
    s400: Color(0xFF5BBDEB),
    s500: Color(0xFF32ADE6),
    s600: Color(0xFF2E9DD1),
    s700: Color(0xFF247BA3),
    s800: Color(0xFF1C5F7F),
    s900: Color(0xFF154961),
  );

  static const blue = ColorScale(
    name: 'Azul',
    s50: Color(0xFFE6F2FF),
    s100: Color(0xFFB0D6FF),
    s200: Color(0xFF8AC2FF),
    s300: Color(0xFF54A6FF),
    s400: Color(0xFF3395FF),
    s500: Color(0xFF007AFF),
    s600: Color(0xFF006FE8),
    s700: Color(0xFF0057B5),
    s800: Color(0xFF00438C),
    s900: Color(0xFF00336B),
  );

  static const indigo = ColorScale(
    name: 'Índigo',
    s50: Color(0xFFEEEEFB),
    s100: Color(0xFFCBCBF2),
    s200: Color(0xFFB2B1EC),
    s300: Color(0xFF8F8EE4),
    s400: Color(0xFF7978DE),
    s500: Color(0xFF5856D6),
    s600: Color(0xFF504EC3),
    s700: Color(0xFF3E3D98),
    s800: Color(0xFF302F76),
    s900: Color(0xFF25245A),
  );

  static const purple = ColorScale(
    name: 'Roxo',
    s50: Color(0xFFF7EEFC),
    s100: Color(0xFFE6C9F5),
    s200: Color(0xFFDAAFF0),
    s300: Color(0xFFC98BE9),
    s400: Color(0xFFBF75E5),
    s500: Color(0xFFAF52DE),
    s600: Color(0xFF9F4BCA),
    s700: Color(0xFF7C3A9E),
    s800: Color(0xFF602D7A),
    s900: Color(0xFF4A225D),
  );

  static const allScales = <ColorScale>[teal, cyan, blue, indigo, purple, mint, green, orange, red, yellow];

  // Aliases de compatibilidade para gráficos e marca maré.
  static const teal50 = Color(0xFFEAF7F9);
  static const teal100 = Color(0xFFBFE7EE);
  static const teal200 = Color(0xFFA0DBE5);
  static const teal350 = Color(0xFF74CAD9);
  static const teal550 = Color(0xFF30B0C7);
  static const teal750 = Color(0xFF227D8D);
  static const teal900 = Color(0xFF144A54);
  static const teal950 = Color(0xFF0B2931);

  static const orange50 = Color(0xFFFFF4E6);
  static const orange250 = Color(0xFFFFCE8A);
  static const orange400 = Color(0xFFFFAA33);
  static const orange500 = Color(0xFFFF9500);
  static const orange650 = Color(0xFFE88800);
  static const orange900 = Color(0xFF6B3F00);
  static const orange950 = Color(0xFF3B2300);

  static const brandBlue = Color(0xFF247BA3);
  static const brandNavy = Color(0xFF0E2835);
  static const brandDeep = Color(0xFF16485F);
  static const brandSky = Color(0xFF76C8EE);
  static const brandDot = Color(0xFF32ADE6);
  static const brandMist = Color(0xFFF2F2F7);
  static const brandInk = Color(0xFF0B0B0D);

  static const green400 = Color(0xFF5DD27A);
  static const green900 = Color(0xFF165425);
  static const red400 = Color(0xFFFF6259);
  static const red900 = Color(0xFF6B1914);
}

/// Cores de destaque disponíveis para personalização (paleta completa de 10 famílias).
final accentPresets = <(String, Color)>[for (final s in Palette.allScales) (s.name, s.s500)];

/// Família do Figma mais próxima da cor [seed] (em OKLCH).
ColorScale scaleFor(Color seed) {
  for (final s in Palette.allScales) {
    if (s.s500.toARGB32() == seed.toARGB32()) return s;
  }
  return nearestFigmaScale(toOklch(seed).h);
}

/// Cor companheira (tom 500) calculada pela harmonia escolhida — por padrão a
/// complementar, medida em OKLCH e encaixada na paleta do Figma.
Color complementaryOf(Color seed, {Harmony harmony = Harmony.complementary}) =>
    PaletteSet.build(seed, harmony: harmony).companion[500];

/// Tokens semânticos — resolvidos por tema (claro/escuro) e cor destaque.
class AppColors {
  final Brightness brightness;
  final Color seed;
  final Harmony harmony;
  final Color bg;
  final Color card;
  final Color cardAlt; // chips, inputs, segmentos
  final Color surfaceLow; // mais fundo que o bg: poços, overlays, trilhos
  final Color surfaceHigh; // acima do card: toasts, popovers, itens ativos
  final Color borderStrong; // divisórias que precisam aparecer
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary; // ação principal / foco da marca
  final Color onPrimary;
  final Color primarySoft; // destaque suave de seleção (pills, picker, badges)
  final Color secondary; // ação secundária complementar (ex.: gastos)
  final Color onSecondary;
  final Color accent; // cor principal de destaque (ícones, links, gráficos)
  final Color accentWarm; // cor complementar de destaque (ritmo, streak, alertas)
  final Color positive;
  final Color negative;
  final Color positiveSoft;
  final Color negativeSoft;
  final Color emptyCell; // células vazias dos gráficos waffle
  final Color navBg;
  final Color navActive;

  const AppColors({
    required this.brightness,
    required this.seed,
    required this.harmony,
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.borderStrong,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.accentWarm,
    required this.positive,
    required this.negative,
    required this.positiveSoft,
    required this.negativeSoft,
    required this.emptyCell,
    required this.navBg,
    required this.navActive,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Adapta uma cor fixa (categoria, caixinha) ao tema: no escuro clareia, no
  /// claro escurece, só o necessário para ter [min]:1 de contraste.
  Color tone(Color base, {double min = 3.4}) => ensureContrast(base, [card, bg], min);

  /// Cor suave para ícone/texto sobre um fundo [fill] colorido (caixinhas).
  Color softOn(Color fill) => ensureContrast(TonalScale.generate(fill)[200], [fill], 4.5);

  /// Monta o tema completo a partir de uma cor-semente, em três passos:
  /// 1. [PaletteSet] cria as escalas da primária e da companheira (harmonia);
  /// 2. neutros e superfícies saem do mesmo matiz, com croma quase nulo;
  /// 3. cada par texto/fundo passa por [ensureContrast], então nenhuma combinação
  ///    de semente × tema × harmonia fica abaixo do mínimo WCAG.
  factory AppColors.fromSeed(Color seed, Brightness brightness, {Harmony harmony = Harmony.complementary}) {
    final pal = PaletteSet.build(seed, harmony: harmony);
    final dark = brightness == Brightness.dark;
    final h = pal.hue;
    Color tint(double l, [double c = 0.008]) => fromOklch(l, c, h);

    final bg = dark ? tint(0.145) : tint(0.968, 0.006);
    final card = dark ? tint(0.205) : const Color(0xFFFFFFFF);
    final cardAlt = dark ? tint(0.245) : tint(0.945, 0.007);
    final surfaces = [bg, card, cardAlt];

    final text = ensureContrast(dark ? tint(0.985, 0.003) : tint(0.20, 0.012), surfaces, 12);
    final textSecondary = ensureContrast(dark ? tint(0.76, 0.010) : tint(0.45, 0.012), surfaces, 7);
    final textTertiary = ensureContrast(dark ? tint(0.64, 0.010) : tint(0.52, 0.012), surfaces, 4.5);

    final primary = dark ? pal.primary[500] : ensureContrast(pal.primary[600], const [Color(0xFFFFFFFF)], 4.5);
    final onPrimary = onColor(primary);
    final secondary = dark ? pal.companion[900] : pal.companion[50];
    final onSecondary = ensureContrast(dark ? pal.companion[50] : pal.companion[800], [secondary], 4.5);

    final accent = ensureContrast(dark ? pal.primary[400] : pal.primary[600], surfaces, 4.5);
    final accentWarm = ensureContrast(dark ? pal.companion[400] : pal.companion[600], surfaces, 3.0);

    final positive = ensureContrast(harmonize(dark ? Palette.green.s400 : Palette.green.s600, h), surfaces, 4.5);
    final negative = ensureContrast(harmonize(dark ? Palette.red.s400 : Palette.red.s600, h), surfaces, 4.5);

    return AppColors(
      brightness: brightness,
      seed: seed,
      harmony: harmony,
      bg: bg,
      card: card,
      cardAlt: cardAlt,
      surfaceLow: dark ? tint(0.105, 0.006) : tint(0.925, 0.008),
      surfaceHigh: dark ? tint(0.30, 0.010) : const Color(0xFFFFFFFF),
      borderStrong: dark ? tint(0.40, 0.012) : tint(0.80, 0.010),
      border: dark ? tint(0.30, 0.010) : tint(0.885, 0.008),
      text: text,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      primary: primary,
      onPrimary: onPrimary,
      primarySoft: dark ? pal.primary[900] : pal.primary[50],
      secondary: secondary,
      onSecondary: onSecondary,
      accent: accent,
      accentWarm: accentWarm,
      positive: positive,
      negative: negative,
      positiveSoft: dark ? TonalScale.generate(positive)[900] : TonalScale.generate(positive)[50],
      negativeSoft: dark ? TonalScale.generate(negative)[900] : TonalScale.generate(negative)[50],
      emptyCell: dark ? tint(0.27) : tint(0.915),
      navBg: dark ? tint(0.20).withValues(alpha: 0.62) : const Color(0xFFFFFFFF).withValues(alpha: 0.70),
      navActive: dark ? const Color(0xFFFFFFFF).withValues(alpha: 0.10) : tint(0.30).withValues(alpha: 0.07),
    );
  }

  static final dark = AppColors.fromSeed(Palette.teal.s500, Brightness.dark);
  static final light = AppColors.fromSeed(Palette.teal.s500, Brightness.light);

  @override
  bool operator ==(Object other) => other is AppColors && other.brightness == brightness && other.seed == seed && other.harmony == harmony;

  @override
  int get hashCode => Object.hash(brightness, seed, harmony);
}

class AppTheme extends InheritedWidget {
  final AppColors colors;
  const AppTheme({super.key, required this.colors, required super.child});

  static AppColors of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppTheme>()?.colors ?? AppColors.dark;

  @override
  bool updateShouldNotify(AppTheme oldWidget) => oldWidget.colors != colors;
}

extension AppThemeX on BuildContext {
  AppColors get c => AppTheme.of(this);
}

/// Tipografia padronizada: Poppins em escala limpa de números pares.
class T {
  static TextStyle _p(double size, FontWeight w, {double? height, double? ls}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: w, height: height, letterSpacing: ls);

  static TextStyle display = _p(36, FontWeight.w600, height: 1.15, ls: -0.5);
  static TextStyle title = _p(24, FontWeight.w600, height: 1.25);
  static TextStyle headline = _p(20, FontWeight.w600, height: 1.25);
  static TextStyle cardValue = _p(22, FontWeight.w600, height: 1.15);
  static TextStyle body = _p(16, FontWeight.w400, height: 1.4);
  static TextStyle bodyStrong = _p(16, FontWeight.w600, height: 1.4);
  static TextStyle label = _p(14, FontWeight.w400, height: 1.35);
  static TextStyle small = _p(12, FontWeight.w400, height: 1.35);
  static TextStyle smallStrong = _p(12, FontWeight.w600, height: 1.35);
  static TextStyle tiny = _p(12, FontWeight.w400, height: 1.25);
}

/// Escala de espaçamentos no grid de 8pt (com passos pares 2, 4, 8, 12, 16, 20, 24, 32, 40, 48).
class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const gutter = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
  static const xxxl = 48.0;

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusField = 16.0;
  static const radiusCard = 24.0;
  static const radiusSheet = 28.0;
}

/// Ponte para os widgets Cupertino nativos, com as cores do app.
CupertinoThemeData cupertinoThemeFor(AppColors c) => CupertinoThemeData(
  brightness: c.brightness,
  primaryColor: c.accent,
  primaryContrastingColor: c.onPrimary,
  scaffoldBackgroundColor: c.bg,
  barBackgroundColor: c.bg,
  textTheme: CupertinoTextThemeData(
    primaryColor: c.accent,
    textStyle: T.body.copyWith(color: c.text),
    navTitleTextStyle: T.bodyStrong.copyWith(color: c.text),
    navLargeTitleTextStyle: T.title.copyWith(color: c.text),
    actionTextStyle: T.body.copyWith(color: c.accent),
    dateTimePickerTextStyle: T.headline.copyWith(color: c.text, fontWeight: FontWeight.w400),
    pickerTextStyle: T.headline.copyWith(color: c.text, fontWeight: FontWeight.w400),
  ),
);
