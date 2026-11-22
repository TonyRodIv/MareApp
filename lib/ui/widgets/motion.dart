import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
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
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

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
    if (widget.from != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
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
    duration: duration,
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

// ── Gesto preditivo do Android + rotas fluidas ─────────────

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Envolve uma rota com suporte ao gesto preditivo nativo do Android
/// (escala progressiva, cantos arredondados dinâmicos, leve deslocamento
/// seguindo o dedo e revelação suave da tela abaixo). Quando não há gesto
/// preditivo em andamento, delega para [fallbackBuilder].
class PredictiveBackShell extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) fallbackBuilder;
  final Widget child;

  const PredictiveBackShell({
    super.key,
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.fallbackBuilder,
    required this.child,
  });

  @override
  State<PredictiveBackShell> createState() => _PredictiveBackShellState();
}

class _PredictiveBackShellState extends State<PredictiveBackShell>
    with WidgetsBindingObserver {
  PredictiveBackEvent? _startEvent;
  PredictiveBackEvent? _currentEvent;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (_isAndroid) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _canHandle =>
      _isAndroid && widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_canHandle) return false;
    widget.route.handleStartBackGesture(progress: 1.0 - backEvent.progress);
    if (mounted) {
      setState(() {
        _startEvent = backEvent;
        _currentEvent = backEvent;
        _committing = false;
      });
    }
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!widget.route.popGestureInProgress) return;
    _currentEvent = backEvent;
    widget.route.handleUpdateBackGestureProgress(
      progress: 1.0 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    if (!widget.route.popGestureInProgress) return;
    _committing = false;
    _startEvent = null;
    _currentEvent = null;
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    if (!widget.route.popGestureInProgress) return;
    _committing = true;
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroid || !widget.route.popGestureInProgress) {
      return widget.fallbackBuilder(
        context,
        widget.animation,
        widget.secondaryAnimation,
        widget.child,
      );
    }

    final c = context.c;
    // RepaintBoundary rasteriza a tela uma vez na GPU durante o gesto preditivo.
    final cachedChild = RepaintBoundary(child: widget.child);

    return AnimatedBuilder(
      animation: widget.animation,
      child: cachedChild,
      builder: (_, child) {
        final ev = _currentEvent ?? _startEvent;
        final fromLeft = ev?.swipeEdge == SwipeEdge.left;
        final startY = _startEvent?.touchOffset?.dy;
        final curY = _currentEvent?.touchOffset?.dy;
        final rawDy = (startY != null && curY != null)
            ? ((curY - startY) * 0.08).clamp(-16.0, 16.0)
            : 0.0;

        final p = widget.animation.value.clamp(0.0, 1.0);
        final drag = (1.0 - p).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(drag);
        final scale = 1.0 - 0.11 * t;
        final dx = (fromLeft ? 1.0 : -1.0) * 20.0 * t;
        final dy = rawDy * t;
        final radius = 28.0 * t;
        final cardOpacity = _committing ? (p * 2.2).clamp(0.0, 1.0) : 1.0;
        final scrimAlpha = (0.22 * (1.0 - t) * cardOpacity).clamp(0.0, 0.24);

        // ClipRRect + borda fina evita blur de BoxShadow em tela cheia a 120fps.
        Widget card = radius > 0.5
            ? ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: c.isDark
                          ? Palette.neutral0.withValues(alpha: 0.12 * t)
                          : Palette.neutral950.withValues(alpha: 0.08 * t),
                    ),
                  ),
                  child: child,
                ),
              )
            : child!;

        card = Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(scale: scale, child: card),
        );
        if (cardOpacity < 0.999) {
          card = Opacity(opacity: cardOpacity, child: card);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (scrimAlpha > 0.002)
              IgnorePointer(
                child: ColoredBox(
                  color: Palette.neutral950.withValues(alpha: scrimAlpha),
                ),
              ),
            card,
          ],
        );
      },
    );
  }
}

/// Rota principal do maré:
/// - Quando [morph] é `false`: deslizamento horizontal suave com leve paralaxe
///   e escala no Android (320ms), e transição Cupertino nativa no iOS/macOS.
/// - Quando [morph] é `true`: transição "só de elementos" — sem cortina
///   deslizando, o fundo permanece estável enquanto os elementos `Hero` voam e
///   se transformam no lugar.
/// Em ambos os modos, o gesto preditivo nativo do Android funciona ao arrastar
/// da borda da tela.
class MarePageRoute<V> extends CupertinoPageRoute<V> {
  final bool morph;

  MarePageRoute({required super.builder, this.morph = false});

  @override
  Duration get transitionDuration => morph
      ? const Duration(milliseconds: 380)
      : const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => morph
      ? const Duration(milliseconds: 260)
      : const Duration(milliseconds: 240);

  Widget _buildFallback(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    if (morph) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeInCubic),
      );
      return FadeTransition(opacity: fadeIn, child: child);
    }

    final isApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (isApple) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Shared-axis horizontal sutil e responsivo (sem zoom lento de 800ms).
    final enter = CurvedAnimation(
      parent: animation,
      curve: easeOutExpo,
      reverseCurve: Curves.easeOutCubic,
    );
    final enterFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: easeOutExpo,
      reverseCurve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([enter, exit]),
      child: child,
      builder: (_, ch) {
        if (enter.value >= 0.999 && exit.value <= 0.001) return ch!;
        final dx = (1.0 - enter.value) * 0.08 - exit.value * 0.03;
        final scale = (0.986 + 0.014 * enter.value) * (1.0 - 0.014 * exit.value);
        return FadeTransition(
          opacity: enterFade,
          child: FractionalTranslation(
            translation: Offset(dx, 0),
            child: Transform.scale(scale: scale, child: ch),
          ),
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_isAndroid) {
      return PredictiveBackShell(
        route: this,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fallbackBuilder: _buildFallback,
        child: child,
      );
    }
    return _buildFallback(context, animation, secondaryAnimation, child);
  }
}

/// Transição modal fluida para fluxos de criação (sobe suavemente com fade)
/// com suporte ao gesto preditivo nativo do Android.
class FluidModalRoute<V> extends PageRoute<V> {
  final WidgetBuilder builder;
  FluidModalRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  Widget _buildFallback(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final t = CurvedAnimation(
      parent: animation,
      curve: easeOutExpo,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      reverseCurve: const Interval(0.25, 1.0, curve: Curves.easeIn),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.09),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_isAndroid) {
      return PredictiveBackShell(
        route: this,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fallbackBuilder: _buildFallback,
        child: child,
      );
    }
    return _buildFallback(context, animation, secondaryAnimation, child);
  }
}

// ── Helpers para Hero sem artefatos ─────────────────────────

/// Texto com transição `Hero` limpa: interpola estilo suavemente e garante
/// ausência de sublinhado amarelo ou overflow durante o voo no Overlay.
class HeroText extends StatelessWidget {
  final String? tag;
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;

  const HeroText(
    this.text, {
    super.key,
    required this.tag,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
  });

  Alignment _alignmentFor(TextAlign a) => switch (a) {
    TextAlign.center => Alignment.center,
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: style.copyWith(decoration: TextDecoration.none),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
    if (tag == null) return child;
    return Hero(
      tag: tag!,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final fromW = fromHeroContext.widget;
            final toW = toHeroContext.widget;
            final fromText = fromW is Hero && fromW.child is Text
                ? fromW.child as Text
                : null;
            final toText = toW is Hero && toW.child is Text
                ? toW.child as Text
                : null;
            final sFrom =
                (fromText?.style ?? style).copyWith(decoration: TextDecoration.none);
            final sTo =
                (toText?.style ?? style).copyWith(decoration: TextDecoration.none);
            final aFrom = _alignmentFor(fromText?.textAlign ?? textAlign);
            final aTo = _alignmentFor(toText?.textAlign ?? textAlign);

            return AnimatedBuilder(
              animation: animation,
              builder: (_, _) {
                final t = Curves.easeInOutCubic.transform(animation.value);
                final lerpedStyle = TextStyle.lerp(sFrom, sTo, t) ?? sTo;
                final lerpedAlign =
                    Alignment.lerp(aFrom, aTo, t) ?? Alignment.centerLeft;
                return Align(
                  alignment: lerpedAlign,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: lerpedAlign,
                    child: DefaultTextStyle(
                      style: lerpedStyle,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      child: Text(
                        text,
                        style: lerpedStyle,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            );
          },
      child: child,
    );
  }
}

/// Shuttle genérico que escala o elemento de destino sem overflow durante voo.
Widget heroFittedShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final dest = toHeroContext.widget;
  final child = dest is Hero ? dest.child : dest;
  return FittedBox(fit: BoxFit.contain, child: child);
}
