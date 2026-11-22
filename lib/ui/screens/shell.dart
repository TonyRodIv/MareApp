import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'box_form.dart';
import 'caixinhas.dart';
import 'extrato.dart';
import 'home.dart';
import 'profile.dart';

/// Navega com a transição nativa do iOS (swipe para voltar incluso).
Future<V?> push<V>(BuildContext context, Widget page) =>
    Navigator.of(context).push<V>(CupertinoPageRoute(builder: (_) => page));

/// Abre fluxos de criação com a transição "fluida" (sobe + desfoca).
Future<V?> pushFluid<V>(BuildContext context, Widget page) =>
    Navigator.of(context).push<V>(FluidModalRoute(builder: (_) => page));

/// Permite que telas filhas troquem a aba (ex.: card "Seus gastos" → Extrato).
class ShellScope extends InheritedWidget {
  final void Function(int tab, {ExtratoFilter? filter}) goTo;
  const ShellScope({super.key, required this.goTo, required super.child});
  static ShellScope? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ShellScope>();
  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Acesso global às abas — telas empilhadas (fora da árvore do Shell)
/// também conseguem trocar de aba.
class ShellNav {
  void Function(int tab, {ExtratoFilter? filter})? _impl;
  void goTo(int tab, {ExtratoFilter? filter}) =>
      _impl?.call(tab, filter: filter);
}

final shellNav = ShellNav();

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _extratoFilter = ValueNotifier<ExtratoFilter?>(null);

  @override
  void initState() {
    super.initState();
    shellNav._impl = _goTo;
  }

  void _goTo(int tab, {ExtratoFilter? filter}) {
    if (filter != null) _extratoFilter.value = filter;
    if (tab == 2 && context.storeRead.data.boxes.isEmpty) {
      pushFluid(context, const BoxForm());
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final hasBoxes = s.data.boxes.isNotEmpty;
    final effectiveTab = (!hasBoxes && _tab == 2) ? 0 : _tab;
    if (effectiveTab != _tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab == 2 && context.storeRead.data.boxes.isEmpty) {
          setState(() => _tab = 0);
        }
      });
    }
    final pages = [
      const HomeScreen(),
      ExtratoScreen(filter: _extratoFilter),
      const CaixinhasScreen(),
      const ProfileScreen(),
    ];
    final logicalTabs = hasBoxes ? const [0, 1, 2, 3] : const [0, 1, 3];
    final navIndex = logicalTabs
        .indexOf(effectiveTab)
        .clamp(0, logicalTabs.length - 1);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ShellScope(
      goTo: _goTo,
      child: SheetScaler(
        child: CupertinoPageScaffold(
          backgroundColor: c.bg,
          child: Stack(
            children: [
              RepaintBoundary(
                child: IndexedStack(index: effectiveTab, children: pages),
              ),
              // Progressive blur contido logo atrás da barra inferior flutuante
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 126 + bottom,
                child: ProgressiveBlur(
                  direction: AxisDirection.up,
                  maxSigma: 10,
                  tint: c.isDark ? const Color(0xFF0A0A0A) : null,
                  tintOpacity: c.isDark ? 0.80 : 0.82,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FloatingNavBar(
                      index: navIndex,
                      onTap: (i) => setState(() => _tab = logicalTabs[i]),
                      items: [
                        NavItem(
                          'Carteira',
                          LucideIcons.wallet,
                          activeBuilder: (col, sz) =>
                              _FilledNavIcon(kind: 0, color: col, size: sz),
                        ),
                        NavItem(
                          'Extrato',
                          LucideIcons.receiptText,
                          activeBuilder: (col, sz) =>
                              _FilledNavIcon(kind: 1, color: col, size: sz),
                        ),
                        if (hasBoxes)
                          NavItem(
                            'Caixinhas',
                            LucideIcons.piggyBank,
                            activeBuilder: (col, sz) =>
                                _FilledNavIcon(kind: 2, color: col, size: sz),
                          ),
                        NavItem(
                          'Seu Perfil',
                          LucideIcons.user,
                          custom: Avatar(
                            path: s.data.avatarPath,
                            name: s.data.userName,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Espaço no fim das listas para não ficar atrás da barra flutuante.
double navClearance(BuildContext context) =>
    66 + 40 + MediaQuery.paddingOf(context).bottom;

/// Ícone preenchido para a aba ativa da navbar (combinando com os traços do Lucide).
class _FilledNavIcon extends StatelessWidget {
  final int kind; // 0 = carteira, 1 = extrato, 2 = caixinhas
  final Color color;
  final double size;
  const _FilledNavIcon({
    required this.kind,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cutout = context.c.isDark
        ? const Color(0xFF242427)
        : const Color(0xFFEBEBF0);
    return CustomPaint(
      size: Size.square(size),
      painter: _FilledNavPainter(kind, color, cutout),
    );
  }
}

class _FilledNavPainter extends CustomPainter {
  final int kind;
  final Color color;
  final Color cutout;
  _FilledNavPainter(this.kind, this.color, this.cutout);

  @override
  void paint(Canvas canvas, Size s) {
    // Todas as coordenadas seguem exatamente o viewBox 24x24 oficial do Lucide
    // (wallet, receipt-text, piggy-bank) para que ativo vs. inativo tenham a
    // mesma silhueta, mudando apenas de contorno para preenchido.
    canvas.save();
    canvas.scale(s.width / 24, s.height / 24);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cutFill = Paint()
      ..color = cutout
      ..style = PaintingStyle.fill;
    final cutStroke = Paint()
      ..color = cutout
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (kind == 0) {
      // Lucide `wallet` (viewBox 24x24) preenchido
      // Aba superior (y=3..7, x=3..19)
      final topFlap = Path()
        ..moveTo(5, 3)
        ..lineTo(18, 3)
        ..arcToPoint(const Offset(19, 4), radius: const Radius.circular(1))
        ..lineTo(19, 7)
        ..lineTo(5, 7)
        ..arcToPoint(const Offset(5, 3), radius: const Radius.circular(2))
        ..close();
      canvas.drawPath(topFlap, fill);
      // Corpo principal (x=3..21, y=7..21)
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          3,
          6.5,
          21,
          21,
          topRight: const Radius.circular(1.5),
          bottomLeft: const Radius.circular(2.5),
          bottomRight: const Radius.circular(1.5),
        ),
        fill,
      );
      // Linha divisória sutil da aba superior
      canvas.drawLine(const Offset(5.2, 6.8), const Offset(19.2, 6.8), cutStroke);
      // Fecho lateral direito (x=16..22, y=12..16) com recorte
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          15.5,
          11.2,
          22.2,
          16.8,
          topLeft: const Radius.circular(2.8),
          bottomLeft: const Radius.circular(2.8),
          topRight: const Radius.circular(1.2),
          bottomRight: const Radius.circular(1.2),
        ),
        cutFill,
      );
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          16.8,
          12.3,
          22.0,
          15.7,
          topLeft: const Radius.circular(1.7),
          bottomLeft: const Radius.circular(1.7),
          topRight: const Radius.circular(1.0),
          bottomRight: const Radius.circular(1.0),
        ),
        fill,
      );
      canvas.drawCircle(const Offset(18.5, 14.0), 0.9, cutFill);
    } else if (kind == 1) {
      // Lucide `receipt-text` (viewBox 24x24) preenchido
      final p = Path()
        ..moveTo(4, 2)
        ..lineTo(4, 22)
        ..lineTo(6, 21)
        ..lineTo(8, 22)
        ..lineTo(10, 21)
        ..lineTo(12, 22)
        ..lineTo(14, 21)
        ..lineTo(16, 22)
        ..lineTo(18, 21)
        ..lineTo(20, 22)
        ..lineTo(20, 2)
        ..lineTo(18, 3)
        ..lineTo(16, 2)
        ..lineTo(14, 3)
        ..lineTo(12, 2)
        ..lineTo(10, 3)
        ..lineTo(8, 2)
        ..lineTo(6, 3)
        ..close();
      canvas.drawPath(p, fill);
      // 3 linhas exatas do `receipt-text`
      canvas.drawLine(const Offset(8, 8), const Offset(16, 8), cutStroke);
      canvas.drawLine(const Offset(8, 12), const Offset(16, 12), cutStroke);
      canvas.drawLine(const Offset(8, 16), const Offset(13, 16), cutStroke);
    } else {
      // Lucide `piggy-bank` (viewBox 24x24) preenchido
      final body = Path()
        ..moveTo(19, 5)
        ..cubicTo(17.5, 5, 16.2, 6.4, 16, 7)
        ..cubicTo(12.5, 5.5, 5, 6.7, 5, 12)
        ..cubicTo(5, 13.8, 5, 15, 7, 16.5)
        ..lineTo(7, 20)
        ..lineTo(11, 20)
        ..lineTo(11, 18)
        ..lineTo(14, 18)
        ..lineTo(14, 20)
        ..lineTo(18, 20)
        ..lineTo(18, 16)
        ..cubicTo(19, 15.5, 19.7, 15, 20, 14)
        ..lineTo(22, 14)
        ..lineTo(22, 10)
        ..lineTo(20, 10)
        ..cubicTo(20, 9, 19.5, 8.5, 19, 8)
        ..lineTo(19, 5)
        ..close();
      canvas.drawPath(body, fill);
      // Rabinho (M2 9v1c0 1.1.9 2 2 2h1)
      final tail = Path()
        ..moveTo(2, 9)
        ..lineTo(2, 10)
        ..cubicTo(2, 11.1, 2.9, 12, 4, 12)
        ..lineTo(5.5, 12);
      canvas.drawPath(tail, stroke);
      // Olhinho exato do Lucide piggy-bank (16, 11) + fenda da moeda (9..13, 9.5)
      canvas.drawCircle(const Offset(16, 10.8), 1.0, cutFill);
      canvas.drawLine(const Offset(9.5, 9.5), const Offset(13.2, 9.5), cutStroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FilledNavPainter old) =>
      old.kind != kind || old.color != color || old.cutout != cutout;
}
