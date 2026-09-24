import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

void main() {
  // Regression: beim Umschalten der Oberflaeche animiert `MaterialApp`
  // zwischen beiden Themes. `TextStyle.lerp` wirft, sobald zwei Stile
  // verschiedene `inherit`-Werte tragen. Materials eigene Stile haben
  // `inherit: false`; ein von Grund auf gebauter `TextStyle` hat `true`.
  //
  // Der Fehler faellt nur beim Uebergang auf, nie beim Bau eines einzelnen
  // Themes - deshalb hat ihn keiner der uebrigen Tests gesehen.
  group('Themenwechsel', () {
    for (final helligkeit in Brightness.values) {
      test('Stile beider Themes lassen sich ineinander ueberfuehren '
          '(${helligkeit.name})', () {
        final codex = buildAppTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        );
        final karto = buildKartoTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        );

        // Die Rohprobe: genau das tut Flutter waehrend der Animation.
        for (final t in <double>[0, 0.2, 0.5, 0.8, 1]) {
          expect(
            () => ThemeData.lerp(codex, karto, t),
            returnsNormally,
            reason: 'Codex nach Kartograph bei t=$t',
          );
          expect(
            () => ThemeData.lerp(karto, codex, t),
            returnsNormally,
            reason: 'Kartograph nach Codex bei t=$t',
          );
        }
      });

      test('alle Schriftrollen tragen dasselbe inherit wie Material '
          '(${helligkeit.name})', () {
        final karto = buildKartoTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        );
        final material = ThemeData(brightness: helligkeit).textTheme;

        final rollen = <String, TextStyle?>{
          'displayLarge': karto.textTheme.displayLarge,
          'displayMedium': karto.textTheme.displayMedium,
          'displaySmall': karto.textTheme.displaySmall,
          'headlineLarge': karto.textTheme.headlineLarge,
          'headlineMedium': karto.textTheme.headlineMedium,
          'headlineSmall': karto.textTheme.headlineSmall,
          'titleLarge': karto.textTheme.titleLarge,
          'titleMedium': karto.textTheme.titleMedium,
          'titleSmall': karto.textTheme.titleSmall,
          'bodyLarge': karto.textTheme.bodyLarge,
          'bodyMedium': karto.textTheme.bodyMedium,
          'bodySmall': karto.textTheme.bodySmall,
          'labelLarge': karto.textTheme.labelLarge,
          'labelMedium': karto.textTheme.labelMedium,
          'labelSmall': karto.textTheme.labelSmall,
        };

        for (final rolle in rollen.entries) {
          expect(rolle.value, isNotNull, reason: rolle.key);
          expect(
            rolle.value!.inherit,
            material.bodyMedium!.inherit,
            reason:
                '${rolle.key} weicht ab. Ein von Grund auf gebauter '
                'TextStyle hat inherit: true, Materials Stile haben false. '
                'Die Rollen muessen deshalb per copyWith auf der Material-'
                'Grundlage entstehen.',
          );
        }
      });
    }
  });

  testWidgets('ein Themenwechsel laeuft ohne Ausnahme durch', (tester) async {
    Widget rahmen(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Probe')),
        body: Column(
          children: [
            const Text('Fliesstext'),
            FilledButton(onPressed: () {}, child: const Text('Übernehmen')),
            OutlinedButton(onPressed: () {}, child: const Text('Abbrechen')),
            const Chip(label: Text('Marke')),
            const TextField(),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      rahmen(
        buildAppTheme(brightness: Brightness.light, centerAppBarTitle: false),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      rahmen(
        buildKartoTheme(brightness: Brightness.light, centerAppBarTitle: false),
      ),
    );
    // Durch die Theme-Animation laufen. Genau hier warf es vorher.
    for (final schritt in <int>[1, 50, 100, 150, 200, 300]) {
      await tester.pump(Duration(milliseconds: schritt));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Ausnahme nach $schritt ms der Themenanimation',
      );
    }
  });
}
