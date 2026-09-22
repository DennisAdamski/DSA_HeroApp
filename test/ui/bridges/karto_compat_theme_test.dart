import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('maps $brightness Kartograph roles onto the compatibility theme', () {
      final base =
          buildKartoTheme(
            brightness: brightness,
            centerAppBarTitle: false,
          ).copyWith(
            extensions: <ThemeExtension<dynamic>>[
              brightness == Brightness.dark ? kartoDunkel : kartoHell,
              const _MarkerTheme('retained'),
            ],
          );

      final result = buildKartoCompatTheme(base);
      final karto = result.extension<KartoTheme>()!;
      final codex = result.extension<CodexTheme>()!;

      expect(result.brightness, brightness);
      expect(result.extension<_MarkerTheme>()?.value, 'retained');
      expect(karto, same(base.extension<KartoTheme>()));
      expect(codex.parchment, karto.blatt);
      expect(codex.parchmentStrong, karto.senke);
      expect(codex.panel, karto.feld);
      expect(codex.panelRaised, karto.senke);
      expect(codex.ink, karto.schrift);
      expect(codex.inkMuted, karto.schriftLeise);
      expect(codex.brass, karto.meer);
      expect(codex.accent, karto.meer);
      expect(codex.brassMuted, karto.hoehenlinie);
      expect(codex.rule, karto.hoehenlinie);
      expect(codex.success, karto.moos);
      expect(codex.warning, karto.wachs);
      expect(codex.danger, karto.siegel);
      expect(codex.sectionRadius, kKartoRadius);
      expect(codex.panelRadius, kKartoRadius);
      expect(codex.showDecoration, isFalse);
      expect((codex.heroGradient as LinearGradient).colors, <Color>[
        karto.blatt,
        karto.blatt,
      ]);
      expect((codex.heroGradientSoft as LinearGradient).colors, <Color>[
        karto.senke,
        karto.senke,
      ]);
    });
  }

  test('keeps text inheritance stable during the compatibility transition', () {
    final base = buildKartoTheme(
      brightness: Brightness.light,
      centerAppBarTitle: false,
    );

    final result = buildKartoCompatTheme(base);

    expect(result.textTheme, base.textTheme);
    expect(
      result.textTheme.bodyMedium?.inherit,
      base.textTheme.bodyMedium?.inherit,
    );
    expect(
      result.textTheme.titleLarge?.inherit,
      base.textTheme.titleLarge?.inherit,
    );
    expect(() => ThemeData.lerp(base, result, 0.5), returnsNormally);
  });
}

class _MarkerTheme extends ThemeExtension<_MarkerTheme> {
  const _MarkerTheme(this.value);

  final String value;

  @override
  _MarkerTheme copyWith({String? value}) => _MarkerTheme(value ?? this.value);

  @override
  _MarkerTheme lerp(covariant _MarkerTheme? other, double t) {
    return t < 0.5 || other == null ? this : other;
  }
}
