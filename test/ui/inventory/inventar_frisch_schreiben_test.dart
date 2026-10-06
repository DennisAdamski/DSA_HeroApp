import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Inventar (ARCH-05): Editor, Löschen und Geldstand arbeiten auf dem
// gespeicherten Helden. Ein anderer Schreibweg speichert nach dem Aufbau
// (`BogenTestRepository.fremdeAenderung`); seine Felder bleiben stehen,
// Münzschritte zählen vom gespeicherten Betrag, ein Editorergebnis trifft
// den geöffneten Gegenstand oder wird abgewiesen.

const _seil = HeroInventoryEntry(gegenstand: 'Seil', anzahl: '1');
const _fackel = HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '3');

HeroSheet _held({String dukaten = '5'}) => HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
  level: 1,
  dukaten: dukaten,
  attributes: const Attributes(
    mu: 12,
    kl: 11,
    inn: 10,
    ch: 10,
    ff: 11,
    ge: 12,
    ko: 11,
    kk: 12,
  ),
  inventoryEntries: const [_seil],
);

MainWeaponSlot _bogen(String id, int pfeile) => MainWeaponSlot(
  id: id,
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [RangedProjectile(id: 'p', name: 'Pfeil', count: pfeile)],
  ),
);

HeroInventoryEntry _bogenEintrag(String bogenId) => HeroInventoryEntry(
  gegenstand: 'Kurzbogen',
  itemType: InventoryItemType.ausruestung,
  source: InventoryItemSource.waffe,
  sourceRef: 'w:Kurzbogen',
  slotRef: 'w#$bogenId',
  istAusgeruestet: true,
);

HeroInventoryEntry _pfeile(String bogenId, String anzahl) => HeroInventoryEntry(
  gegenstand: 'Pfeil',
  anzahl: anzahl,
  itemType: InventoryItemType.verbrauchsgegenstand,
  source: InventoryItemSource.geschoss,
  sourceRef: 'w:Kurzbogen|p:Pfeil',
  slotRef: 'w#$bogenId|p#p',
);

// Zwei gleichnamige Bögen mit je einem Pfeilvorrat.
HeroSheet _schuetze() => _held().copyWith(
  combatConfig: CombatConfig(weapons: [_bogen('a', 10), _bogen('b', 20)]),
  inventoryEntries: [
    _bogenEintrag('a'),
    _pfeile('a', '10'),
    _bogenEintrag('b'),
    _pfeile('b', '20'),
  ],
);

// Ein anderer Weg (etwa der Kampf-Tab) hat dem ersten Bogen Pfeile gegeben.
HeroSheet _mitFremdenPfeilen(HeroSheet held) => held.copyWith(
  name: 'Thalion der Kühne',
  combatConfig: CombatConfig(weapons: [_bogen('a', 14), _bogen('b', 20)]),
);

int _pfeileVon(HeroSheet held, int bogen) =>
    held.combatConfig.weaponSlots[bogen].rangedProfile.projectiles.single.count;

void main() {
  late BogenTestRepository repo;

  // Schmal öffnet der Editor als eigene Seite, breit als Seitenpanel.
  Future<void> zeige(
    WidgetTester tester,
    HeroSheet held, {
    bool breit = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = breit
        ? const Size(1600, 900)
        : const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [held]);
    final aktionen = ValueNotifier<WorkspaceTabEditActions?>(null);
    addTearDown(aktionen.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ValueListenableBuilder<WorkspaceTabEditActions?>(
                  valueListenable: aktionen,
                  builder: (context, wert, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final aktion in wert?.headerActions ?? const [])
                        Builder(builder: aktion.builder),
                    ],
                  ),
                ),
              ],
            ),
            body: HeroInventoryTab(
              heroId: 'hero-1',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (wert) => aktionen.value = wert,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> oeffneZeile(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey<String>('inventory-row-open-$index')));
    await tester.pumpAndSettle();
  }

  Future<void> speichereEditor(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('inventory-editor-save')),
    );
    await tester.pumpAndSettle();
  }

  Finder editorFeld(String name) =>
      find.byKey(ValueKey<String>('inventory-editor-$name'));

  Future<void> loescheErstenEintrag(WidgetTester tester) async {
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey<String>('inventory-row-delete-0')),
        )
        .onPressed!
        .call();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
  }

  group('Löschen', () {
    testWidgets('trifft den angezeigten Eintrag, nicht die Position', (
      tester,
    ) async {
      await zeige(tester, _held());
      // Inzwischen wurde vor dem Seil eine Fackel gespeichert.
      repo.fremdeAenderung = (held) => held.copyWith(
        name: 'Thalion der Kühne',
        inventoryEntries: const [_fackel, _seil],
      );

      await loescheErstenEintrag(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.inventoryEntries.map((e) => e.gegenstand), ['Fackel']);
      expect(gespeichert.name, 'Thalion der Kühne');
    });

    testWidgets('ein inzwischen geänderter Eintrag wird gemeldet', (
      tester,
    ) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) =>
          held.copyWith(inventoryEntries: [_seil.copyWith(anzahl: '2')]);

      await loescheErstenEintrag(tester);

      expect(
        find.textContaining('Der Gegenstand wurde inzwischen geändert'),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0);
    });
  });

  group('Editor', () {
    testWidgets('ein neuer Gegenstand lässt fremde Kampfänderungen stehen', (
      tester,
    ) async {
      await zeige(tester, _schuetze());
      repo.fremdeAenderung = _mitFremdenPfeilen;

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-header-add')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(editorFeld('name'), 'Fackel');
      await speichereEditor(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.name, 'Thalion der Kühne');
      expect(_pfeileVon(gespeichert, 0), 14);
      expect(
        gespeichert.inventoryEntries.map((e) => e.gegenstand),
        contains('Fackel'),
      );
    });

    testWidgets('Bearbeiten trifft den geöffneten Gegenstand', (tester) async {
      await zeige(tester, _held());
      await oeffneZeile(tester, 0);
      // Inzwischen wurde vor dem Seil eine Fackel gespeichert.
      repo.fremdeAenderung = (held) =>
          held.copyWith(inventoryEntries: const [_fackel, _seil]);

      await tester.enterText(editorFeld('name'), 'Seil, 20 m');
      await speichereEditor(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.inventoryEntries.map((e) => e.gegenstand), [
        'Fackel',
        'Seil, 20 m',
      ]);
    });

    testWidgets('ein inzwischen geänderter Gegenstand wird abgewiesen', (
      tester,
    ) async {
      await zeige(tester, _held(), breit: true);
      await oeffneZeile(tester, 0);
      repo.fremdeAenderung = (held) =>
          held.copyWith(inventoryEntries: [_seil.copyWith(anzahl: '2')]);

      await tester.enterText(editorFeld('name'), 'Seil, 20 m');
      await speichereEditor(tester);

      expect(
        find.text(
          'Speichern fehlgeschlagen: Der Gegenstand wurde inzwischen '
          'geändert oder entfernt.',
        ),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0);
      // Der breite Editor bleibt mit dem Entwurf offen.
      expect(
        find.byKey(const ValueKey<String>('inventory-editor-panel')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(editorFeld('name')).controller!.text,
        'Seil, 20 m',
      );
    });

    testWidgets('der breite Editor bleibt beim geöffneten Gegenstand', (
      tester,
    ) async {
      await zeige(tester, _held(), breit: true);
      await oeffneZeile(tester, 0);
      // Ein anderer Weg speichert sichtbar eine Fackel vor das Seil.
      await repo.saveHero(
        _held().copyWith(inventoryEntries: const [_fackel, _seil]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(editorFeld('name'), 'Seil, 20 m');
      await speichereEditor(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.inventoryEntries.map((e) => e.gegenstand), [
        'Fackel',
        'Seil, 20 m',
      ]);
      expect(
        tester.widget<TextField>(editorFeld('name')).controller!.text,
        'Seil, 20 m',
      );
    });

    testWidgets('eine Geschossmenge erreicht nur ihren eigenen Bogen', (
      tester,
    ) async {
      await zeige(tester, _schuetze());
      repo.fremdeAenderung = _mitFremdenPfeilen;

      await oeffneZeile(tester, 3);
      await tester.enterText(editorFeld('quantity'), '25');
      await speichereEditor(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.name, 'Thalion der Kühne');
      expect(_pfeileVon(gespeichert, 0), 14);
      expect(_pfeileVon(gespeichert, 1), 25);
      expect(gespeichert.inventoryEntries.map((e) => e.anzahl), [
        '',
        '14',
        '',
        '25',
      ]);
    });

    testWidgets('ein Speicherfehler bleibt im Editor', (tester) async {
      await zeige(tester, _held(), breit: true);
      await oeffneZeile(tester, 0);
      repo.schreibFehler = true;

      await tester.enterText(editorFeld('name'), 'Seil, 20 m');
      await speichereEditor(tester);

      expect(
        find.text('Speichern fehlgeschlagen: Speicher voll'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('inventory-editor-panel')),
        findsOneWidget,
      );
    });
  });

  group('Dukaten', () {
    Finder feld() => find.descendant(
      of: find.byKey(const ValueKey<String>('inventory-dukaten-field')),
      matching: find.byType(TextField),
    );

    testWidgets('schnelle Münzschritte zählen vom gespeicherten Betrag', (
      tester,
    ) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) =>
          held.copyWith(name: 'Thalion der Kühne', dukaten: '7');
      final silber = find.byKey(
        const ValueKey<String>('inventory-dukaten-increment-silber'),
      );

      await tester.tap(silber);
      await tester.tap(silber);
      await tester.tap(silber);
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.dukaten, '7,3');
      expect(gespeichert.name, 'Thalion der Kühne');
      expect(tester.widget<TextField>(feld()).controller!.text, '7,3');
    });

    testWidgets('ein eingetippter Betrag wird gesetzt', (tester) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) => held.copyWith(name: 'Thalion der Kühne');

      await tester.enterText(feld(), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.dukaten, '12');
      expect(gespeichert.name, 'Thalion der Kühne');
    });

    testWidgets('Tippen und Münzschritt: der Schritt geht nicht verloren', (
      tester,
    ) async {
      await zeige(tester, _held());

      await tester.enterText(feld(), '12');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-dukaten'),
        ),
      );
      await tester.pumpAndSettle();

      expect((await repo.gespeichert('hero-1')).dukaten, '13');
    });

    testWidgets('ein Speicherfehler wird gemeldet', (tester) async {
      await zeige(tester, _held());
      repo.schreibFehler = true;

      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-silber'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Dukaten nicht gespeichert: Speicher voll'),
        findsOneWidget,
      );
    });
  });
}
