import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_herkunft_section.dart';

typedef _Aufbau = ({
  List<List<HeroHerkunftsModifikator>> aenderungen,
  List<HerkunftsAbgleichWahl> abgleiche,
});

// Baut die Section und sammelt ihre Callbacks.
Future<_Aufbau> _zeige(
  WidgetTester tester, {
  required HeroBackground background,
  HeroHerkunft herkunft = HeroHerkunft.rasse,
  bool bearbeitbar = true,
  double breite = 800,
  double textFaktor = 1,
}) async {
  final aufbau = (
    aenderungen: <List<HeroHerkunftsModifikator>>[],
    abgleiche: <HerkunftsAbgleichWahl>[],
  );
  tester.view.physicalSize = Size(breite, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textFaktor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(breite, 1200),
          textScaler: TextScaler.linear(textFaktor),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: HeroHerkunftSection(
              herkunft: herkunft,
              background: background,
              bearbeitbar: bearbeitbar,
              onEintraegeChanged: aufbau.aenderungen.add,
              onAbgleich: aufbau.abgleiche.add,
            ),
          ),
        ),
      ),
    ),
  );
  return aufbau;
}

HeroBackground get _basis =>
    herkunftZumSpeichern(const HeroBackground(rasseModText: 'MU+1, Flink'));

void main() {
  testWidgets('Hinzufügen abbrechen verändert keine Einträge', (tester) async {
    final aufbau = await _zeige(tester, background: _basis);
    await tester.tap(find.text('+ Herkunftsmodifikator'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('herkunft-dialog-modus')), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(aufbau.aenderungen, isEmpty);
    expect(aufbau.abgleiche, isEmpty);
    expect(find.byKey(const ValueKey('herkunft-dialog-modus')), findsNothing);
  });

  testWidgets('zeigt die Einträge der Gruppe und den Titel', (tester) async {
    await _zeige(tester, background: _basis);
    expect(find.text('Rasse Modifikatoren'), findsOneWidget);
    expect(find.text('MU+1'), findsOneWidget);
    expect(find.text('Flink'), findsOneWidget);
  });

  testWidgets('Eigenschaft mit Ziel und Betrag hinzufügen', (tester) async {
    final aufbau = await _zeige(tester, background: _basis);
    await tester.tap(find.text('+ Herkunftsmodifikator'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('herkunft-dialog-ziel-eigenschaft')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('KK').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('herkunft-dialog-betrag')),
      '-2',
    );
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();

    expect(aufbau.aenderungen, hasLength(1));
    final liste = aufbau.aenderungen.single;
    expect(liste, hasLength(3));
    expect(liste.first, _basis.herkunftsModifikatoren!.rasse.first);
    final neu = liste.last;
    expect(neu.art, HeroHerkunftsModifikatorArt.eigenschaft);
    expect((neu.ziel, neu.betrag, neu.text), ('KK', -2, 'KK-2'));
    expect(neu.id, isNotEmpty);
  });

  testWidgets('Ziel ohne Auswahl zeigt einen Fehler und ändert nichts', (
    tester,
  ) async {
    final aufbau = await _zeige(tester, background: _basis);
    await tester.tap(find.text('+ Herkunftsmodifikator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('herkunft-dialog-fehler')),
      findsOneWidget,
    );
    expect(aufbau.aenderungen, isEmpty);
  });

  testWidgets('freier Text: mehrere Fragmente werden abgewiesen', (
    tester,
  ) async {
    final aufbau = await _zeige(tester, background: _basis);
    await tester.tap(find.text('+ Herkunftsmodifikator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freier Text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('herkunft-dialog-text')),
      'MU+1, KL+1',
    );
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('herkunft-dialog-fehler')),
      findsOneWidget,
    );
    expect(aufbau.aenderungen, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('herkunft-dialog-text')),
      'AE-2',
    );
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();
    final neu = aufbau.aenderungen.single.last;
    // Ein getippter Direktmodifikator wird strukturiert.
    expect(
      (neu.art, neu.ziel, neu.betrag),
      (HeroHerkunftsModifikatorArt.basiswert, 'ASP', -2),
    );
  });

  testWidgets('Ändern erhält die ID des Eintrags', (tester) async {
    final aufbau = await _zeige(tester, background: _basis);
    final vorher = _basis.herkunftsModifikatoren!.rasse.first;
    await tester.tap(find.byKey(const ValueKey('herkunft-chip-rasse-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('herkunft-dialog-betrag')),
      '4',
    );
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();
    final ersatz = aufbau.aenderungen.single.first;
    expect(ersatz.id, vorher.id);
    expect((ersatz.ziel, ersatz.betrag, ersatz.text), ('MU', 4, 'MU+4'));
  });

  testWidgets('Entfernen meldet die Liste ohne den Eintrag', (tester) async {
    final aufbau = await _zeige(tester, background: _basis);
    final chip = find.byKey(const ValueKey('herkunft-chip-rasse-1'));
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(aufbau.aenderungen.single.map((e) => e.text), ['MU+1']);
  });

  testWidgets('ohne Bearbeitungsmodus gibt es keine Aktionen', (tester) async {
    await _zeige(tester, background: _basis, bearbeitbar: false);
    expect(find.text('+ Herkunftsmodifikator'), findsNothing);
    expect(find.byKey(const ValueKey('herkunft-chip-rasse-0')), findsNothing);
    expect(find.text('MU+1'), findsOneWidget);
  });

  group('Abweichung durch eine ältere App', () {
    HeroBackground fremd() => _basis.copyWith(rasseModText: 'MU+3, Flink');

    testWidgets('beide Buttons melden die Wahl, Hinzufügen ist gesperrt', (
      tester,
    ) async {
      final aufbau = await _zeige(tester, background: fremd());
      expect(
        find.byKey(const ValueKey('herkunft-abweichung-rasse')),
        findsOneWidget,
      );
      final hinzufuegen = tester.widget<TextButton>(
        find.byKey(const ValueKey('herkunft-add-rasse')),
      );
      expect(hinzufuegen.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('herkunft-text-uebernehmen-rasse')),
      );
      await tester.tap(
        find.byKey(const ValueKey('herkunft-liste-behalten-rasse')),
      );
      expect(aufbau.abgleiche, [
        HerkunftsAbgleichWahl.textUebernehmen,
        HerkunftsAbgleichWahl.listeBehalten,
      ]);
      expect(aufbau.aenderungen, isEmpty);
    });

    testWidgets('ohne Bearbeitungsmodus nur der Hinweis', (tester) async {
      await _zeige(tester, background: fremd(), bearbeitbar: false);
      expect(
        find.byKey(const ValueKey('herkunft-text-uebernehmen-rasse')),
        findsNothing,
      );
      expect(
        find.text('Zum Entscheiden in den Bearbeitungsmodus wechseln.'),
        findsOneWidget,
      );
    });

    testWidgets('eine andere Gruppe bleibt bearbeitbar', (tester) async {
      await _zeige(tester, background: fremd(), herkunft: HeroHerkunft.kultur);
      expect(
        find.byKey(const ValueKey('herkunft-abweichung-kultur')),
        findsNothing,
      );
      final hinzufuegen = tester.widget<TextButton>(
        find.byKey(const ValueKey('herkunft-add-kultur')),
      );
      expect(hinzufuegen.onPressed, isNotNull);
    });
  });

  group('gesperrte Daten', () {
    testWidgets('unbekannte Containerversion: Grund statt Felder', (
      tester,
    ) async {
      final background = HeroBackground(
        rasseModText: 'LEP+10',
        herkunftsModifikatoren: HeroHerkunftsModifikatoren.fromJson(
          <String, Object?>{'formatVersion': 900},
        ),
      );
      final aufbau = await _zeige(tester, background: background);
      expect(
        find.byKey(const ValueKey('herkunft-gesperrt-rasse')),
        findsOneWidget,
      );
      expect(find.textContaining('neueren App-Version'), findsOneWidget);
      expect(find.text('LEP+10'), findsOneWidget);
      final hinzufuegen = tester.widget<TextButton>(
        find.byKey(const ValueKey('herkunft-add-rasse')),
      );
      expect(hinzufuegen.onPressed, isNull);
      expect(find.byType(InputChip), findsNothing);
      expect(aufbau.aenderungen, isEmpty);
    });

    testWidgets('nicht lesbarer Eintrag: Chip ohne Aktionen, Gruppe gesperrt', (
      tester,
    ) async {
      final background = HeroBackground(
        herkunftsModifikatoren: HeroHerkunftsModifikatoren.fromJson(
          <String, Object?>{
            'formatVersion': 1,
            'rasse': <Object?>[
              <String, Object?>{'id': 'a', 'art': 'frei', 'text': 'Gut'},
              'kaputt',
            ],
            'kultur': <Object?>[],
            'profession': <Object?>[],
          },
        ),
        rasseModText: 'Gut',
      );
      await _zeige(tester, background: background);
      expect(find.text('Nicht lesbarer Eintrag'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      expect(
        find.byKey(const ValueKey('herkunft-gesperrt-rasse')),
        findsOneWidget,
      );
    });
  });

  group('Layout', () {
    for (final (breite, faktor) in <(double, double)>[
      (360.0, 1.0),
      (360.0, 2.0),
      (800.0, 2.0),
    ]) {
      testWidgets('${breite.toInt()} px mit Textfaktor $faktor ohne Overflow', (
        tester,
      ) async {
        await _zeige(
          tester,
          background: _basis,
          breite: breite,
          textFaktor: faktor,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('+ Herkunftsmodifikator'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('herkunft-dialog-uebernehmen')),
          findsOneWidget,
        );
      });
    }
  });
}
