import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show PredictiveBackPageTransitionsBuilder;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/native_bridge.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'add_expense.dart';
import 'box_form.dart';
import 'caixinhas.dart';
import 'extrato.dart';
import 'home.dart';
import 'insights.dart';
import 'profile.dart';

/// Destino configurável da barra de navegação inferior.
class NavDestination {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool locked;
  const NavDestination({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.locked = false,
  });
}

/// Todas as telas que podem ser fixadas na barra de navegação inferior.
const navDestinations = <NavDestination>[
  NavDestination(
    id: 'home',
    label: 'Carteira',
    subtitle: 'Resumo do ciclo e saldo livre',
    icon: LucideIcons.wallet,
  ),
  NavDestination(
    id: 'extrato',
    label: 'Extrato',
    subtitle: 'Todos os gastos e filtros',
    icon: LucideIcons.receiptText,
  ),
  NavDestination(
    id: 'caixinhas',
    label: 'Caixinhas',
    subtitle: 'Metas e reservas mensais',
    icon: LucideIcons.piggyBank,
  ),
  NavDestination(
    id: 'categorias',
    label: 'Categorias',
    subtitle: 'Divisão de gastos por categoria',
    icon: LucideIcons.chartPie,
  ),
  NavDestination(
    id: 'assinaturas',
    label: 'Assinaturas',
    subtitle: 'Serviços recorrentes e gráfico',
    icon: LucideIcons.tv,
  ),
  NavDestination(
    id: 'historico',
    label: 'Histórico',
    subtitle: 'Evolução dos últimos ciclos',
    icon: LucideIcons.chartColumn,
  ),
  NavDestination(
    id: 'perfil',
    label: 'Seu Perfil',
    subtitle: 'Finanças e configurações',
    icon: LucideIcons.user,
    locked: true,
  ),
];

/// Resolve a lista efetiva de abas fixadas (2 a 4 itens, sempre com `perfil`).
List<String> effectiveNavTabs(AppData d) {
  final validIds = {for (final n in navDestinations) n.id};
  if (d.navTabs.isEmpty) {
    return d.boxes.isNotEmpty
        ? const ['home', 'extrato', 'caixinhas', 'perfil']
        : const ['home', 'extrato', 'perfil'];
  }
  final out = <String>[];
  for (final id in d.navTabs) {
    if (validIds.contains(id) && !out.contains(id) && out.length < 4) {
      out.add(id);
    }
  }
  if (!out.contains('perfil')) {
    if (out.length >= 4) out.removeLast();
    out.add('perfil');
  }
  if (out.length < 2) {
    if (!out.contains('home')) out.insert(0, 'home');
  }
  return out;
}

/// Rota com gesto preditivo nativo do Android (mantendo a transição Cupertino
/// nativa no iOS/macOS). Usada tanto na rota raiz quanto nas páginas empilhadas
/// para que a tela anterior nunca deslize -1/3 deixando faixa escura à direita.
class _PredictivePageRoute<V> extends CupertinoPageRoute<V> {
  _PredictivePageRoute({required super.builder, super.settings});

  static const _androidBuilder = PredictiveBackPageTransitionsBuilder();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Color? get barrierColor => _isAndroid ? null : super.barrierColor;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_isAndroid) {
      return _androidBuilder.buildTransitions<V>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Cria a rota padrão do app (incluindo a rota inicial `/`) com suporte ao
/// gesto preditivo do Android sem deslocamento lateral Cupertino na tela base.
PageRoute<V> createAppRoute<V>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) => _PredictivePageRoute<V>(builder: builder, settings: settings);

/// Navega com gesto preditivo nativo no Android e swipe Cupertino no iOS.
Future<V?> push<V>(BuildContext context, Widget page) =>
    Navigator.of(context).push<V>(createAppRoute<V>(builder: (_) => page));

/// Abre fluxos de criação com transição modal ultraleve.
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

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final _tabId = ValueNotifier<String>('home');
  final _extratoFilter = ValueNotifier<ExtratoFilter?>(null);
  final Map<String, Widget> _pageCache = {};
  Store? _store;
  StreamSubscription<String>? _bankSub;

  Widget _pageFor(String id) => _pageCache.putIfAbsent(
    id,
    () => RepaintBoundary(
      child: switch (id) {
        'home' => const HomeScreen(),
        'extrato' => ExtratoScreen(filter: _extratoFilter),
        'caixinhas' => const CaixinhasScreen(),
        'categorias' => const CategoriesScreen(embedded: true),
        'assinaturas' => const SubscriptionsScreen(embedded: true),
        'historico' => const HistoryScreen(embedded: true),
        'perfil' => const ProfileScreen(),
        _ => const HomeScreen(),
      },
    ),
  );

  @override
  void initState() {
    super.initState();
    shellNav._impl = _goTo;
    WidgetsBinding.instance.addObserver(this);
    _bankSub = BankNotifications.events.listen((event) {
      if (!mounted) return;
      if (event == 'launch_add_expense') {
        openAddExpense(context);
      } else if (event == 'suggestions_changed') {
        _processApprovedSuggestions();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _store = context.storeRead..addListener(_syncWidgets);
      _syncWidgets();
      _processApprovedSuggestions();
      _checkLaunchAction();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _syncWidgets();
      _processApprovedSuggestions();
      _checkLaunchAction();
    }
  }

  void _syncWidgets() {
    final s = _store;
    if (s != null) NativeWidgets.syncFromStore(s);
  }

  Future<void> _checkLaunchAction() async {
    final action = await BankNotifications.consumeLaunchAction();
    if (!mounted) return;
    if (action == 'com.mare.mare.ACTION_ADD_EXPENSE') {
      openAddExpense(context);
    }
  }

  Future<void> _processApprovedSuggestions() async {
    final s = _store ?? (mounted ? context.storeRead : null);
    if (s == null) return;
    final items = await BankNotifications.consumeApproved();
    if (items.isEmpty || !mounted) return;
    var count = 0;
    for (final item in items) {
      if (BankNotifications.saveSuggestion(s, item) == null) count++;
    }
    if (count > 0 && mounted) {
      toast(
        context,
        count == 1
            ? 'Gasto salvo: ${items.first.name}'
            : '$count gastos salvos pela notificação',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bankSub?.cancel();
    _store?.removeListener(_syncWidgets);
    if (shellNav._impl == _goTo) shellNav._impl = null;
    _tabId.dispose();
    _extratoFilter.dispose();
    super.dispose();
  }

  static const _legacyTabIds = ['home', 'extrato', 'caixinhas', 'perfil'];

  void _goTo(int tab, {ExtratoFilter? filter}) {
    final targetId = (tab >= 0 && tab < _legacyTabIds.length)
        ? _legacyTabIds[tab]
        : 'home';
    final s = context.storeRead;
    if (targetId == 'caixinhas' && s.data.boxes.isEmpty) {
      pushFluid(context, const BoxForm());
      return;
    }
    final tabs = effectiveNavTabs(s.data);
    if (tabs.contains(targetId)) {
      if (filter != null) _extratoFilter.value = filter;
      _tabId.value = targetId;
      return;
    }
    // Se a tela não está fixada na barra inferior, abre como página empilhada.
    if (targetId == 'extrato') {
      push(
        context,
        ExtratoScreen(initialFilter: filter, standalone: true),
      );
    } else if (targetId == 'caixinhas') {
      push(context, const CaixinhasScreen(standalone: true));
    } else if (targetId == 'perfil') {
      _tabId.value = 'perfil';
    }
  }

  NavItem _buildNavItem(String id, AppData d) {
    final dest = navDestinations.firstWhere(
      (n) => n.id == id,
      orElse: () => navDestinations.first,
    );
    return switch (id) {
      'home' => NavItem(
        dest.label,
        dest.icon,
        activeBuilder: (col, sz) =>
            _FilledNavIcon(kind: 0, color: col, size: sz),
      ),
      'extrato' => NavItem(
        dest.label,
        dest.icon,
        activeBuilder: (col, sz) =>
            _FilledNavIcon(kind: 1, color: col, size: sz),
      ),
      'caixinhas' => NavItem(
        dest.label,
        dest.icon,
        activeBuilder: (col, sz) =>
            _FilledNavIcon(kind: 2, color: col, size: sz),
      ),
      'perfil' => NavItem(
        dest.label,
        dest.icon,
        custom: Avatar(path: d.avatarPath, name: d.userName, size: 24),
      ),
      _ => NavItem(dest.label, dest.icon),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final tabs = effectiveNavTabs(s.data);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ShellScope(
      goTo: _goTo,
      child: SheetScaler(
        child: CupertinoPageScaffold(
          backgroundColor: c.bg,
          child: Stack(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _tabId,
                builder: (_, activeId, _) {
                  final idx = tabs.indexOf(activeId);
                  final safeIdx = idx < 0 ? 0 : idx;
                  final effectiveId = tabs[safeIdx];
                  if (idx < 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !tabs.contains(_tabId.value)) {
                        _tabId.value = tabs.first;
                      }
                    });
                  }
                  // Monta cada aba sob demanda na primeira visita (reduz tempo
                  // de abertura e RAM inicial em aparelhos modestos) e mantém
                  // em cache após visitada para troca instantânea.
                  _pageFor(effectiveId);
                  final orderedPages = [
                    for (final id in tabs)
                      _pageCache[id] ?? const SizedBox.shrink(),
                  ];
                  return IndexedStack(index: safeIdx, children: orderedPages);
                },
              ),
              // Progressive blur mais encorpado atrás da barra inferior flutuante
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 140 + bottom,
                child: ProgressiveBlur(
                  direction: AxisDirection.up,
                  maxSigma: 22,
                  tint: c.bg,
                  tintOpacity: c.isDark ? 0.86 : 0.84,
                ),
              ),
              // Botão flutuante de adicionar gasto na aba Extrato (ACIMA do blur!)
              ValueListenableBuilder<String>(
                valueListenable: _tabId,
                builder: (_, activeId, _) {
                  final showFab = activeId == 'extrato' && tabs.contains('extrato');
                  final fabBottom =
                      66 + (bottom > 0 ? bottom : Space.base) + Space.md;
                  final pad = sidePadding(context);
                  return Positioned(
                    right: pad,
                    bottom: fabBottom,
                    child: IgnorePointer(
                      ignoring: !showFab,
                      child: AnimatedScale(
                        scale: showFab ? 1.0 : 0.72,
                        duration: const Duration(milliseconds: 180),
                        curve: easeOutExpo,
                        child: AnimatedOpacity(
                          opacity: showFab ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Pressable(
                            semanticLabel: 'Adicionar gasto',
                            scale: 0.92,
                            onTap: () => openAddExpense(context),
                            child: Builder(
                              builder: (_) {
                                final (fabBg, fabFg) = softActionTone(
                                  c.palette.primary[500],
                                  isDark: c.isDark,
                                );
                                return Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: fabBg,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Palette.neutral950.withValues(
                                          alpha: c.isDark ? 0.48 : 0.18,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    LucideIcons.plus,
                                    size: 24,
                                    color: fabFg,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _tabId,
                      builder: (_, activeId, _) {
                        final idx = tabs.indexOf(activeId);
                        final navIndex = idx < 0 ? 0 : idx;
                        return FloatingNavBar(
                          index: navIndex,
                          onTap: (i) => _tabId.value = tabs[i],
                          items: [
                            for (final id in tabs) _buildNavItem(id, s.data),
                          ],
                        );
                      },
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
