import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';

/// Persistenz und Vorrang der Systemeinstellung für optionale Effekte.
void main() {
  testWidgets('App-Hülle reicht abgeschaltete Effekte an Dialoge weiter', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const AppSettings(animationen: false, dekorativeEffekte: false),
            ),
          ),
        ],
        child: DsaAppShell(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(
                    '${kartoDauer(context, Bewegung.kurz).inMilliseconds} / '
                    '${kartoDekorationAktiv(context)}',
                  ),
                ),
              ),
              child: const Text('Dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('0 / false'), findsOneWidget);
  });

  test(
    'alte Einstellungen aktivieren Effekte und bewahren getrennte Auswahl',
    () {
      final alt = AppSettings.fromJson({});
      expect(alt.animationen, isTrue);
      expect(alt.dekorativeEffekte, isTrue);
      final aus = alt.copyWith(animationen: false, dekorativeEffekte: false);
      final geladen = AppSettings.fromJson(aus.toJson());
      expect(geladen.animationen, isFalse);
      expect(geladen.dekorativeEffekte, isFalse);
      expect(geladen.copyWith(dunkelModus: true).animationen, isFalse);
      expect(geladen.copyWith(animationen: true).dekorativeEffekte, isFalse);
    },
  );

  for (final animationen in [true, false]) {
    for (final dekoration in [true, false]) {
      for (final systemAus in [true, false]) {
        testWidgets(
          'Animation $animationen, Dekoration $dekoration, System $systemAus',
          (tester) async {
            late Duration dauer;
            late bool dekorativ;
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(disableAnimations: systemAus),
                child: KartoEffektEinstellungen(
                  animationen: animationen,
                  dekorativeEffekte: dekoration,
                  child: Builder(
                    builder: (context) {
                      dauer = kartoDauer(context, Bewegung.mittel);
                      dekorativ = kartoDekorationAktiv(context);
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            );
            expect(
              dauer,
              animationen && !systemAus ? Bewegung.mittel : Duration.zero,
            );
            expect(dekorativ, animationen && dekoration && !systemAus);
          },
        );
      }
    }
  }
}
