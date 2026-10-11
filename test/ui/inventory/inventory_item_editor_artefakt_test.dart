import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';

// Matrixgeber im Inventareditor: Artefaktdaten, eingesprochene Zauber mit den
// Werten ihres Sprechers und die Katalogvorbelegung.

const _katalog = RulesCatalog(
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
      availability: 'Mag6',
      aspCost: '8 AsP',
      range: 'Selbst',
      duration: '1 Stunde',
    ),
    SpellDef(
      id: 'spell_ignifaxius',
      name: 'Ignifaxius',
      tradition: 'Mag',
      steigerung: 'D',
      attributes: ['KL', 'IN', 'FF'],
      availability: 'Mag7',
      aspCost: 'ZfP*',
    ),
  ],
);

Future<List<HeroInventoryEntry>> _zeige(
  WidgetTester tester,
  HeroInventoryEntry eintrag,
) async {
  final gespeichert = <HeroInventoryEntry>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rulesCatalogProvider.overrideWith((ref) async => _katalog)],
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
    // Frei änderbar: die Vorbelegung ist nur ein Vorschlag.
    await tester.enterText(_zauber('repraesentation'), 'Elf');
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
}
