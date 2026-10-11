import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';

// Matrixgeber im Inventareditor: Artefaktdaten, eingesprochene Zauber mit den
// Werten ihres Sprechers und die Katalogvorbelegung.

const _passwort = 'geheim';

final _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  weapons: [],
  spells: [
    SpellDef(
      id: 'spell_armatrutz',
      name: 'Armatrutz',
      tradition: 'Mag',
      steigerung: 'D',
      attributes: ['IN', 'GE', 'KO'],
      availability: 'Mag6, Elf5',
      aspCost: '8 AsP',
      range: 'Selbst',
      duration: '1 Stunde',
      variants: ['Dauerhaft', 'Für die Gruppe'],
    ),
    SpellDef(
      id: 'spell_ignifaxius',
      name: 'Ignifaxius',
      tradition: 'Mag',
      steigerung: 'D',
      attributes: ['KL', 'IN', 'FF'],
      availability: 'Mag7',
      aspCost: 'ZfP*',
      rawVariantsEncrypted: 'enc:3:gesperrt',
    ),
    SpellDef(
      id: 'spell_balsam',
      name: 'Balsam',
      tradition: 'Mag',
      steigerung: 'C',
      attributes: ['KL', 'IN', 'FF'],
      availability: 'Mag7',
      aspCost: '5 AsP',
      rawVariantsEncrypted: encryptCatalogList([
        'Schnell',
        'Kraftvoll',
      ], _passwort),
    ),
  ],
);

Future<List<HeroInventoryEntry>> _zeige(
  WidgetTester tester,
  HeroInventoryEntry eintrag, {
  String? passwort,
}) async {
  final gespeichert = <HeroInventoryEntry>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rulesCatalogProvider.overrideWith((ref) async => _katalog),
        if (passwort != null)
          catalogContentPasswordProvider.overrideWithValue(passwort),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InventoryItemEditor(
            entry: eintrag,
            showAppBar: false,
            onSaved: (neu) async => gespeichert.add(neu),
            onCancelled: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gespeichert;
}

Future<void> _speichere(WidgetTester tester) async {
  final knopf = find.widgetWithText(FilledButton, 'Speichern');
  await tester.ensureVisible(knopf);
  await tester.tap(knopf);
  await tester.pumpAndSettle();
}

Finder _artefakt(String name) =>
    find.byKey(ValueKey<String>('inventory-editor-artefakt-$name'));
Finder _zauber(String name) =>
    find.byKey(ValueKey<String>('artefakt-zauber-$name'));

Future<void> _tippe(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ein normaler Gegenstand bekommt keine Artefaktdaten', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(gegenstand: 'Seil'),
    );

    await _speichere(tester);

    expect(gespeichert.single.artefaktDaten, isNull);
  });

  testWidgets('Matrixgeber anlegen: Zauber frei erfassen und speichern', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(gegenstand: 'Armschiene'),
    );

    // Der Matrixgeber hängt unter „Magisch“: erst danach erscheint er.
    expect(
      find.byKey(const ValueKey('inventory-editor-artefakt')),
      findsNothing,
    );
    await _tippe(
      tester,
      find.byKey(const ValueKey('inventory-editor-magisch')),
    );
    await _tippe(
      tester,
      find.byKey(const ValueKey('inventory-editor-artefakt')),
    );
    expect(_artefakt('add'), findsOneWidget);
    await _tippe(tester, _artefakt('add'));
    await tester.enterText(_zauber('name'), 'Gardianum');
    await tester.enterText(_zauber('repraesentation'), 'Mag');
    await tester.enterText(_zauber('zfw'), '12');
    await tester.enterText(_zauber('zfp'), '7');
    await tester.enterText(_zauber('kosten'), '9');
    await tester.enterText(_zauber('reichweite'), 'Selbst');
    await tester.pumpAndSettle();
    await _tippe(tester, _zauber('uebernehmen'));
    await tester.enterText(_artefakt('ersteller'), 'Meister Okharim');
    await _speichere(tester);

    final eintrag = gespeichert.single;
    expect(eintrag.isMagisch, isTrue, reason: 'ein Artefakt ist magisch');
    final daten = eintrag.artefaktDaten!;
    expect(daten.ersteller, 'Meister Okharim');
    expect(daten.stabilitaet, MatrixStabilitaet.stabil);
    final z = daten.zauber.single;
    expect(z.name, 'Gardianum');
    expect(z.spellId, isNull, reason: 'freier Zauber');
    expect(z.repraesentation, 'Mag');
    expect(z.zfw, 12);
    expect(z.zfpStern, 7);
    expect(z.kostenAsp, 9);
    expect(z.reichweite, 'Selbst');
  });

  testWidgets('permanente AsP: je Zauber erfasst, Summe als Hilfetext', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    expect(find.text('Summe der Zauber: 5'), findsNothing);
    for (final (name, pAsP) in [('Gardianum', '3'), ('Armatrutz', '2')]) {
      await _tippe(tester, _artefakt('add'));
      await tester.enterText(_zauber('name'), name);
      await tester.enterText(_zauber('pasp'), pAsP);
      await tester.pumpAndSettle();
      await _tippe(tester, _zauber('uebernehmen'));
    }

    expect(find.text('Summe der Zauber: 5'), findsOneWidget);
    expect(find.textContaining('3 pAsP'), findsOneWidget);
    await _speichere(tester);

    final daten = gespeichert.single.artefaktDaten!;
    expect(daten.zauber.map((z) => z.pAsP), [3, 2]);
    expect(daten.pAsP, isNull, reason: 'die Summe wird nicht gespeichert');
  });

  testWidgets('die Katalogauswahl belegt Kosten, Reichweite und Dauer vor', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    await _tippe(tester, _artefakt('add'));
    await tester.enterText(_zauber('suche'), 'armat');
    await tester.pumpAndSettle();
    await _tippe(tester, _zauber('treffer-spell_armatrutz'));
    // Zwei Verbreitungen: keine Vorgabe, der Nutzer wählt aus dem Zauber.
    await _tippe(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'artefakt-zauber-repraesentation-wahl',
            ),
      ),
    );
    await _tippe(tester, find.text('Elf').last);
    await _tippe(tester, _zauber('uebernehmen'));
    await _speichere(tester);

    final z = gespeichert.single.artefaktDaten!.zauber.single;
    expect(z.spellId, 'spell_armatrutz');
    expect(z.name, 'Armatrutz');
    expect(z.kostenAsp, 8);
    expect(z.reichweite, 'Selbst');
    expect(z.wirkungsdauer, '1 Stunde');
    expect(z.repraesentation, 'Elf');
  });

  testWidgets('uneindeutige Katalogkosten bleiben leer', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Stab',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    await _tippe(tester, _artefakt('add'));
    await tester.enterText(_zauber('suche'), 'ignifax');
    await tester.pumpAndSettle();
    await _tippe(tester, _zauber('treffer-spell_ignifaxius'));
    await _tippe(tester, _zauber('uebernehmen'));
    await _speichere(tester);

    expect(gespeichert.single.artefaktDaten!.zauber.single.kostenAsp, isNull);
  });

  testWidgets('Zauber lassen sich ändern und entfernen', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(
          zauber: <ArtefaktZauber>[
            ArtefaktZauber(name: 'Gardianum', kostenAsp: 9),
            ArtefaktZauber(name: 'Armatrutz', kostenAsp: 6),
          ],
        ),
      ),
    );

    await _tippe(tester, _artefakt('zauber-0'));
    await tester.enterText(_zauber('kosten'), '10');
    await _tippe(tester, _zauber('uebernehmen'));
    await tester.tap(find.byTooltip('Zauber entfernen').last);
    await tester.pumpAndSettle();
    await _speichere(tester);

    final zauber = gespeichert.single.artefaktDaten!.zauber;
    expect(zauber.map((z) => z.name), ['Gardianum']);
    expect(zauber.single.kostenAsp, 10);
  });

  testWidgets('Stabilität und Regelfassung sind einstellbar', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Amulett',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    await _tippe(tester, _artefakt('stabilitaet'));
    await _tippe(tester, find.text('unempfindlich').last);
    await _tippe(tester, _artefakt('regelfassung'));
    await _tippe(tester, find.text('Stäbe, Ringe, Dschinnenlampen 2011').last);
    await _speichere(tester);

    final daten = gespeichert.single.artefaktDaten!;
    expect(daten.stabilitaet, MatrixStabilitaet.unempfindlich);
    expect(daten.regelfassung, MatrixRegelfassung.staebeRinge2011);
  });

  testWidgets('Matrixgeber ausschalten entfernt die Artefaktdaten', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    await _tippe(
      tester,
      find.byKey(const ValueKey('inventory-editor-artefakt')),
    );
    await _speichere(tester);

    expect(gespeichert.single.artefaktDaten, isNull);
    expect(gespeichert.single.toJson().containsKey('artefaktDaten'), isFalse);
  });

  group('Repräsentation und Variante eines Katalogzaubers', () {
    const leer = HeroInventoryEntry(
      gegenstand: 'Armschiene',
      isMagisch: true,
      artefaktDaten: ArtefaktDaten(),
    );

    Future<void> waehleZauber(
      WidgetTester tester,
      String suche,
      String id,
    ) async {
      await _tippe(tester, _artefakt('add'));
      await tester.enterText(_zauber('suche'), suche);
      await tester.pumpAndSettle();
      await _tippe(tester, _zauber('treffer-$id'));
    }

    Finder dropdown(String praefix) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(praefix),
    );

    testWidgets('eine einzige Verbreitung ist die Vorgabe', (tester) async {
      final gespeichert = await _zeige(tester, leer, passwort: _passwort);

      await waehleZauber(tester, 'balsam', 'spell_balsam');
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(
        gespeichert.single.artefaktDaten!.zauber.single.repraesentation,
        'Mag',
      );
    });

    testWidgets('Varianten: Standard ist keine, die Auswahl wird gespeichert', (
      tester,
    ) async {
      final gespeichert = await _zeige(tester, leer);

      await waehleZauber(tester, 'armat', 'spell_armatrutz');
      expect(find.text('Keine Variante'), findsOneWidget);
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);
      expect(gespeichert.last.artefaktDaten!.zauber.single.variante, '');
      expect(
        gespeichert.last.artefaktDaten!.zauber.single.toJson().containsKey(
          'variante',
        ),
        isFalse,
      );

      // Erneut öffnen und eine Variante wählen.
      await _tippe(tester, _artefakt('zauber-0'));
      await _tippe(tester, dropdown('artefakt-zauber-variante-wahl'));
      await _tippe(tester, find.text('Für die Gruppe').last);
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(
        gespeichert.last.artefaktDaten!.zauber.single.variante,
        'Für die Gruppe',
      );
      expect(find.textContaining('Variante: Für die Gruppe'), findsOneWidget);
    });

    testWidgets('eine Variante lässt sich wieder auf „Keine“ zurücksetzen', (
      tester,
    ) async {
      final gespeichert = await _zeige(
        tester,
        leer.copyWith(
          artefaktDaten: const ArtefaktDaten(
            zauber: <ArtefaktZauber>[
              ArtefaktZauber(
                spellId: 'spell_armatrutz',
                name: 'Armatrutz',
                repraesentation: 'Mag',
                variante: 'Dauerhaft',
              ),
            ],
          ),
        ),
      );

      await _tippe(tester, _artefakt('zauber-0'));
      await _tippe(tester, dropdown('artefakt-zauber-variante-wahl'));
      await _tippe(tester, find.text('Keine Variante').last);
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(gespeichert.single.artefaktDaten!.zauber.single.variante, '');
    });

    testWidgets('gesperrte Varianten: Hinweis und freies Feld', (tester) async {
      final gespeichert = await _zeige(tester, leer);

      await waehleZauber(tester, 'ignifax', 'spell_ignifaxius');
      expect(_zauber('varianten-gesperrt'), findsOneWidget);
      await tester.enterText(_zauber('variante-frei'), 'Von Hand');
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(
        gespeichert.single.artefaktDaten!.zauber.single.variante,
        'Von Hand',
      );
    });

    testWidgets('mit Passwort werden verschlüsselte Varianten auswählbar', (
      tester,
    ) async {
      final gespeichert = await _zeige(tester, leer, passwort: _passwort);

      await waehleZauber(tester, 'balsam', 'spell_balsam');
      expect(_zauber('varianten-gesperrt'), findsNothing);
      await _tippe(tester, dropdown('artefakt-zauber-variante-wahl'));
      await _tippe(tester, find.text('Kraftvoll').last);
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(
        gespeichert.single.artefaktDaten!.zauber.single.variante,
        'Kraftvoll',
      );
    });

    testWidgets('eine andere Repräsentation lässt sich frei eintragen', (
      tester,
    ) async {
      final gespeichert = await _zeige(tester, leer);

      await waehleZauber(tester, 'armat', 'spell_armatrutz');
      await _tippe(tester, dropdown('artefakt-zauber-repraesentation-wahl'));
      await _tippe(tester, find.text('Andere …').last);
      await tester.enterText(_zauber('repraesentation'), 'Ach');
      await _tippe(tester, _zauber('uebernehmen'));
      await _speichere(tester);

      expect(
        gespeichert.single.artefaktDaten!.zauber.single.repraesentation,
        'Ach',
      );
    });

    testWidgets('ein freier Zauber hat ein Textfeld für die Repräsentation', (
      tester,
    ) async {
      await _zeige(tester, leer);

      await _tippe(tester, _artefakt('add'));

      expect(_zauber('repraesentation'), findsOneWidget);
      expect(dropdown('artefakt-zauber-repraesentation-wahl'), findsNothing);
    });
  });

  testWidgets('ein Matrixgeber lässt sich als ausgerüstet markieren', (
    tester,
  ) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    // Typ „Sonstiges“: der Schalter erscheint wegen des Matrixgebers.
    await _tippe(
      tester,
      find.byKey(const ValueKey('inventory-editor-ausgeruestet')),
    );
    await _speichere(tester);

    expect(gespeichert.single.istAusgeruestet, isTrue);
  });

  testWidgets(
    'ein normaler Gegenstand vom Typ Sonstiges hat den Schalter nicht',
    (tester) async {
      await _zeige(tester, const HeroInventoryEntry(gegenstand: 'Seil'));

      expect(
        find.byKey(const ValueKey('inventory-editor-ausgeruestet')),
        findsNothing,
      );
    },
  );

  testWidgets('Magisch ausschalten entfernt den Matrixgeber', (tester) async {
    final gespeichert = await _zeige(
      tester,
      const HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(),
      ),
    );

    await _tippe(
      tester,
      find.byKey(const ValueKey('inventory-editor-magisch')),
    );
    expect(
      find.byKey(const ValueKey('inventory-editor-artefakt')),
      findsNothing,
    );
    await _speichere(tester);

    expect(gespeichert.single.isMagisch, isFalse);
    expect(gespeichert.single.artefaktDaten, isNull);
  });
}
