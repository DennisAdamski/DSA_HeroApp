import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

/// Startet die Anwendung und initialisiert die persistenten Heldendaten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await HiveHeroRepository.create();
  await const StartupHeroImporter().importFromAssets(repository);

  runApp(
    ProviderScope(
      overrides: [heroRepositoryProvider.overrideWithValue(repository)],
      child: const DsaApp(),
    ),
  );
}

/// Wurzel-Widget der DSA-Heldenverwaltung mit plattformspezifischem Theme.
class DsaApp extends StatelessWidget {
  const DsaApp({super.key});

  static bool _isApple() =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.light(useMaterial3: true);
    final apple = _isApple();
    return ScrollConfiguration(
      behavior: _AdaptiveScrollBehavior(),
      child: MaterialApp(
        title: 'DSA Heldenverwaltung',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          materialTapTargetSize:
              apple ? MaterialTapTargetSize.padded : null,
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF2A5A73)),
          scaffoldBackgroundColor: const Color(0xFFF2F5F7),
          textTheme: baseTheme.textTheme.apply(
            fontFamily: 'Merriweather',
            bodyColor: const Color(0xFF1D2830),
            displayColor: const Color(0xFF1D2830),
          ),
          appBarTheme: AppBarTheme(centerTitle: apple),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            },
          ),
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
