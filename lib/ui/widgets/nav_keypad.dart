import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/perf.dart';
import '../../core/theme.dart';
import '../../data/validation.dart';
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

/// Pílula flutuante monocromática (estilo planejado no Figma) com física Fluid Motion:
/// indicador elástico com stretch/squash proporcional à velocidade + atração
/// magnética ao toque e bounce físico nos ícones/rótulos de cada aba.
class FloatingNavBar extends StatefulWidget {
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
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = widget.items;
    final index = widget.index;
    final bottom = MediaQuery.of(context).padding.bottom;
    final activeFg = c.text;
    final inactiveFg = c.textSecondary;
    // Atração magnética sutil da pílula ativa em direção à aba pressionada
    final targetPill = _pressedIndex != null && _pressedIndex != index
        ? index + (_pressedIndex! - index) * 0.06
        : index.toDouble();

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
          // Estilo "X": fundo translúcido com blur forte isolado num RepaintBoundary
          // próprio para que o indicador animado das abas não re-execute o
          // BackdropFilter a cada frame da troca de aba.
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(34),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: Builder(
                    builder: (ctx) {
                      final perf = ctx.perf;
                      final sigma = 26.0 * perf.glassSigmaFactor;
                      final surface = DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.isDark
                              ? (perf.allowBlur
                                    ? const Color(0xFF16161A).withValues(
                                        alpha: 0.56,
                                      )
                                    : c.card)
                              : (perf.allowBlur
                                    ? const Color(0xFFFFFFFF).withValues(
                                        alpha: 0.62,
                                      )
                                    : Palette.neutral0),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(34),
                            side: BorderSide(
                              color: c.isDark
                                  ? Palette.neutral0.withValues(alpha: 0.10)
                                  : Palette.neutral950.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      );
                      if (!perf.allowBlur || sigma < 1.0) return surface;
                      return BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: surface,
                      );
                    },
                  ),
                ),
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
                    child: LayoutBuilder(
                      builder: (ctx, box) {
                        final w = box.maxWidth / items.length;
                        return Stack(
                          children: [
                            // Indicador líquido Fluid Motion suave e bem amortecido
                            SpringBuilder(
                              value: targetPill,
                              spring: Springs.of(32, 0.92),
                              builder: (_, v, vel) {
                                final speed = vel.abs();
                                final stretchX = (speed * 0.014).clamp(
                                  0.0,
                                  0.09,
                                );
                                final squashY = (speed * 0.004).clamp(
                                  0.0,
                                  0.03,
                                );
                                final pressingActive = _pressedIndex == index;
                                final pressScale = pressingActive ? 0.97 : 1.0;
                                return Positioned(
                                  left: v * w - (w * stretchX / 2),
                                  top: 58 * squashY / 2,
                                  bottom: 58 * squashY / 2,
                                  width: w * (1 + stretchX),
                                  child: AnimatedScale(
                                    scale: pressScale,
                                    duration: const Duration(milliseconds: 90),
                                    curve: Curves.easeOut,
                                    child: DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color: c.navActive,
                                        shape: RoundedSuperellipseBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
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
                                    child: _FluidNavTabItem(
                                      item: items[i],
                                      active: i == index,
                                      pressed: _pressedIndex == i,
                                      activeFg: activeFg,
                                      inactiveFg: inactiveFg,
                                      onPressChanged: (down) {
                                        if ( down && _pressedIndex != i) {
                                          setState(() => _pressedIndex = i);
                                        } else if (!down &&
                                            _pressedIndex == i) {
                                          setState(() => _pressedIndex = null);
                                        }
                                      },
                                      onTap: () {
                                        if (i == index) {
                                          HapticFeedback.lightImpact();
                                          return;
                                        }
                                        HapticFeedback.selectionClick();
                                        widget.onTap(i);
                                      },
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FluidNavTabItem extends StatelessWidget {
  final NavItem item;
  final bool active;
  final bool pressed;
  final Color activeFg;
  final Color inactiveFg;
  final ValueChanged<bool> onPressChanged;
  final VoidCallback onTap;

  const _FluidNavTabItem({
    required this.item,
    required this.active,
    required this.pressed,
    required this.activeFg,
    required this.inactiveFg,
    required this.onPressChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final targetScale = pressed ? 0.94 : 1.0;
    final targetActivation = active ? 1.0 : 0.0;

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressChanged(true),
        onTapUp: (_) => onPressChanged(false),
        onTapCancel: () => onPressChanged(false),
        onTap: onTap,
        child: SpringBuilder(
          value: targetScale,
          spring: Springs.of(32, 0.88),
          builder: (_, pressScale, _) => SpringBuilder(
            value: targetActivation,
            spring: Springs.of(28, 0.90),
            builder: (_, act, actVel) {
              final t = act.clamp(0.0, 1.0);
              final fg = Color.lerp(inactiveFg, activeFg, t) ?? activeFg;
              final bouncePop = 1.0 + (actVel.abs() * 0.002).clamp(0.0, 0.025);
              final liftY = -0.8 * t;

              Widget iconWidget;
              if (item.custom != null) {
                iconWidget = item.custom!;
              } else if (active && item.activeBuilder != null) {
                iconWidget = KeyedSubtree(
                  key: const ValueKey('active'),
                  child: item.activeBuilder!(fg, 22),
                );
              } else {
                iconWidget = Icon(
                  item.icon,
                  key: const ValueKey('inactive'),
                  size: 22,
                  color: fg,
                );
              }

              return Transform.scale(
                scale: pressScale * bouncePop,
                child: SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(0, liftY),
                        child: BlurSwitcher(
                          duration: const Duration(milliseconds: 220),
                          alignment: Alignment.center,
                          child: iconWidget,
                        ),
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.micro.copyWith(
                          color: fg,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
  static const max = MoneyLimits.maxCents;

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
  final List<int> amounts;
  final Color? chipBg;
  const QuickAddChips({
    super.key,
    required this.controller,
    this.center = true,
    this.amounts = const [10, 20, 50, 100],
    this.chipBg,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: center ? WrapAlignment.center : WrapAlignment.start,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in amounts)
        ChipButton(
          '+$v',
          bg: chipBg,
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
  final Color? keyColor;
  final double keyHeight;
  const Keypad({
    super.key,
    required this.controller,
    this.keyColor,
    this.keyHeight = 62,
  });

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
            height: keyHeight,
            decoration: ShapeDecoration(
              color: ghost ? null : (keyColor ?? c.card),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(20),
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
