import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
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
    final variante = ref.watch(uiVarianteProvider);
    final debugModus = ref.watch(debugModusProvider);
    final apple = _isApple();

    return ScrollConfiguration(
      behavior: _AdaptiveScrollBehavior(),
      child: MaterialApp(
        title: 'DSA Heldenverwaltung',
        debugShowCheckedModeBanner: false,
        themeMode: dunkelModus ? ThemeMode.dark : ThemeMode.light,
        theme:
            buildAppTheme(
              variante: variante,
              brightness: Brightness.light,
              centerAppBarTitle: apple,
            ).copyWith(
              materialTapTargetSize: apple
                  ? MaterialTapTargetSize.padded
                  : null,
              pageTransitionsTheme: _pageTransitionsTheme,
            ),
        darkTheme:
            buildAppTheme(
              variante: variante,
              brightness: Brightness.dark,
              centerAppBarTitle: apple,
            ).copyWith(
              materialTapTargetSize: apple
                  ? MaterialTapTargetSize.padded
                  : null,
              pageTransitionsTheme: _pageTransitionsTheme,
            ),
        home: home,
        builder: (context, child) {
          if (!debugModus) return child!;
          final layout = appLayoutOf(context);
          final label = switch (layout) {
            AppLayoutClass.compact => 'Mobil',
            AppLayoutClass.tabletPortrait => 'iPad Portrait',
            AppLayoutClass.tabletLandscape => 'iPad Landscape',
            AppLayoutClass.desktopWide => 'Breit',
          };
          return Stack(
            children: [
              child!,
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 8,
                child: IgnorePointer(
                  child: Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(context).colorScheme.tertiaryContainer,
                    labelStyle: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
