import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/perf.dart';
import '../../core/theme.dart';

/// Movimento "fluido": molas físicas definidas por frequência (w) e
/// amortecimento (z), como em fluidui. stiffness = w², damping = 2·z·w.
class Springs {
  static SpringDescription of(double w, double z) =>
      SpringDescription(mass: 1, stiffness: w * w, damping: 2 * z * w);

  /// Morph de corpos (pílulas, cards que crescem).
  static final body = of(26, 0.85);

  /// Respostas rápidas (toque, switch, indicador de aba).
  static final snappy = of(32, 0.82);

  /// Valores e barras se acomodando.
  static final settle = of(22, 0.86);

  /// Elástico e ágil, para confirmações.
  static final bouncy = of(22, 0.62);
}

const easeOutExpo = Cubic(0.22, 1, 0.36, 1);

bool reduceMotion(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
    context.perfRead.simplifyMotion;

// ── Valor que persegue o alvo com mola (interrompível) ──────

class SpringBuilder extends StatefulWidget {
  final double value;
  final SpringDescription? spring;
  final Widget Function(BuildContext, double value, double velocity) builder;
  final double? from;
  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.spring,
    this.from,
  });

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.from ?? widget.value,
  );

  @override
  void initState() {
    super.initState();
    if (widget.from != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    }
  }

  void _go() {
    if (!mounted) return;
    if (reduceMotion(context)) {
      _c.value = widget.value;
      return;
    }
    _c.animateWith(
      SpringSimulation(
        widget.spring ?? Springs.settle,
        _c.value,
        widget.value,
        _c.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(SpringBuilder old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _go();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (ctx, _) => widget.builder(ctx, _c.value, _c.velocity),
  );
}

// ── Entrada sutil e consistente (sem excesso de blur/delay) ─

class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final double dy;
  final bool blur;
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = Duration.zero,
    this.dy = 6,
    this.blur = false,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    final delay =
        widget.baseDelay +
        Duration(milliseconds: 16 * widget.index.clamp(0, 3));
    if (delay == Duration.zero) {
      _a.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _a.forward();
      });
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    final t = CurvedAnimation(parent: _a, curve: easeOutExpo);
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (ctx, child) {
        final v = t.value;
        if (v >= 0.999) return child!;
        return Opacity(
          opacity: clampOpacity(v),
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

double clampOpacity(double v) => v.clamp(0.0, 1.0);

// ── Troca suave de conteúdo ─────────────────────────────────

class BlurSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Alignment alignment;
  const BlurSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: reduceMotion(context) ? Duration.zero : duration,
    switchInCurve: easeOutExpo,
    switchOutCurve: Curves.easeOut,
    layoutBuilder: (cur, prev) =>
        Stack(alignment: alignment, children: [...prev, ?cur]),
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(anim),
        alignment: alignment,
        child: child,
      ),
    ),
    child: child,
  );
}

// ── Contador de valores (Stat Counter) ──────────────────────

/// Número em dinheiro que transita suavemente quando o valor muda.
class CountingMoney extends StatelessWidget {
  final Cents cents;
  final Widget Function(Cents) builder;
  const CountingMoney({super.key, required this.cents, required this.builder});

  @override
  Widget build(BuildContext context) => SpringBuilder(
    value: cents.toDouble(),
    spring: Springs.settle,
    builder: (_, v, _) => builder(v.round()),
  );
}

// ── Switch com mola e "esticada" pela velocidade ────────────

class SpringSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  const SpringSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const travel = 20.0;
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(!value);
        },
        child: SizedBox(
          width: 52,
          height: 44, // alvo de toque ≥ 44
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 32,
              decoration: ShapeDecoration(
                color: value ? c.primary : c.cardAlt,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: value ? BorderSide.none : BorderSide(color: c.border),
                ),
              ),
              child: SpringBuilder(
                value: value ? 1 : 0,
                spring: Springs.settle,
                builder: (_, t, v) {
                  final stretch = math.min(
                    0.10,
                    (v * travel).abs() * 0.002,
                  );
                  return Stack(
                    children: [
                      Positioned(
                        left: 3 + travel * t.clamp(0.0, 1.0),
                        top: 2,
                        child: Transform.scale(
                          scaleX: 1 + stretch,
                          scaleY: 1 - stretch * 0.25,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: value
                                  ? c.onPrimary
                                  : (c.isDark
                                        ? Palette.neutral300
                                        : Palette.neutral0),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barra que cresce com mola (Spring Bars) ─────────────────

class SpringBar extends StatelessWidget {
  final double fraction; // 0..1
  final Color color;
  final Color track;
  final double height;
  const SpringBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.track,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) => SpringBuilder(
    value: fraction.clamp(0.0, 1.0),
    from: 0,
    spring: Springs.settle,
    builder: (_, v, _) => Container(
      height: height,
      decoration: ShapeDecoration(color: track, shape: const StadiumBorder()),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v.clamp(0.0, 1.0),
        child: Container(
          decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
        ),
      ),
    ),
  );
}

// ── Rota modal ultraleve ────────────────────────────────────

/// Transição modal fluida com curva easeOutExpo, leve escala e fade suave.
class FluidModalRoute<V> extends PageRouteBuilder<V> {
  FluidModalRoute({required WidgetBuilder builder})
    : super(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, _, _) => builder(ctx),
        transitionsBuilder: (ctx, a, _, child) {
          if (reduceMotion(ctx)) return child;
          final t = CurvedAnimation(
            parent: a,
            curve: easeOutExpo,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: a,
              curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(t),
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(t),
                child: child,
              ),
            ),
          );
        },
      );
}
