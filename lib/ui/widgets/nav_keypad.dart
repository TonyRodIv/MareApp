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
  const FloatingNavBar({super.key, required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.of(context).padding.bottom;
    final activeBg = c.isDark ? const Color(0xFF242427) : const Color(0xFFEBEBF0);
    final activeFg = c.isDark ? Palette.neutral0 : Palette.brandInk;
    final inactiveFg = c.isDark ? const Color(0xFF9A9AA2) : const Color(0xFF767680);

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, bottom > 0 ? bottom : Space.base),
      child: RepaintBoundary(
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Palette.neutral950.withValues(alpha: c.isDark ? 0.42 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Vidro leve: desfoca o que passa por trás, tinge de leve, brilho
          // suave no topo e borda de 1px que clareia no canto superior esquerdo.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: CustomPaint(
                foregroundPainter: _GlassEdgePainter(dark: c.isDark),
                child: Container(
                  padding: const EdgeInsets.all(Space.xs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: c.isDark
                          ? [const Color(0xFF1C1C1F).withValues(alpha: 0.74), const Color(0xFF121214).withValues(alpha: 0.84)]
                          : [const Color(0xFFFFFFFF).withValues(alpha: 0.80), const Color(0xFFF1F4F7).withValues(alpha: 0.72)],
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
                      final stretch = (vel.abs() * 0.025).clamp(0.0, 0.16);
                      return Positioned(
                        left: v * w - (w * stretch / 2),
                        top: 0,
                        bottom: 0,
                        width: w * (1 + stretch),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: activeBg.withValues(alpha: c.isDark ? 0.92 : 0.9),
                            border: Border.all(color: Palette.neutral0.withValues(alpha: c.isDark ? 0.10 : 0.7)),
                            boxShadow: [BoxShadow(color: Palette.neutral950.withValues(alpha: c.isDark ? 0.30 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (items[i].custom != null)
                                    items[i].custom!
                                  else if (i == index && items[i].activeBuilder != null)
                                    items[i].activeBuilder!(activeFg, 22)
                                  else
                                    Icon(
                                      items[i].icon,
                                      size: 22,
                                      color: i == index ? activeFg : inactiveFg,
                                    ),
                                  const SizedBox(height: Space.xxs),
                                  Text(
                                    items[i].label,
                                    maxLines: 1,
                                    style: T.small.copyWith(
                                      fontSize: 11,
                                      color: i == index ? activeFg : inactiveFg,
                                      fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
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
      ),
    );
  }
}

/// Borda de vidro: 1px que clareia no canto superior esquerdo e quase some no
/// inferior direito, mais um brilho muito leve no alto da pílula.
class _GlassEdgePainter extends CustomPainter {
  final bool dark;
  _GlassEdgePainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(34));
    const base = Palette.neutral0;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: dark ? 0.26 : 0.95),
            base.withValues(alpha: dark ? 0.04 : 0.30),
            base.withValues(alpha: dark ? 0.12 : 0.60),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
    // Brilho suave no topo (a "lente" do vidro).
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withValues(alpha: dark ? 0.07 : 0.35), base.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) => old.dark != dark;
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
  const AmountDisplay({super.key, required this.cents, this.size = 64, this.center = true, this.color});

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
              style: T.display.copyWith(fontSize: size, color: fg, height: 1.05),
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
  const QuickAddChips({super.key, required this.controller, this.center = true});

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
    Widget key(String label, VoidCallback onTap, {Widget? child, bool ghost = false}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Pressable(
          scale: 0.92,
          semanticLabel: label,
          onTap: onTap,
          child: Container(
            height: 62,
            decoration: BoxDecoration(color: ghost ? null : c.card, borderRadius: BorderRadius.circular(22)),
            alignment: Alignment.center,
            child:
                child ??
                Text(
                  label,
                  style: T.headline.copyWith(fontWeight: FontWeight.w400, color: c.text),
                ),
          ),
        ),
      ),
    );
    Widget row(List<int> ds) => Row(children: [for (final d in ds) key('$d', () => controller.digit(d))]);
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
              child: Text(
                'C',
                style: T.headline.copyWith(fontWeight: FontWeight.w400, color: c.textSecondary),
              ),
            ),
            key('0', () => controller.digit(0)),
            key('Apagar', controller.backspace, ghost: true, child: Icon(LucideIcons.delete, color: c.text, size: 24)),
          ],
        ),
      ],
    );
  }
}
