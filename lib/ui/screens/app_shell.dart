import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Wurzel-Widget der DSA-Heldenverwaltung mit plattformspezifischem Theme.
class DsaAppShell extends ConsumerWidget {
  /// Erstellt die App-Huelle mit Theme und Navigator.
  const DsaAppShell({super.key, required this.home});

  static bool _isApple() =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

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

    return ScrollConfiguration(
      behavior: _AdaptiveScrollBehavior(),
      child: MaterialApp(
        title: 'DSA Heldenverwaltung',
        debugShowCheckedModeBanner: false,
        themeMode: dunkelModus ? ThemeMode.dark : ThemeMode.light,
        theme:
            buildCodexTheme(
              brightness: Brightness.light,
              centerAppBarTitle: apple,
            ).copyWith(
              materialTapTargetSize: apple
                  ? MaterialTapTargetSize.padded
                  : null,
              pageTransitionsTheme: _pageTransitionsTheme,
            ),
        darkTheme:
            buildCodexTheme(
              brightness: Brightness.dark,
              centerAppBarTitle: apple,
            ).copyWith(
              materialTapTargetSize: apple
                  ? MaterialTapTargetSize.padded
                  : null,
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
