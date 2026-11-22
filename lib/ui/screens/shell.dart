import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'caixinhas.dart';
import 'extrato.dart';
import 'home.dart';
import 'profile.dart';

/// Navega com a transição nativa do iOS (swipe para voltar incluso).
Future<V?> push<V>(BuildContext context, Widget page) => Navigator.of(context).push<V>(CupertinoPageRoute(builder: (_) => page));

/// Abre fluxos de criação com a transição "fluida" (sobe + desfoca).
Future<V?> pushFluid<V>(BuildContext context, Widget page) => Navigator.of(context).push<V>(FluidModalRoute(builder: (_) => page));

/// Permite que telas filhas troquem a aba (ex.: card "Seus gastos" → Extrato).
class ShellScope extends InheritedWidget {
  final void Function(int tab, {ExtratoFilter? filter}) goTo;
  const ShellScope({super.key, required this.goTo, required super.child});
  static ShellScope? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ShellScope>();
  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Acesso global às abas — telas empilhadas (fora da árvore do Shell)
/// também conseguem trocar de aba.
class ShellNav {
  void Function(int tab, {ExtratoFilter? filter})? _impl;
  void goTo(int tab, {ExtratoFilter? filter}) => _impl?.call(tab, filter: filter);
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
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final pages = [const HomeScreen(), ExtratoScreen(filter: _extratoFilter), const CaixinhasScreen(), const ProfileScreen()];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ShellScope(
      goTo: _goTo,
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            RepaintBoundary(
              child: IndexedStack(index: _tab, children: pages),
            ),
            // Progressive blur contido logo atrás da barra inferior flutuante
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 92 + bottom,
              child: ProgressiveBlur(
                direction: AxisDirection.up,
                maxSigma: 18,
                tintOpacity: c.isDark ? 0.62 : 0.78,
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
                    index: _tab,
                    onTap: (i) => setState(() => _tab = i),
                    items: [
                      NavItem(
                        'Carteira',
                        LucideIcons.wallet,
                        activeBuilder: (col, sz) => _FilledNavIcon(kind: 0, color: col, size: sz),
                      ),
                      NavItem(
                        'Extrato',
                        LucideIcons.receipt,
                        activeBuilder: (col, sz) => _FilledNavIcon(kind: 1, color: col, size: sz),
                      ),
                      NavItem(
                        'Caixinhas',
                        LucideIcons.piggyBank,
                        activeBuilder: (col, sz) => _FilledNavIcon(kind: 2, color: col, size: sz),
                      ),
                      NavItem(
                        'Seu Perfil',
                        LucideIcons.user,
                        custom: Avatar(path: s.data.avatarPath, name: s.data.userName, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Espaço no fim das listas para não ficar atrás da barra flutuante.
double navClearance(BuildContext context) => 66 + 40 + MediaQuery.paddingOf(context).bottom;

/// Ícone preenchido para a aba ativa da navbar (combinando com os traços do Lucide).
class _FilledNavIcon extends StatelessWidget {
  final int kind; // 0 = carteira, 1 = extrato, 2 = caixinhas
  final Color color;
  final double size;
  const _FilledNavIcon({required this.kind, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final cutout = context.c.isDark ? const Color(0xFF242427) : const Color(0xFFEBEBF0);
    return CustomPaint(size: Size.square(size), painter: _FilledNavPainter(kind, color, cutout));
  }
}

class _FilledNavPainter extends CustomPainter {
  final int kind;
  final Color color;
  final Color cutout;
  _FilledNavPainter(this.kind, this.color, this.cutout);

  @override
  void paint(Canvas canvas, Size s) {
    final fill = Paint()..color = color;
    final cut = Paint()..color = cutout;
    final w = s.width;
    final h = s.height;

    if (kind == 0) {
      // Carteira preenchida (estilo Lucide wallet sólido)
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.18, w * 0.72, h * 0.64), Radius.circular(w * 0.14)), fill);
      // Aba lateral do fecho
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.50, h * 0.36, w * 0.38, h * 0.28), Radius.circular(w * 0.10)), cut);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.56, h * 0.41, w * 0.30, h * 0.18), Radius.circular(w * 0.08)), fill);
      canvas.drawCircle(Offset(w * 0.68, h * 0.50), w * 0.055, cut);
    } else if (kind == 1) {
      // Extrato / recibo preenchido
      final p = Path()
        ..moveTo(w * 0.18, h * 0.12)
        ..lineTo(w * 0.82, h * 0.12)
        ..lineTo(w * 0.82, h * 0.88)
        ..lineTo(w * 0.70, h * 0.80)
        ..lineTo(w * 0.58, h * 0.88)
        ..lineTo(w * 0.50, h * 0.80)
        ..lineTo(w * 0.42, h * 0.88)
        ..lineTo(w * 0.30, h * 0.80)
        ..lineTo(w * 0.18, h * 0.88)
        ..close();
      canvas.drawPath(p, fill);
      final line = Paint()
        ..color = cutout
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.32, h * 0.34), Offset(w * 0.68, h * 0.34), line);
      canvas.drawLine(Offset(w * 0.32, h * 0.50), Offset(w * 0.68, h * 0.50), line);
      canvas.drawLine(Offset(w * 0.32, h * 0.66), Offset(w * 0.54, h * 0.66), line);
    } else {
      // Cofrinho (piggy bank) preenchido
      canvas.drawOval(Rect.fromLTWH(w * 0.14, h * 0.24, w * 0.64, h * 0.50), fill);
      // Focinho
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.72, h * 0.42, w * 0.16, h * 0.18), Radius.circular(w * 0.06)), fill);
      // Orelha
      canvas.drawOval(Rect.fromLTWH(w * 0.52, h * 0.14, w * 0.16, h * 0.18), fill);
      // Perninhas
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.66, w * 0.13, h * 0.18), Radius.circular(w * 0.05)), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.54, h * 0.66, w * 0.13, h * 0.18), Radius.circular(w * 0.05)), fill);
      // Fenda da moeda
      final slot = Paint()
        ..color = cutout
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.36, h * 0.36), Offset(w * 0.54, h * 0.36), slot);
      // Olho
      canvas.drawCircle(Offset(w * 0.64, h * 0.44), w * 0.045, cut);
    }
  }

  @override
  bool shouldRepaint(_FilledNavPainter old) => old.kind != kind || old.color != color || old.cutout != cutout;
}
