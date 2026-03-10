import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

/// Startet die Anwendung und initialisiert die persistenten Heldendaten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await HiveHeroRepository.create();
  final settingsRepo = await HiveSettingsRepository.create();
  await const StartupHeroImporter().importFromAssets(repository);

  runApp(
    ProviderScope(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repository),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
      ],
      child: const DsaApp(),
    ),
  );
}

/// Wurzel-Widget der DSA-Heldenverwaltung mit plattformspezifischem Theme.
class DsaApp extends ConsumerWidget {
  const DsaApp({super.key});

  static bool _isApple() =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static const _seedColor = Color(0xFF2A5A73);

  static const _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dunkelModus = ref.watch(dunkelModusProvider);
    final apple = _isApple();
    final lightBase = ThemeData.light(useMaterial3: true);
    final darkBase = ThemeData.dark(useMaterial3: true);

    return ScrollConfiguration(
      behavior: _AdaptiveScrollBehavior(),
      child: MaterialApp(
        title: 'DSA Heldenverwaltung',
        debugShowCheckedModeBanner: false,
        themeMode: dunkelModus ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          materialTapTargetSize:
              apple ? MaterialTapTargetSize.padded : null,
          colorScheme:
              ColorScheme.fromSeed(seedColor: _seedColor),
          scaffoldBackgroundColor: const Color(0xFFF2F5F7),
          textTheme: lightBase.textTheme.apply(
            fontFamily: 'Merriweather',
            bodyColor: const Color(0xFF1D2830),
            displayColor: const Color(0xFF1D2830),
          ),
          appBarTheme: AppBarTheme(centerTitle: apple),
          pageTransitionsTheme: _pageTransitionsTheme,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          materialTapTargetSize:
              apple ? MaterialTapTargetSize.padded : null,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.black,
          textTheme: darkBase.textTheme.apply(
            fontFamily: 'Merriweather',
          ),
          appBarTheme: AppBarTheme(centerTitle: apple),
          pageTransitionsTheme: _pageTransitionsTheme,
        ),
        home: const HeroesHomeScreen(),
      ),
    );
  }
}

/// Gibt auf Apple-Plattformen BouncingScrollPhysics zurueck.
class _AdaptiveScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }
}
