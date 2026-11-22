import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

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

double _hueDist(double a, double b) {
  final d = (a - b).abs() % 360.0;
  return d > 180.0 ? 360.0 - d : d;
}

/// Encontra a escala da paleta oficial mais próxima da cor [seed].
ColorScale scaleFor(Color seed) {
  for (final s in Palette.allScales) {
    if (s.s500.toARGB32() == seed.toARGB32()) return s;
  }
  final targetHue = HSLColor.fromColor(seed).hue;
  ColorScale best = Palette.teal;
  var bestDist = 999.0;
  for (final s in Palette.allScales) {
    final d = _hueDist(HSLColor.fromColor(s.s500).hue, targetHue);
    if (d < bestDist) {
      bestDist = d;
      best = s;
    }
  }
  return best;
}

/// Algoritmo de cor complementar: rotaciona o matiz em +180° (círculo cromático HSL)
/// e seleciona a família complementar mais harmoniosa da paleta oficial.
ColorScale complementaryScaleOf(ColorScale primary) {
  // Ajuste de harmonia perceptual: azul/ciano/teal harmonizam com laranja quente.
  if (primary == Palette.teal || primary == Palette.cyan || primary == Palette.blue) return Palette.orange;
  final targetHue = (HSLColor.fromColor(primary.s500).hue + 180.0) % 360.0;
  ColorScale best = Palette.orange;
  var bestDist = 999.0;
  for (final s in Palette.allScales) {
    if (s == primary) continue;
    final d = _hueDist(HSLColor.fromColor(s.s500).hue, targetHue);
    if (d < bestDist) {
      bestDist = d;
      best = s;
    }
  }
  return best;
}

/// Cor complementar principal (tom 500 da escala complementar escolhida).
Color complementaryOf(Color seed) => complementaryScaleOf(scaleFor(seed)).s500;

/// Tokens semânticos — resolvidos por tema (claro/escuro) e cor destaque.
class AppColors {
  final Brightness brightness;
  final Color seed;
  final Color bg;
  final Color card;
  final Color cardAlt; // chips, inputs, segmentos
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
    required this.bg,
    required this.card,
    required this.cardAlt,
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

  /// Monta o tema completo a partir da escala oficial da cor [seed] e de sua
  /// escala complementar calculada automaticamente, com alto contraste em claro e escuro.
  factory AppColors.fromSeed(Color seed, Brightness brightness) {
    final p = scaleFor(seed);
    final comp = complementaryScaleOf(p);

    if (brightness == Brightness.dark) {
      final primary = p.s500;
      final onPrimary = primary.computeLuminance() > 0.42 ? Palette.neutral950 : Palette.neutral0;
      return AppColors(
        brightness: Brightness.dark,
        seed: p.s500,
        bg: Palette.neutral950,
        card: Palette.neutral800,
        cardAlt: Palette.neutral750,
        border: Palette.neutral650,
        text: Palette.neutral0,
        textSecondary: Palette.neutral300,
        textTertiary: Palette.neutral450,
        primary: primary,
        onPrimary: onPrimary,
        primarySoft: p.s900,
        secondary: comp.s900,
        onSecondary: comp.s50,
        accent: p.s400,
        accentWarm: comp.s400,
        positive: Palette.green.s400,
        negative: Palette.red.s400,
        positiveSoft: Palette.green.s900,
        negativeSoft: Palette.red.s900,
        emptyCell: Palette.neutral700,
        navBg: const Color(0xD6131316),
        navActive: p.s900,
      );
    }

    // No modo claro, tons muito luminosos (ex. amarelo) usam s700/s600 para manter contraste AA.
    final primary = p.s600.computeLuminance() > 0.45 ? p.s700 : p.s600;
    final onPrimary = primary.computeLuminance() > 0.45 ? Palette.neutral950 : Palette.neutral0;
    return AppColors(
      brightness: Brightness.light,
      seed: p.s500,
      bg: Palette.neutral50,
      card: Palette.neutral0,
      cardAlt: Palette.neutral100,
      border: const Color(0xFFD6D6DE),
      text: Palette.brandInk,
      textSecondary: Palette.neutral400,
      textTertiary: const Color(0xFF6E6E78),
      primary: primary,
      onPrimary: onPrimary,
      primarySoft: p.s50,
      secondary: comp.s50,
      onSecondary: comp.s800,
      accent: p.s600,
      accentWarm: comp.s500,
      positive: Palette.green.s600,
      negative: Palette.red.s600,
      positiveSoft: Palette.green.s50,
      negativeSoft: Palette.red.s50,
      emptyCell: Palette.neutral100,
      navBg: const Color(0xDCFFFFFF),
      navActive: p.s50,
    );
  }

  static final dark = AppColors.fromSeed(Palette.teal.s500, Brightness.dark);
  static final light = AppColors.fromSeed(Palette.teal.s500, Brightness.light);

  @override
  bool operator ==(Object other) => other is AppColors && other.brightness == brightness && other.seed == seed;

  @override
  int get hashCode => Object.hash(brightness, seed);
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
