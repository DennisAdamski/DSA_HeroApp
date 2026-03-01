import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/startup_hero_importer.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

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

class DsaApp extends StatelessWidget {
  const DsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.light(useMaterial3: true);
    return MaterialApp(
      title: 'DSA Heldenverwaltung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4B57)),
        scaffoldBackgroundColor: const Color(0xFFEFF3F6),
        textTheme: baseTheme.textTheme.apply(
          fontFamily: 'Source Serif 4',
          bodyColor: const Color(0xFF1A252C),
          displayColor: const Color(0xFF1A252C),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const HeroesHomeScreen(),
    );
  }
}
