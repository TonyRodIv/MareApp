import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import 'kit.dart';
import 'motion.dart';

// ── Barra de navegação flutuante (Figma 293:952) ────────────

class NavItem {
  final String label;
  final IconData icon;
  final Widget? custom; // ex.: avatar no "Seu Perfil"
  final Widget Function(Color color, double size)? activeBuilder;
  const NavItem(this.label, this.icon, {this.custom, this.activeBuilder});
}

/// Pílula flutuante monocromática (estilo planejado no Figma):
/// paleta neutra sem cores de destaque, mais alta e com ícone ativo preenchido.
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.of(context).padding.bottom;
    final activeFg = c.text;
    final inactiveFg = c.textSecondary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        bottom > 0 ? bottom : Space.base,
      ),
      child: RepaintBoundary(
        child: Container(
          height: 66,
          decoration: ShapeDecoration(
            shadows: [
              BoxShadow(
                color: Palette.neutral950.withValues(
                  alpha: c.isDark ? 0.42 : 0.10,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(34),
            ),
          ),
          // Estilo "X": corpo translúcido com blur forte e borda uniforme de 1px,
          // sem brilho nem degradê na borda. O fundo continua legível por baixo.
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                padding: const EdgeInsets.all(Space.xs),
                decoration: ShapeDecoration(
                  color: c.isDark
                      ? const Color(0xFF16161A).withValues(alpha: 0.56)
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.62),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(34),
                    side: BorderSide(
                      color: c.isDark
                          ? Palette.neutral0.withValues(alpha: 0.10)
                          : Palette.neutral950.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final w = box.maxWidth / items.length;
                    return Stack(
                      children: [
                        SpringBuilder(
                          value: index.toDouble(),
                          spring: Springs.snappy,
                          builder: (_, v, vel) {
                            final stretch = (vel.abs() * 0.025).clamp(
                              0.0,
                              0.16,
                            );
                            return Positioned(
                              left: v * w - (w * stretch / 2),
                              top: 0,
                              bottom: 0,
                              width: w * (1 + stretch),
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: c.navActive,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Expanded(
                                child: Pressable(
                                  semanticLabel: items[i].label,
                                  scale: 0.94,
                                  onTap: () => onTap(i),
                                  child: SizedBox.expand(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (items[i].custom != null)
                                          items[i].custom!
                                        else if (i == index &&
                                            items[i].activeBuilder != null)
                                          items[i].activeBuilder!(activeFg, 22)
                                        else
                                          Icon(
                                            items[i].icon,
                                            size: 22,
                                            color: i == index
                                                ? activeFg
                                                : inactiveFg,
                                          ),
                                        const SizedBox(height: Space.xxs),
                                        Text(
                                          items[i].label,
                                          maxLines: 1,
                                          style: T.micro.copyWith(
                                            color: i == index
                                                ? activeFg
                                                : inactiveFg,
                                            fontWeight: i == index
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Valor grande + teclado numérico (Figma 414:2887) ────────

/// Controla um valor em centavos digitado da direita para a esquerda
/// (como em apps de banco: 1 → 0,01; 12 → 0,12; 123 → 1,23).
class AmountController extends ValueNotifier<Cents> {
  AmountController([super.value = 0]);
  static const max = 99999999999; // R$ 999.999.999,99

  void digit(int d) {
    final next = value * 10 + d;
    if (next <= max) value = next;
  }

  void backspace() => value = value ~/ 10;
  void add(Cents c) => value = (value + c).clamp(0, max);
  void clear() => value = 0;
}

class AmountDisplay extends StatelessWidget {
  final Cents cents;
  final double size;
  final bool center;
  final Color? color;
  const AmountDisplay({
    super.key,
    required this.cents,
    this.size = 64,
    this.center = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final empty = cents == 0;
    final fg = empty ? c.textTertiary : (color ?? c.text);
    return SpringBuilder(
      value: cents.toDouble(),
      spring: Springs.snappy,
      builder: (_, v, vel) {
        final pop = (vel.abs() / 60000).clamp(0.0, 0.05);
        return Transform.scale(
          scale: 1 + pop,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'R\$ ${fmtNumber(cents)}',
              style: T.display.copyWith(
                fontSize: size,
                color: fg,
                height: 1.05,
              ),
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

class QuickAddChips extends StatelessWidget {
  final AmountController controller;
  final bool center;
  const QuickAddChips({
    super.key,
    required this.controller,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: center ? WrapAlignment.center : WrapAlignment.start,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in const [10, 20, 50, 100])
        ChipButton(
          '+$v',
          onTap: () {
            HapticFeedback.lightImpact();
            controller.add(v * 100);
          },
        ),
    ],
  );
}

class Keypad extends StatelessWidget {
  final AmountController controller;
  const Keypad({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const digitMetrics = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
      leadingDistribution: TextLeadingDistribution.even,
    );
    Widget key(
      String label,
      VoidCallback onTap, {
      Widget? child,
      bool ghost = false,
    }) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Pressable(
          scale: 0.92,
          semanticLabel: label,
          onTap: onTap,
          child: Container(
            height: 62,
            decoration: ShapeDecoration(
              color: ghost ? null : c.card,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            alignment: Alignment.center,
            child:
                child ??
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    textHeightBehavior: digitMetrics,
                    style: T.headline.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                      color: c.text,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    Widget row(List<int> ds) => Row(
      children: [for (final d in ds) key('$d', () => controller.digit(d))],
    );
    return Column(
      children: [
        row([1, 2, 3]),
        row([4, 5, 6]),
        row([7, 8, 9]),
        Row(
          children: [
            key(
              'Limpar',
              controller.clear,
              ghost: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Text(
                  'C',
                  textAlign: TextAlign.center,
                  textHeightBehavior: digitMetrics,
                  style: T.headline.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
            key('0', () => controller.digit(0)),
            key(
              'Apagar',
              controller.backspace,
              ghost: true,
              child: Icon(LucideIcons.delete, color: c.text, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}
