import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';

/// Semantische Codex-Designwerte fuer die Workspace-Oberflaeche.
@immutable
class CodexTheme extends ThemeExtension<CodexTheme> {
  /// Erstellt die Codex-Farb- und Radius-Tokens.
  const CodexTheme({
    required this.parchment,
    required this.parchmentStrong,
    required this.panel,
    required this.panelRaised,
    required this.ink,
    required this.inkMuted,
    required this.brass,
    required this.brassMuted,
    required this.rule,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.heroGradient,
    required this.heroGradientSoft,
    required this.sectionRadius,
    required this.panelRadius,
    this.showDecoration = true,
  });

  /// Hauptflaeche mit Pergamentcharakter.
  final Color parchment;

  /// Staerker gefaerbte Pergamentflaeche fuer Header und Akzente.
  final Color parchmentStrong;

  /// Standardpanel fuer Karten und Tabellen.
  final Color panel;

  /// Hoeherliegende Panel-Variante fuer Header, Rail und Navigation.
  final Color panelRaised;

  /// Primaere Text-/Linienfarbe.
  final Color ink;

  /// Gedaempfte Textfarbe fuer Hinweise und Helper.
  final Color inkMuted;

  /// Metallischer Akzent fuer markante UI-Elemente.
  final Color brass;

  /// Gedaempfte Metallfarbe fuer Linien und Badge-Raender.
  final Color brassMuted;

  /// Allgemeine Kontur-/Trennerfarbe.
  final Color rule;

  /// Akzentfarbe fuer aktive Bereiche.
  final Color accent;

  /// Positiv-/Stabilitaetsfarbe.
  final Color success;

  /// Warnfarbe fuer Hinweise und BE-/Wund-Fokus.
  final Color warning;

  /// Fehler- und Gefahrenfarbe.
  final Color danger;

  /// Satter Verlauf fuer den Workspace-Kopf.
  final Gradient heroGradient;

  /// Weicher Verlauf fuer Rails und Sidecars.
  final Gradient heroGradientSoft;

  /// Standardradius grosser Sektionen.
  final double sectionRadius;

  /// Standardradius kleiner Panels und Badges.
  final double panelRadius;

  /// Steuert, ob dekorative Elemente (Texturen, Wasserzeichen, Gradients,
  /// Asset-Illustrationen) angezeigt werden.
  final bool showDecoration;

  /// Liefert das aktive Codex-Theme aus dem Build-Kontext.
  static CodexTheme of(BuildContext context) {
    return Theme.of(context).extension<CodexTheme>()
        ?? (Theme.of(context).brightness == Brightness.dark
            ? _darkCodexTheme()
            : _lightCodexTheme());
  }

  @override
  CodexTheme copyWith({
    Color? parchment,
    Color? parchmentStrong,
    Color? panel,
    Color? panelRaised,
    Color? ink,
    Color? inkMuted,
    Color? brass,
    Color? brassMuted,
    Color? rule,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Gradient? heroGradient,
    Gradient? heroGradientSoft,
    double? sectionRadius,
    double? panelRadius,
    bool? showDecoration,
  }) {
    return CodexTheme(
      parchment: parchment ?? this.parchment,
      parchmentStrong: parchmentStrong ?? this.parchmentStrong,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      brass: brass ?? this.brass,
      brassMuted: brassMuted ?? this.brassMuted,
      rule: rule ?? this.rule,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      heroGradient: heroGradient ?? this.heroGradient,
      heroGradientSoft: heroGradientSoft ?? this.heroGradientSoft,
      sectionRadius: sectionRadius ?? this.sectionRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      showDecoration: showDecoration ?? this.showDecoration,
    );
  }

  @override
  ThemeExtension<CodexTheme> lerp(
    covariant ThemeExtension<CodexTheme>? other,
    double t,
  ) {
    if (other is! CodexTheme) {
      return this;
    }
    return CodexTheme(
      parchment: Color.lerp(parchment, other.parchment, t) ?? parchment,
      parchmentStrong: Color.lerp(parchmentStrong, other.parchmentStrong, t)!,
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t) ?? panelRaised,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t) ?? inkMuted,
      brass: Color.lerp(brass, other.brass, t) ?? brass,
      brassMuted: Color.lerp(brassMuted, other.brassMuted, t) ?? brassMuted,
      rule: Color.lerp(rule, other.rule, t) ?? rule,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      heroGradient: t < 0.5 ? heroGradient : other.heroGradient,
      heroGradientSoft: t < 0.5 ? heroGradientSoft : other.heroGradientSoft,
      sectionRadius: lerpDouble(sectionRadius, other.sectionRadius, t)!,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t)!,
      showDecoration: t < 0.5 ? showDecoration : other.showDecoration,
    );
  }
}

/// Baut das globale App-Theme fuer die gewaehlte UI-Variante.
ThemeData buildAppTheme({
  required UiVariante variante,
  required Brightness brightness,
  required bool centerAppBarTitle,
}) {
  return switch (variante) {
    UiVariante.codex => _buildCodexTheme(
      brightness: brightness,
      centerAppBarTitle: centerAppBarTitle,
    ),
    UiVariante.klassisch => _buildClassicTheme(
      brightness: brightness,
      centerAppBarTitle: centerAppBarTitle,
    ),
  };
}

ThemeData _buildClassicTheme({
  required Brightness brightness,
  required bool centerAppBarTitle,
}) {
  final isDark = brightness == Brightness.dark;
  const seedColor = Color(0xFF2A5A73);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final codex = isDark ? _darkClassicTheme() : _lightClassicTheme();
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: codex.parchment,
    fontFamily: 'Merriweather',
    extensions: <ThemeExtension<dynamic>>[codex],
  );

  final textTheme = base.textTheme.apply(
    fontFamily: 'Merriweather',
    bodyColor: codex.ink,
    displayColor: codex.ink,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(centerTitle: centerAppBarTitle),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData _buildCodexTheme({
  required Brightness brightness,
  required bool centerAppBarTitle,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A5A2C),
    brightness: brightness,
    primary: isDark ? const Color(0xFFD2A85E) : const Color(0xFF7B5C2F),
    secondary: isDark ? const Color(0xFF7A98A5) : const Color(0xFF36586B),
    tertiary: isDark ? const Color(0xFF8A584B) : const Color(0xFF835447),
    surface: isDark ? const Color(0xFF191612) : const Color(0xFFF6F0E3),
  );

  final codex = isDark ? _darkCodexTheme() : _lightCodexTheme();
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: codex.parchment,
    fontFamily: 'Merriweather',
    extensions: <ThemeExtension<dynamic>>[codex],
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w700,
      color: codex.ink,
      letterSpacing: 0.4,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w700,
      color: codex.ink,
      letterSpacing: 0.3,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w700,
      color: codex.ink,
      letterSpacing: 0.2,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w700,
      color: codex.ink,
      letterSpacing: 0.2,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w700,
      color: codex.ink,
      letterSpacing: 0.15,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontFamily: 'Cinzel',
      fontWeight: FontWeight.w600,
      color: codex.ink,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: codex.ink,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      color: codex.ink,
      height: 1.4,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      color: codex.ink,
      height: 1.4,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      color: codex.inkMuted,
      height: 1.35,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: codex.ink,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: codex.ink,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: codex.inkMuted,
      letterSpacing: 0.4,
    ),
  );

  final outlinedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(codex.panelRadius),
    borderSide: BorderSide(color: codex.rule),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: centerAppBarTitle,
      backgroundColor: codex.parchmentStrong.withValues(
        alpha: isDark ? 0.92 : 0.98,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: codex.ink,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: codex.ink),
      actionsIconTheme: IconThemeData(color: codex.ink),
    ),
    cardTheme: CardThemeData(
      color: codex.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(codex.sectionRadius),
        side: BorderSide(
          color: codex.rule.withValues(alpha: isDark ? 0.45 : 0.8),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: codex.rule, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: codex.panelRaised.withValues(alpha: isDark ? 0.55 : 0.9),
      labelStyle: textTheme.bodySmall?.copyWith(color: codex.inkMuted),
      helperStyle: textTheme.bodySmall,
      hintStyle: textTheme.bodySmall,
      border: outlinedBorder,
      enabledBorder: outlinedBorder,
      focusedBorder: outlinedBorder.copyWith(
        borderSide: BorderSide(color: codex.accent, width: 1.4),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: codex.panelRaised,
      selectedColor: codex.brass.withValues(alpha: isDark ? 0.25 : 0.18),
      side: BorderSide(color: codex.rule),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(codex.panelRadius),
      ),
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium,
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: codex.brass,
        foregroundColor: isDark ? const Color(0xFF13100C) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(codex.panelRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: codex.ink,
        side: BorderSide(color: codex.rule),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(codex.panelRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: codex.parchmentStrong,
      surfaceTintColor: Colors.transparent,
      indicatorColor: codex.brass.withValues(alpha: isDark ? 0.28 : 0.16),
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? codex.accent : codex.inkMuted);
      }),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: codex.rule,
      labelColor: codex.ink,
      unselectedLabelColor: codex.inkMuted,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: codex.brass, width: 3),
      ),
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.bodyMedium,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: codex.panelRaised,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.rule),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: codex.ink),
    ),
    listTileTheme: ListTileThemeData(
      dense: false,
      iconColor: codex.inkMuted,
      textColor: codex.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(codex.panelRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: codex.panelRaised,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: codex.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(codex.panelRadius),
        side: BorderSide(color: codex.rule),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

CodexTheme _lightCodexTheme() {
  return const CodexTheme(
    parchment: Color(0xFFF6F0E3),
    parchmentStrong: Color(0xFFEAE0CC),
    panel: Color(0xFFF9F4EA),
    panelRaised: Color(0xFFF2E7D4),
    ink: Color(0xFF241C15),
    inkMuted: Color(0xFF625546),
    brass: Color(0xFF8D6733),
    brassMuted: Color(0xFFB49A73),
    rule: Color(0xFFD4C3A8),
    accent: Color(0xFF345162),
    success: Color(0xFF39604A),
    warning: Color(0xFF8A5D1C),
    danger: Color(0xFF8D3E34),
    heroGradient: LinearGradient(
      colors: <Color>[Color(0xFF4E3922), Color(0xFF7B5C2F), Color(0xFF2F4D5B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradientSoft: LinearGradient(
      colors: <Color>[Color(0xFFE8D9BD), Color(0xFFF7F1E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    sectionRadius: 24,
    panelRadius: 16,
    showDecoration: true,
  );
}

CodexTheme _darkCodexTheme() {
  return const CodexTheme(
    parchment: Color(0xFF14110E),
    parchmentStrong: Color(0xFF1B1713),
    panel: Color(0xFF201A15),
    panelRaised: Color(0xFF2A221C),
    ink: Color(0xFFF1E4C9),
    inkMuted: Color(0xFFB8A994),
    brass: Color(0xFFD0A35A),
    brassMuted: Color(0xFF8B6B35),
    rule: Color(0xFF4A3D2D),
    accent: Color(0xFF86A7B6),
    success: Color(0xFF7FB592),
    warning: Color(0xFFDAAE63),
    danger: Color(0xFFD47F73),
    heroGradient: LinearGradient(
      colors: <Color>[Color(0xFF2A221B), Color(0xFF4B3925), Color(0xFF223844)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradientSoft: LinearGradient(
      colors: <Color>[Color(0xFF221B15), Color(0xFF161310)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    sectionRadius: 24,
    panelRadius: 16,
    showDecoration: true,
  );
}

CodexTheme _lightClassicTheme() {
  return const CodexTheme(
    parchment: Color(0xFFF2F5F7),
    parchmentStrong: Color(0xFFE8ECF0),
    panel: Color(0xFFFFFFFF),
    panelRaised: Color(0xFFF5F7FA),
    ink: Color(0xFF1D2830),
    inkMuted: Color(0xFF5A6670),
    brass: Color(0xFF2A5A73),
    brassMuted: Color(0xFF6A99B3),
    rule: Color(0xFFD0D7DE),
    accent: Color(0xFF2A5A73),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFE65100),
    danger: Color(0xFFC62828),
    heroGradient: LinearGradient(
      colors: <Color>[Color(0xFF2A5A73), Color(0xFF2A5A73)],
    ),
    heroGradientSoft: LinearGradient(
      colors: <Color>[Color(0xFFF2F5F7), Color(0xFFF2F5F7)],
    ),
    sectionRadius: 12,
    panelRadius: 8,
    showDecoration: false,
  );
}

CodexTheme _darkClassicTheme() {
  return const CodexTheme(
    parchment: Color(0xFF121212),
    parchmentStrong: Color(0xFF1E1E1E),
    panel: Color(0xFF1E1E1E),
    panelRaised: Color(0xFF2C2C2C),
    ink: Color(0xFFE0E0E0),
    inkMuted: Color(0xFF9E9E9E),
    brass: Color(0xFF5C9AB8),
    brassMuted: Color(0xFF3A6E88),
    rule: Color(0xFF424242),
    accent: Color(0xFF5C9AB8),
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFF9800),
    danger: Color(0xFFEF5350),
    heroGradient: LinearGradient(
      colors: <Color>[Color(0xFF1E1E1E), Color(0xFF1E1E1E)],
    ),
    heroGradientSoft: LinearGradient(
      colors: <Color>[Color(0xFF121212), Color(0xFF121212)],
    ),
    sectionRadius: 12,
    panelRadius: 8,
    showDecoration: false,
  );
}

/// Stellt kurze Zugriffshelfer fuer das aktive Codex-Theme bereit.
extension CodexBuildContextX on BuildContext {
  /// Liefert die aktiven Codex-Tokens.
  CodexTheme get codexTheme => CodexTheme.of(this);
}
