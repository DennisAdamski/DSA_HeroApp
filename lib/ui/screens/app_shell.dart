import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Wurzel-Widget der DSA-Heldenverwaltung mit plattformspezifischem Theme.
class DsaAppShell extends ConsumerWidget {
  /// Erstellt die App-Huelle mit Theme und Navigator.
  const DsaAppShell({super.key, required this.home});

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

  /// Startscreen innerhalb der App-Navigation.
  final Widget home;

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
        home: home,
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
