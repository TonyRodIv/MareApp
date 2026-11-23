import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/perf.dart';
import 'core/theme.dart';
import 'data/drive_sync.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/shell.dart';
import 'ui/widgets/kit.dart';
import 'ui/widgets/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  GoogleFonts.config.allowRuntimeFetching = false;
  late final Store store;
  await Future.wait([
    initializeDateFormatting('pt_BR'),
    DevicePerf.instance.init(),
    ProgressiveBlur.preload(),
    Store.load().then((s) => store = s),
  ]);
  final sync = SyncService.attach(store);
  runApp(
    MareApp(
      store: store,
      sync: sync,
      showLaunchAnimation: true,
    ),
  );
}

class MareApp extends StatefulWidget {
  final Store store;
  final SyncService? sync;
  final bool showLaunchAnimation;
  const MareApp({
    super.key,
    required this.store,
    this.sync,
    this.showLaunchAnimation = false,
  });

  @override
  State<MareApp> createState() => _MareAppState();
}

class _MareAppState extends State<MareApp> with WidgetsBindingObserver {
  late final SyncService _sync;
  late final bool _ownsSync;

  @override
  void initState() {
    super.initState();
    _ownsSync = widget.sync == null;
    _sync =
        widget.sync ?? SyncService.attach(widget.store, restoreSession: false);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DevicePerf.instance.refresh();
      _sync.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsSync) _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerfScope(
      perf: DevicePerf.instance,
      child: StoreScope(
      store: widget.store,
      child: SyncScope(
        sync: _sync,
        child: Builder(
          builder: (context) {
            final d = context.store.data;
            final pref = d.theme;
            final platform = MediaQuery.platformBrightnessOf(context);
            final dark =
                pref == ThemePref.dark ||
                (pref == ThemePref.auto && platform == Brightness.dark);
            final seed = d.accentColor == null
                ? accentPresets.first.$2
                : Color(d.accentColor!);
            final colors = AppColors.fromSeed(
              seed,
              dark ? Brightness.dark : Brightness.light,
            );
            final overlay = SystemUiOverlayStyle(
              statusBarColor: const Color(0x00000000),
              statusBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: const Color(0x00000000),
              systemNavigationBarDividerColor: const Color(0x00000000),
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: AppTheme(
                colors: colors,
                child: CupertinoApp(
                  title: 'maré',
                  debugShowCheckedModeBanner: false,
                  theme: cupertinoThemeFor(colors),
                  locale: const Locale('pt', 'BR'),
                  supportedLocales: const [Locale('pt', 'BR')],
                  localizationsDelegates: const [
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                  ],
                  home: _LaunchReveal(
                    enabled: widget.showLaunchAnimation,
                    child: const _Root(),
                  ),
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

/// Transição de abertura estilo apps do Google: inicia exibindo o título
/// "maré." centralizado sobre o fundo do tema e anima suavemente a entrada
/// do aplicativo por baixo antes de sair da árvore.
class _LaunchReveal extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const _LaunchReveal({required this.enabled, required this.child});

  @override
  State<_LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends State<_LaunchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _done = !widget.enabled;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.enabled) {
      _ctrl.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _done = true);
        }
      });
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final c = context.c;
    final wordIn = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.34, curve: easeOutExpo),
    );
    final reveal = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.42, 1.0, curve: easeOutExpo),
    );

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, appChild) {
        final r = reveal.value;
        final w = wordIn.value;
        final splashOpacity = (1.0 - r).clamp(0.0, 1.0);
        final appScale = 0.965 + 0.035 * r;
        final splashScale = (0.94 + 0.06 * w) + 0.08 * r;

        return Stack(
          children: [
            Transform.scale(
              scale: appScale,
              child: Opacity(opacity: r.clamp(0.0, 1.0), child: appChild),
            ),
            if (splashOpacity > 0.001)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: r > 0.25,
                  child: Opacity(
                    opacity: splashOpacity,
                    child: ColoredBox(
                      color: c.bg,
                      child: Stack(
                        children: [
                          const GlowBackground(height: 520),
                          Center(
                            child: Transform.scale(
                              scale: splashScale,
                              child: const MareWordmark(size: 46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final done = context.store.data.onboardingDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      child: done
          ? const Shell(key: ValueKey('shell'))
          : const Onboarding(key: ValueKey('onb')),
    );
  }
}
