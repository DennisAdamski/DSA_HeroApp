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

  static const _seedColor = Color(0xFF27465B);
  static const _paperBackground = Color(0xFFF5F0E6);
  static const _paperSurface = Color(0xFFFFFBF5);
  static const _paperOutline = Color(0xFFD7CCB7);

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
    final lightScheme = ColorScheme.fromSeed(seedColor: _seedColor).copyWith(
      surface: _paperSurface,
      surfaceContainerLowest: const Color(0xFFF9F4EA),
      surfaceContainerLow: const Color(0xFFF3ECDD),
      surfaceContainer: const Color(0xFFEDE3D0),
      surfaceContainerHigh: const Color(0xFFE8DCC5),
      surfaceContainerHighest: const Color(0xFFE0D1B6),
      outlineVariant: _paperOutline,
      primary: const Color(0xFF27465B),
      secondary: const Color(0xFF766244),
      tertiary: const Color(0xFF7E4D36),
    );
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF161411),
          surfaceContainerLowest: const Color(0xFF11100D),
          surfaceContainerLow: const Color(0xFF1B1915),
          surfaceContainer: const Color(0xFF24211B),
          surfaceContainerHigh: const Color(0xFF2E2A23),
          surfaceContainerHighest: const Color(0xFF39332A),
          outlineVariant: const Color(0xFF564D3F),
          primary: const Color(0xFF95B7D0),
          secondary: const Color(0xFFD6BD98),
          tertiary: const Color(0xFFE0A98D),
        );
    final lightTextTheme = lightBase.textTheme
        .copyWith(
          displayLarge: lightBase.textTheme.displayLarge?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          displayMedium: lightBase.textTheme.displayMedium?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          displaySmall: lightBase.textTheme.displaySmall?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: lightBase.textTheme.headlineLarge?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: lightBase.textTheme.headlineMedium?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: lightBase.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          titleLarge: lightBase.textTheme.titleLarge?.copyWith(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.w700,
          ),
          titleMedium: lightBase.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(
          bodyColor: const Color(0xFF1D2830),
          displayColor: const Color(0xFF1D2830),
        );
    final darkTextTheme = darkBase.textTheme.copyWith(
      displayLarge: darkBase.textTheme.displayLarge?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      displayMedium: darkBase.textTheme.displayMedium?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      displaySmall: darkBase.textTheme.displaySmall?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: darkBase.textTheme.headlineLarge?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: darkBase.textTheme.headlineMedium?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: darkBase.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      titleLarge: darkBase.textTheme.titleLarge?.copyWith(
        fontFamily: 'Merriweather',
        fontWeight: FontWeight.w700,
      ),
      titleMedium: darkBase.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return ScrollConfiguration(
      behavior: _AdaptiveScrollBehavior(),
      child: MaterialApp(
        title: 'DSA Heldenverwaltung',
        debugShowCheckedModeBanner: false,
        themeMode: dunkelModus ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          materialTapTargetSize: apple ? MaterialTapTargetSize.padded : null,
          colorScheme: lightScheme,
          scaffoldBackgroundColor: _paperBackground,
          textTheme: lightTextTheme,
          cardTheme: CardThemeData(
            color: lightScheme.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: lightScheme.outlineVariant),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: lightScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: lightScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: lightScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: lightScheme.primary, width: 1.4),
            ),
          ),
          dividerTheme: DividerThemeData(color: lightScheme.outlineVariant),
          appBarTheme: AppBarTheme(
            centerTitle: apple,
            backgroundColor: lightScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: lightScheme.surface,
            indicatorColor: lightScheme.secondaryContainer,
          ),
          pageTransitionsTheme: _pageTransitionsTheme,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          materialTapTargetSize: apple ? MaterialTapTargetSize.padded : null,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: const Color(0xFF11100D),
          textTheme: darkTextTheme,
          cardTheme: CardThemeData(
            color: darkScheme.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: darkScheme.outlineVariant),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: darkScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: darkScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: darkScheme.primary, width: 1.4),
            ),
          ),
          dividerTheme: DividerThemeData(color: darkScheme.outlineVariant),
          appBarTheme: AppBarTheme(
            centerTitle: apple,
            backgroundColor: darkScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: darkScheme.surface,
            indicatorColor: darkScheme.secondaryContainer,
          ),
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
