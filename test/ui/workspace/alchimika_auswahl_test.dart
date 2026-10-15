import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/vitalwirkung_anwenden_dialog.dart';

const _heiltrank = AlchimikumDef(
  id: 'alch_heiltrank',
  name: 'Heiltrank',
  beleg: AlchimikumBeleg(buch: 'Wege der Alchimie', seite: '56'),
  preisSilber: 100,
  qualitaeten: <AlchimikumQualitaet>[
    AlchimikumQualitaet(stufe: 'B', lepWurf: '1W6+2', lepProWunde: 7),
    AlchimikumQualitaet(stufe: 'C', lepWurf: '2W6+4', lepProWunde: 7),
  ],
);

const _wundpulver = AlchimikumDef(id: 'alch_wundpulver', name: 'Wundpulver');

const _katalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
  alchimika: <AlchimikumDef>[_heiltrank, _wundpulver],
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  Future<void> zeigeEditor(
    WidgetTester tester, {
    required List<HeroInventoryEntry> gespeichert,
    required HeroInventoryEntry eintrag,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rulesCatalogProvider.overrideWith((ref) async => _katalog)],
        child: MaterialApp(
          home: InventoryItemEditor(
            entry: eintrag,
            isNew: true,
            onSaved: (e) async => gespeichert.add(e),
            onCancelled: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Der Katalog lädt asynchron; der Editor liest ihn erst beim Antippen.
  Future<void> oeffneAuswahl(WidgetTester tester, ProviderContainer c) async {
    await c.read(rulesCatalogProvider.future);
    await tester.tap(_key('inventory-editor-katalog'));
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(InventoryItemEditor)),
  );

  group('Katalogauswahl im Inventareditor', () {
    testWidgets('füllt Name, Typ, Preis, Beschreibung und Vitalwirkung vor', (
      tester,
    ) async {
      final gespeichert = <HeroInventoryEntry>[];
      await zeigeEditor(
        tester,
        gespeichert: gespeichert,
        eintrag: const HeroInventoryEntry(),
      );
      await oeffneAuswahl(tester, container(tester));
      expect(_key('alchimika-auswahl'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('alchimika-uebernehmen')).onPressed,
        isNull,
      );

      await tester.tap(_key('alchimika-mittel-alch_heiltrank'));
      await tester.pumpAndSettle();
      // Qualität C ist vorgewählt.
      expect(find.textContaining('Wurf: LeP 2W6+4'), findsOneWidget);
      await tester.tap(_key('alchimika-stufe-B'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wurf: LeP 1W6+2'), findsOneWidget);
      await tester.tap(_key('alchimika-uebernehmen'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(_key('inventory-editor-name'))
            .controller!
            .text,
        'Heiltrank (Qualität B)',
      );
      expect(_key('inventory-editor-vital-katalog'), findsOneWidget);

      await tester.tap(_key('inventory-editor-save'));
      await tester.pumpAndSettle();
      final eintrag = gespeichert.single;
      expect(eintrag.itemType, InventoryItemType.verbrauchsgegenstand);
      expect(eintrag.wertSilber, 100);
      expect(eintrag.vitalwirkung!.lepWurf, '1W6+2');
      expect(eintrag.vitalwirkung!.lepProWunde, 7);
    });

    testWidgets('Mittel ohne Stufen zeigt keine Qualitätswahl', (tester) async {
      await zeigeEditor(
        tester,
        gespeichert: <HeroInventoryEntry>[],
        eintrag: const HeroInventoryEntry(),
      );
      await oeffneAuswahl(tester, container(tester));
      await tester.tap(_key('alchimika-mittel-alch_wundpulver'));
      await tester.pumpAndSettle();

      expect(_key('alchimika-stufe-C'), findsNothing);
      expect(
        tester.widget<FilledButton>(_key('alchimika-uebernehmen')).onPressed,
        isNotNull,
      );
    });

    testWidgets('Abbrechen lässt den Entwurf unverändert', (tester) async {
      await zeigeEditor(
        tester,
        gespeichert: <HeroInventoryEntry>[],
        eintrag: const HeroInventoryEntry(gegenstand: 'Eigener Trank'),
      );
      await oeffneAuswahl(tester, container(tester));
      await tester.tap(_key('alchimika-abbrechen'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(_key('inventory-editor-name'))
            .controller!
            .text,
        'Eigener Trank',
      );
    });
  });

  group('Anwenden mit Katalogvorschlag', () {
    testWidgets('zeigt Wurf und Wundenregel, bucht nur die Eingabe', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const trank = HeroInventoryEntry(
        gegenstand: 'Heiltrank (Qualität C)',
        itemType: InventoryItemType.verbrauchsgegenstand,
        instanzId: 'trank-1',
        menge: 1,
        anzahl: '1',
        vitalwirkung: Vitalwirkung(lepWurf: '2W6+4', lepProWunde: 7),
      );
      final zustand =
          const HeroState(
            currentLep: 10,
            currentAsp: 0,
            currentKap: 0,
            currentAu: 20,
          ).copyWith(
            wpiZustand: const WundZustand(wundenProZone: {WundZone.brust: 2}),
          );
      final repo = FakeRepository(
        heroes: [
          _held.copyWith(inventoryEntries: [trank]),
        ],
        states: {'demo': zustand},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            rulesCatalogProvider.overrideWith((ref) async => _katalog),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VitalwirkungPanel(
                  heroId: 'demo',
                  eintrag: trank,
                  onFertig: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Das Feld bleibt leer: gewürfelt wird am Tisch, nie von der App.
      expect(
        tester.widget<TextField>(_key('vitalwirkung-lep')).controller!.text,
        isEmpty,
      );
      expect(find.text('Wurf: 2W6+4'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('vitalwirkung-wunden-regel')).data,
        contains('Je 7 zurückgewonnene LeP schließt sich eine Wunde.'),
      );

      await tester.enterText(_key('vitalwirkung-lep'), '8');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(_key('vitalwirkung-wunden-regel')).data,
        contains('bei 8 LeP bis zu 1'),
      );
      // Die Wunden bestimmt weiter der Nutzer.
      expect(tester.widget<Text>(_key('vitalwirkung-wunden-brust')).data, '0');

      await tester.tap(_key('vitalwirkung-wunden-plus-brust'));
      await tester.pumpAndSettle();
      await tester.tap(_key('vitalwirkung-uebernehmen'));
      await tester.pumpAndSettle();

      final z = (await repo.loadHeroState('demo'))!;
      expect(z.currentLep, 18);
      expect(z.wpiZustand.wundenInZone(WundZone.brust), 1);
    });
  });
}
