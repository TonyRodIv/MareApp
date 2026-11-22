import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/shell.dart';
import 'ui/widgets/kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('pt_BR');
  await ProgressiveBlur.preload();
  final store = await Store.load();
  runApp(MareApp(store: store));
}

class MareApp extends StatelessWidget {
  final Store store;
  const MareApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: Builder(
        builder: (context) {
          final d = context.store.data;
          final pref = d.theme;
          final platform = MediaQuery.platformBrightnessOf(context);
          final dark =
              pref == ThemePref.dark ||
              (pref == ThemePref.auto && platform == Brightness.dark);
          final seed = d.accentColor == null ? accentPresets.first.$2 : Color(d.accentColor!);
          final colors = AppColors.fromSeed(seed, dark ? Brightness.dark : Brightness.light);
          final overlay = SystemUiOverlayStyle(
            statusBarColor: const Color(0x00000000),
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarDividerColor: const Color(0x00000000),
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          );
          SystemChrome.setSystemUIOverlayStyle(overlay);
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
                home: const _Root(),
              ),
            ),
          );
        },
      ),
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
