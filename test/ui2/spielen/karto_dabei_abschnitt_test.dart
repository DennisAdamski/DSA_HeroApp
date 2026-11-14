import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

// Block „Dabei“ (SPIEL-02): Geld und Verbrauchsgegenstände in der Spielansicht.
// Jeder Klick schreibt frisch und ändert nur sein eigenes Feld.

HeroInventoryEntry _verbrauch(String name, int menge, {String? id}) =>
    HeroInventoryEntry(
      gegenstand: name,
      anzahl: '$menge',
      menge: menge,
      instanzId: id ?? 'id-$name',
      itemType: InventoryItemType.verbrauchsgegenstand,
    );

HeroSheet _held({
  String dukaten = '12,5',
  List<HeroInventoryEntry>? eintraege,
}) => testHero('praiodan', 'Praiodan').copyWith(
  dukaten: dukaten,
  inventoryEntries:
      eintraege ??
      [
        _verbrauch('Fackel', 3),
        _verbrauch('Proviant', 5),
        const HeroInventoryEntry(
          gegenstand: 'Seil',
          anzahl: '1',
          instanzId: 'seil',
          itemType: InventoryItemType.ausruestung,
        ),
      ],
);

Finder _k(String key) => find.byKey(ValueKey<String>(key));

void main() {
  Future<ProviderContainer> zeigeMit(
    WidgetTester tester,
    FakeRepository repo,
    String heroId, {
    TestBestand? bestand,
    double breite = 390,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, kind) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: kind!,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: heroId,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<({ProviderContainer container, FakeRepository repo})> zeige(
    WidgetTester tester,
    HeroSheet held, {
    TestBestand? bestand,
    double breite = 390,
    double skalierung = 1,
  }) async {
    final repo = FakeRepository(heroes: [held]);
    final container = await zeigeMit(
      tester,
      repo,
      held.id,
      bestand: bestand,
      breite: breite,
      skalierung: skalierung,
    );
    return (container: container, repo: repo);
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.ensureVisible(ziel);
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Geld und nur die Verbrauchsgegenstände', (tester) async {
    await zeige(tester, _held());
    await tester.ensureVisible(find.text('Dabei'));
    expect(find.text('Dabei'), findsOneWidget);
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, '12 D / 5 S');
    expect(find.text('Fackel'), findsOneWidget);
    expect(find.text('Proviant'), findsOneWidget);
    expect(find.text('Seil'), findsNothing);
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '3');
  });

  testWidgets('Münzschritt schreibt frisch und zeigt den neuen Stand', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held());
    await tippe(tester, _k('karto-dabei-geld-s-plus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '12,6');
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, '12 D / 6 S');

    await tippe(tester, _k('karto-dabei-geld-d-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '11,6');
  });

  testWidgets('Abziehen ist ohne genug Geld gesperrt', (tester) async {
    final aufbau = await zeige(tester, _held(dukaten: '0,05'));
    // 50 Kreuzer: Kreuzer abziehen geht, Silber und Dukaten nicht.
    await tippe(tester, _k('karto-dabei-geld-d-minus'));
    await tippe(tester, _k('karto-dabei-geld-s-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '0,05');
    await tippe(tester, _k('karto-dabei-geld-k-minus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '0,049');
  });

  testWidgets('Menge: schnelle Klicks zählen alle', (tester) async {
    final aufbau = await zeige(tester, _held());
    final minus = _k('karto-dabei-0-minus');
    await tester.ensureVisible(minus);
    await tester.tap(minus);
    await tester.tap(minus);
    await tester.pumpAndSettle();
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.inventoryEntries.first.menge, 1);
    expect(gespeichert.inventoryEntries.first.anzahl, '1');
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '1');
    // Der zweite Eintrag und das Geld blieben unberührt.
    expect(gespeichert.inventoryEntries[1].menge, 5);
    expect(gespeichert.dukaten, '12,5');
  });

  testWidgets('Menge 0 sperrt das Minus, das Plus bleibt', (tester) async {
    final aufbau = await zeige(
      tester,
      _held(eintraege: [_verbrauch('Fackel', 0)]),
    );
    await tippe(tester, _k('karto-dabei-0-minus'));
    expect(
      (await aufbau.repo.loadHeroById('praiodan'))!
          .inventoryEntries
          .single
          .menge,
      0,
    );
    await tippe(tester, _k('karto-dabei-0-plus'));
    expect(
      (await aufbau.repo.loadHeroById('praiodan'))!
          .inventoryEntries
          .single
          .menge,
      1,
    );
  });

  testWidgets('Freitext-Menge hat keine Schritte', (tester) async {
    await zeige(
      tester,
      _held(
        eintraege: [
          const HeroInventoryEntry(
            gegenstand: 'Wein',
            anzahl: 'ein paar',
            instanzId: 'wein',
            itemType: InventoryItemType.verbrauchsgegenstand,
          ),
        ],
      ),
    );
    await tester.ensureVisible(find.text('Wein'));
    expect(find.text('ein paar'), findsOneWidget);
    // Die Knöpfe stehen da, tun aber nichts.
    final plus = tester.widget<InkWell>(
      find.descendant(
        of: _k('karto-dabei-0-plus'),
        matching: find.byType(InkWell),
      ),
    );
    expect(plus.onTap, isNull);
  });

  testWidgets('rechnet vom gespeicherten Stand, nicht vom angezeigten', (
    tester,
  ) async {
    // Die Anzeige zeigt 12,5 D und 3 Fackeln; gespeichert sind 20 D und 7.
    final angezeigt = _held();
    final gespeichert = _held(
      dukaten: '20',
      eintraege: [_verbrauch('Fackel', 7), _verbrauch('Proviant', 5)],
    );
    final repo = _AndererStand(angezeigt, frisch: gespeichert);
    await zeigeMit(tester, repo, angezeigt.id);
    expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '3');

    await tippe(tester, _k('karto-dabei-0-minus'));
    expect(repo.zuletztGespeichert!.inventoryEntries.first.menge, 6);
    expect(repo.zuletztGespeichert!.dukaten, '20');

    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    expect(repo.zuletztGespeichert!.dukaten, '21');
  });

  testWidgets('ein inzwischen entfernter Gegenstand meldet den Grund', (
    tester,
  ) async {
    final angezeigt = _held();
    final repo = _AndererStand(
      angezeigt,
      frisch: _held(eintraege: [_verbrauch('Proviant', 5)]),
    );
    await zeigeMit(tester, repo, angezeigt.id);
    await tippe(tester, _k('karto-dabei-0-minus'));
    await tester.ensureVisible(_k('karto-dabei-fehler'));
    expect(
      tester.widget<Text>(_k('karto-dabei-fehler')).data,
      contains('inzwischen geändert oder entfernt'),
    );
    expect(repo.zuletztGespeichert, isNull);

    // Der nächste Schritt räumt die Meldung wieder weg.
    await tippe(tester, _k('karto-dabei-1-plus'));
    expect(_k('karto-dabei-fehler'), findsNothing);
  });

  testWidgets('zwischenzeitlich anderswo Geändertes bleibt erhalten', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held());
    final aktuell = (await aufbau.repo.loadHeroById('praiodan'))!;
    await aufbau.repo.saveHero(
      aktuell.copyWith(
        dukaten: '20',
        inventoryEntries: [_verbrauch('Fackel', 3), _verbrauch('Proviant', 9)],
      ),
    );
    await tippe(tester, _k('karto-dabei-0-minus'));
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.dukaten, '20');
    expect(gespeichert.inventoryEntries.map((e) => e.menge), [2, 9]);
  });

  testWidgets('Betrag hinzufügen und abziehen über den Dialog', (tester) async {
    final aufbau = await zeige(tester, _held());
    await tippe(tester, _k('karto-dabei-geld'));
    await tester.enterText(_k('karto-dabei-betrag'), '3 D 5 S');
    await tester.tap(_k('karto-dabei-hinzufuegen'));
    await tester.pumpAndSettle();
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '16');

    await tippe(tester, _k('karto-dabei-geld'));
    await tester.enterText(_k('karto-dabei-betrag'), '1,5');
    await tester.tap(_k('karto-dabei-abziehen'));
    await tester.pumpAndSettle();
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '14,5');
  });

  testWidgets('Dialog weist Unlesbares und zu hohen Abzug ab', (tester) async {
    final aufbau = await zeige(tester, _held(dukaten: '1'));
    await tippe(tester, _k('karto-dabei-geld'));

    await tester.enterText(_k('karto-dabei-betrag'), 'viel');
    await tester.tap(_k('karto-dabei-hinzufuegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bitte einen Betrag'), findsOneWidget);

    await tester.enterText(_k('karto-dabei-betrag'), '2');
    await tester.tap(_k('karto-dabei-abziehen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nicht genug Geld'), findsOneWidget);
    // Der Dialog bleibt offen, nichts wurde geschrieben.
    expect(_k('karto-dabei-betrag'), findsOneWidget);
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '1');

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(_k('karto-dabei-betrag'), findsNothing);
  });

  testWidgets('unlesbarer Geldstand wird gezeigt und sperrt die Schritte', (
    tester,
  ) async {
    final aufbau = await zeige(tester, _held(dukaten: 'ca. viel'));
    await tester.ensureVisible(_k('karto-dabei-geld-unlesbar'));
    expect(tester.widget<Text>(_k('karto-dabei-geld-wert')).data, 'ca. viel');
    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, 'ca. viel');
  });

  testWidgets('ohne Verbrauchsgegenstände steht ein Hinweis da', (
    tester,
  ) async {
    await zeige(tester, _held(eintraege: const []));
    await tester.ensureVisible(_k('karto-dabei-leer'));
    expect(
      find.text('Keine Verbrauchsgegenstände im Inventar.'),
      findsOneWidget,
    );
  });

  testWidgets('viele Gegenstände klappen mit „Alle zeigen“ auf', (
    tester,
  ) async {
    await zeige(
      tester,
      _held(eintraege: [for (var i = 1; i <= 9; i++) _verbrauch('Ding $i', i)]),
    );
    await tester.ensureVisible(_k('karto-dabei-alle'));
    expect(find.text('Ding 6'), findsOneWidget);
    expect(find.text('Ding 7'), findsNothing);
    expect(find.text('Alle zeigen (3 weitere)'), findsOneWidget);

    await tippe(tester, _k('karto-dabei-alle'));
    expect(find.text('Ding 9'), findsOneWidget);
    expect(find.text('Weniger zeigen'), findsOneWidget);
  });

  group('weite Stufe (SPIEL-07)', () {
    HeroSheet mitBreite(int anzahl, SpielkachelBreite? breite) =>
        _held(
          eintraege: [
            for (var i = 1; i <= anzahl; i++) _verbrauch('Ding $i', i),
          ],
        ).copyWith(
          spielansicht: breite == null
              ? null
              : HeroSpielansicht(
                  kacheln: [HeroSpielkachel(id: 'dabei', breite: breite)],
                ),
        );

    testWidgets('mittel zeigt zwölf Gegenstände in zwei Spalten', (
      tester,
    ) async {
      await zeige(
        tester,
        mitBreite(15, SpielkachelBreite.mittel),
        breite: 1280,
      );
      await tester.ensureVisible(_k('karto-dabei-alle'));
      expect(find.text('Ding 12'), findsOneWidget);
      expect(find.text('Ding 13'), findsNothing);
      expect(find.text('Alle zeigen (3 weitere)'), findsOneWidget);
      final erste = tester.getTopLeft(find.text('Ding 1'));
      final zweite = tester.getTopLeft(find.text('Ding 2'));
      expect(zweite.dy, erste.dy);
      expect(zweite.dx, greaterThan(erste.dx));

      await tippe(tester, _k('karto-dabei-alle'));
      expect(find.text('Ding 15'), findsOneWidget);
    });

    testWidgets('bis zwölf gibt es nichts aufzuklappen', (tester) async {
      await zeige(
        tester,
        mitBreite(12, SpielkachelBreite.mittel),
        breite: 1280,
      );
      await tester.ensureVisible(find.text('Ding 12'));
      expect(find.text('Ding 12'), findsOneWidget);
      expect(_k('karto-dabei-alle'), findsNothing);
    });

    testWidgets('die Standardbreite bleibt bei sechs', (tester) async {
      await zeige(tester, mitBreite(15, null), breite: 390);
      await tester.ensureVisible(_k('karto-dabei-alle'));
      expect(find.text('Ding 6'), findsOneWidget);
      expect(find.text('Ding 7'), findsNothing);
      expect(find.text('Alle zeigen (9 weitere)'), findsOneWidget);
    });

    for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('mittel bei $breite dp, Schrift $skalierung, ohne '
            'Überlauf', (tester) async {
          await zeige(
            tester,
            mitBreite(15, SpielkachelBreite.mittel),
            breite: breite,
            skalierung: skalierung,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('Benutzen erscheint nur mit Brücke und Wirkung', (tester) async {
    final held = _held(
      eintraege: [
        _verbrauch('Fackel', 3),
        _verbrauch(
          'Heiltrank',
          2,
        ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
      ],
    );
    // Ohne Gefechtsbrücke bleibt es beim Zählen.
    await zeige(tester, held);
    expect(_k('karto-dabei-1-benutzen'), findsNothing);

    // Mit Brücke nur beim Eintrag mit Wirkung.
    await zeige(tester, held, bestand: _BestandMitGegenstand());
    expect(_k('karto-dabei-0-benutzen'), findsNothing);
    expect(_k('karto-dabei-1-benutzen'), findsOneWidget);
  });

  testWidgets('Benutzen öffnet den Dialog, der Block schreibt nichts', (
    tester,
  ) async {
    final bestand = _BestandMitGegenstand();
    final aufbau = await zeige(
      tester,
      _held(
        eintraege: [
          _verbrauch(
            'Heiltrank',
            2,
          ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
        ],
      ),
      bestand: bestand,
    );
    await tippe(tester, _k('karto-dabei-0-benutzen'));
    expect(bestand.benutzt, ['Heiltrank']);
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.inventoryEntries.first.menge, 2);
  });

  testWidgets('ein aufgebrauchter Trank lässt sich nicht benutzen', (
    tester,
  ) async {
    final bestand = _BestandMitGegenstand();
    await zeige(
      tester,
      _held(
        eintraege: [
          _verbrauch(
            'Heiltrank',
            0,
          ).copyWith(vitalwirkung: const Vitalwirkung(lep: 5)),
        ],
      ),
      bestand: bestand,
    );
    await tester.ensureVisible(_k('karto-dabei-0-benutzen'));
    await tester.tap(_k('karto-dabei-0-benutzen'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(bestand.benutzt, isEmpty);
  });

  group('Munition', () {
    HeroSheet schuetze() => _held().copyWith(
      combatConfig: const CombatConfig(
        weapons: [
          MainWeaponSlot(
            id: 'w-bogen',
            name: 'Kurzbogen',
            combatType: WeaponCombatType.ranged,
            rangedProfile: RangedWeaponProfile(
              projectiles: [
                RangedProjectile(id: 'p-pfeil', name: 'Pfeile', count: 2),
              ],
              selectedProjectileIndex: 0,
            ),
          ),
        ],
      ),
    );

    int bestand(HeroSheet held) => held
        .combatConfig
        .weaponSlots
        .single
        .rangedProfile
        .projectiles
        .single
        .count;

    testWidgets('ohne Fernkampfwaffe kein Abschnitt', (tester) async {
      await zeige(tester, _held());
      expect(find.text('Munition'), findsNothing);
    });

    testWidgets('zeigt Geschoss, Waffe und Bestand', (tester) async {
      await zeige(tester, schuetze());
      await tester.ensureVisible(_k('karto-dabei-munition-0'));
      expect(find.text('Munition'), findsOneWidget);
      expect(find.text('Pfeile'), findsOneWidget);
      expect(find.text('Kurzbogen · aktiv'), findsOneWidget);
      expect(tester.widget<Text>(_k('karto-dabei-munition-0-menge')).data, '2');
    });

    testWidgets('Schritte zählen alle und führen das Inventar mit', (
      tester,
    ) async {
      final aufbau = await zeige(tester, schuetze());
      final minus = _k('karto-dabei-munition-0-minus');
      await tester.ensureVisible(minus);
      await tester.tap(minus);
      await tester.tap(minus);
      await tester.pumpAndSettle();
      final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
      expect(bestand(gespeichert), 0);
      // Der verknüpfte Inventareintrag folgt dem Slot.
      final eintrag = gespeichert.inventoryEntries.singleWhere(
        (e) => e.source == InventoryItemSource.geschoss,
      );
      expect(eintrag.anzahl, '0');
      expect(gespeichert.dukaten, '12,5');
      expect(tester.widget<Text>(_k('karto-dabei-munition-0-menge')).data, '0');
      // Leer: Minus gesperrt, Plus bleibt.
      await tippe(tester, minus);
      expect(bestand((await aufbau.repo.loadHeroById('praiodan'))!), 0);
      await tippe(tester, _k('karto-dabei-munition-0-plus'));
      expect(bestand((await aufbau.repo.loadHeroById('praiodan'))!), 1);
    });

    testWidgets('schmal mit Schrift 2 ohne Überlauf', (tester) async {
      await zeige(tester, schuetze(), breite: 360, skalierung: 2);
      await tester.ensureVisible(_k('karto-dabei-munition-0'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ein laufendes Gefecht sperrt die Munition', (tester) async {
      final aufbau = await zeige(tester, schuetze());
      aufbau.container
          .read(gefechtProvider('praiodan').notifier)
          .setzen(const Gefechtszustand(iniWurf: 6, dk: 'N'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('karto-dabei-munition-gefecht'));
      await tippe(tester, _k('karto-dabei-munition-0-plus'));
      expect(bestand((await aufbau.repo.loadHeroById('praiodan'))!), 2);
      // Geld bleibt bedienbar.
      await tippe(tester, _k('karto-dabei-geld-d-plus'));
      expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '13,5');
    });

    testWidgets('eine offene Planung sperrt auch die Munition', (tester) async {
      final held = schuetze();
      final aufbau = await zeige(tester, held);
      aufbau.container
          .read(advancementSessionProvider('praiodan').notifier)
          .start(hero: held, catalog: testCatalog);
      await tester.pumpAndSettle();
      await tippe(tester, _k('karto-dabei-munition-0-plus'));
      expect(bestand((await aufbau.repo.loadHeroById('praiodan'))!), 2);
      expect(_k('karto-dabei-munition-gefecht'), findsNothing);
    });
  });

  testWidgets('eine offene Planung sperrt alle Schritte', (tester) async {
    final held = _held();
    final aufbau = await zeige(tester, held);
    aufbau.container
        .read(advancementSessionProvider('praiodan').notifier)
        .start(hero: held, catalog: testCatalog);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_k('karto-dabei-gesperrt'));
    expect(_k('karto-dabei-gesperrt'), findsOneWidget);

    await tippe(tester, _k('karto-dabei-geld-d-plus'));
    await tippe(tester, _k('karto-dabei-0-minus'));
    final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
    expect(gespeichert.dukaten, '12,5');
    expect(gespeichert.inventoryEntries.first.menge, 3);
  });

  group('Verbrauchsgegenstände von Begleitern', () {
    HeroInventoryEntry beiBegleiter(String name, int menge, String traegerId) =>
        HeroInventoryEntry(
          gegenstand: name,
          anzahl: '$menge',
          menge: menge,
          instanzId: 'id-$name',
          itemType: InventoryItemType.verbrauchsgegenstand,
          traegerTyp: InventoryTraeger.begleiter,
          traegerId: traegerId,
        );

    HeroSheet heldMit() =>
        _held(
          dukaten: '0',
          eintraege: [
            _verbrauch('Fackel', 3),
            beiBegleiter('Hafer', 5, 'b1'),
            beiBegleiter('Wasser', 2, 'b1'),
            beiBegleiter('Futter', 4, 'b2'),
          ],
        ).copyWith(
          companions: const [
            HeroCompanion(id: 'b1', name: 'Rosinante'),
            HeroCompanion(id: 'b2', name: 'Falke'),
          ],
        );

    testWidgets('zeigt je Begleiter eine Gruppe, getrennt vom Helden', (
      tester,
    ) async {
      await zeige(tester, heldMit());
      await tester.ensureVisible(_k('karto-dabei-begleiter-0'));
      expect(
        tester.widget<Text>(_k('karto-dabei-begleiter-0')).data,
        'Beim Begleiter: Rosinante',
      );
      expect(
        tester.widget<Text>(_k('karto-dabei-begleiter-1')).data,
        'Beim Begleiter: Falke',
      );
      expect(find.text('Hafer'), findsOneWidget);
      expect(find.text('Futter'), findsOneWidget);
      // Der Held behält seine eigene Liste, ohne „Benutzen“ am Begleiter.
      expect(tester.widget<Text>(_k('karto-dabei-0-menge')).data, '3');
      expect(
        tester.widget<Text>(_k('karto-dabei-begleiter-0-0-menge')).data,
        '5',
      );
      expect(_k('karto-dabei-begleiter-0-0-benutzen'), findsNothing);
    });

    testWidgets(
      '−/+ zählt vom gespeicherten Wert und ändert nur diesen Eintrag',
      (tester) async {
        final aufbau = await zeige(tester, heldMit());
        final minus = _k('karto-dabei-begleiter-0-0-minus');
        await tester.ensureVisible(minus);
        await tester.tap(minus);
        await tester.tap(minus);
        await tester.pumpAndSettle();
        final gespeichert = (await aufbau.repo.loadHeroById('praiodan'))!;
        final hafer = gespeichert.inventoryEntries.firstWhere(
          (e) => e.gegenstand == 'Hafer',
        );
        expect(hafer.menge, 3);
        expect(hafer.anzahl, '3');
        // Träger bleibt der Begleiter, alles andere unberührt.
        expect(hafer.traegerTyp, InventoryTraeger.begleiter);
        expect(hafer.traegerId, 'b1');
        expect(
          gespeichert.inventoryEntries
              .firstWhere((e) => e.gegenstand == 'Wasser')
              .menge,
          2,
        );
        expect(
          gespeichert.inventoryEntries
              .firstWhere((e) => e.gegenstand == 'Fackel')
              .menge,
          3,
        );
        expect(
          tester.widget<Text>(_k('karto-dabei-begleiter-0-0-menge')).data,
          '3',
        );

        await tippe(tester, _k('karto-dabei-begleiter-1-0-plus'));
        expect(
          (await aufbau.repo.loadHeroById('praiodan'))!.inventoryEntries
              .firstWhere((e) => e.gegenstand == 'Futter')
              .menge,
          5,
        );
      },
    );

    testWidgets('ohne Begleiterlast gibt es keine Gruppe', (tester) async {
      await zeige(tester, _held());
      expect(_k('karto-dabei-begleiter-0'), findsNothing);
    });

    testWidgets('eine offene Planung sperrt auch die Begleiterzeilen', (
      tester,
    ) async {
      final held = heldMit();
      final aufbau = await zeige(tester, held);
      aufbau.container
          .read(advancementSessionProvider('praiodan').notifier)
          .start(hero: held, catalog: testCatalog);
      await tester.pumpAndSettle();
      await tippe(tester, _k('karto-dabei-begleiter-0-0-minus'));
      expect(
        (await aufbau.repo.loadHeroById('praiodan'))!.inventoryEntries
            .firstWhere((e) => e.gegenstand == 'Hafer')
            .menge,
        5,
      );
    });
  });

  group('Belastung (Last und Tragkraft)', () {
    HeroInventoryEntry schwer(int gramm) => HeroInventoryEntry(
      gegenstand: 'Amboss',
      anzahl: '1',
      menge: 1,
      instanzId: 'amboss',
      gewichtGramm: gramm,
    );

    String text(WidgetTester tester, String schluessel) =>
        tester.widget<Text>(_k(schluessel)).data!;

    String tipp(WidgetTester tester) => tester
        .widget<Tooltip>(
          find
              .ancestor(
                of: _k('karto-dabei-last'),
                matching: find.byType(Tooltip),
              )
              .first,
        )
        .message!;

    testWidgets('eine Zeile Last, die Herleitung steht im Tooltip', (
      tester,
    ) async {
      await zeige(tester, _held(eintraege: [schwer(4500)], dukaten: '0'));
      await tester.ensureVisible(_k('karto-dabei-last'));
      expect(text(tester, 'karto-dabei-last'), '4,5 / 13 Stein');
      expect(tipp(tester), 'Tragkraft 13 (Körperkraft)');
      expect(_k('karto-dabei-last-hinweis'), findsNothing);
      // Die Quellen pflegt der Inventar-Tab.
      expect(find.text('+ Bärenrune'), findsNothing);
      expect(find.text('+ Andere Tragkraftquelle'), findsNothing);
    });

    testWidgets('über der Tragkraft steht BE +n, die Folge im Tooltip', (
      tester,
    ) async {
      await zeige(
        tester,
        _held(
          dukaten: '0',
          eintraege: [
            schwer(14000),
            const HeroInventoryEntry(gegenstand: 'Beutel', instanzId: 'b'),
          ],
        ),
      );
      await tester.ensureVisible(_k('karto-dabei-last'));
      // Ein Eintrag ohne Gewicht: die Last ist ein Mindestwert.
      expect(text(tester, 'karto-dabei-last'), '≥ 14 / 13 Stein');
      expect(text(tester, 'karto-dabei-last-hinweis'), 'BE +1');
      expect(tipp(tester), contains('im Marsch'));
      expect(tipp(tester), contains('1 getragener Eintrag hat kein Gewicht'));
    });

    testWidgets('Tragkraftquellen zählen mit, ohne hier zu stehen', (
      tester,
    ) async {
      final held = _held(dukaten: '0').copyWith(
        tragkraftBoni: const [
          HeroTragkraftBonus(id: 'a', name: 'Rune', stein: 70, kk: 1),
        ],
      );
      await zeige(tester, held);
      await tester.ensureVisible(_k('karto-dabei-last'));
      // 13 + 1 + 70
      expect(text(tester, 'karto-dabei-last'), '0 / 84 Stein');
      expect(find.text('Rune'), findsNothing);
    });

    testWidgets('Erschöpfung und Überanstrengung stehen nebeneinander', (
      tester,
    ) async {
      await zeige(tester, _held());
      expect(_k('karto-dabei-stufen-nebeneinander'), findsOneWidget);
      final e = tester.getTopLeft(_k('karto-dabei-erschoepfung-menge'));
      final u = tester.getTopLeft(_k('karto-dabei-ueberanstrengung-menge'));
      expect(u.dy, e.dy);
      expect(u.dx, greaterThan(e.dx));
    });

    testWidgets(
      'Erschöpfung und Überanstrengung zählen vom gespeicherten Wert',
      (tester) async {
        final aufbau = await zeige(tester, _held());
        final plus = _k('karto-dabei-erschoepfung-plus');
        await tester.ensureVisible(plus);
        await tester.tap(plus);
        await tester.tap(plus);
        await tester.pumpAndSettle();
        expect((await aufbau.repo.loadHeroState('praiodan'))!.erschoepfung, 2);
        expect(text(tester, 'karto-dabei-erschoepfung-menge'), '2');

        await tippe(tester, _k('karto-dabei-erschoepfung-minus'));
        expect((await aufbau.repo.loadHeroState('praiodan'))!.erschoepfung, 1);

        await tippe(tester, _k('karto-dabei-ueberanstrengung-plus'));
        final zustand = (await aufbau.repo.loadHeroState('praiodan'))!;
        expect(zustand.ueberanstrengung, 1);
        expect(zustand.erschoepfung, 1);
        // Der Bogen bleibt unberührt.
        expect((await aufbau.repo.loadHeroById('praiodan'))!.dukaten, '12,5');
      },
    );

    testWidgets('Minus ist bei 0 gesperrt', (tester) async {
      final aufbau = await zeige(tester, _held());
      await tippe(tester, _k('karto-dabei-erschoepfung-minus'));
      expect(
        (await aufbau.repo.loadHeroState('praiodan'))?.erschoepfung ?? 0,
        0,
      );
    });

    testWidgets('während einer Planung zählen die Stufen weiter', (
      tester,
    ) async {
      final held = _held(dukaten: '0');
      final aufbau = await zeige(tester, held);
      aufbau.container
          .read(advancementSessionProvider('praiodan').notifier)
          .start(hero: held, catalog: testCatalog);
      await tester.pumpAndSettle();

      await tippe(tester, _k('karto-dabei-erschoepfung-plus'));
      expect((await aufbau.repo.loadHeroState('praiodan'))!.erschoepfung, 1);
    });
  });
}

/// Repository, dessen gespeicherter Bogen vom angezeigten abweicht.
///
/// Der Indexstrom zeigt [angezeigt]; geladen wird [frisch], wie nach einer
/// Änderung auf einem anderen Weg. So lässt sich belegen, dass die Schritte
/// vom gespeicherten Stand ausgehen und nie vom Bild.
class _AndererStand extends FakeRepository {
  _AndererStand(HeroSheet angezeigt, {required this.frisch})
    : super(heroes: [angezeigt]);

  final HeroSheet frisch;

  /// Letzter über [saveHero] gespeicherter Bogen, sonst `null`.
  HeroSheet? zuletztGespeichert;

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async =>
      zuletztGespeichert ?? frisch;

  @override
  Future<void> saveHero(HeroSheet hero) async {
    zuletztGespeichert = hero;
  }
}

/// Bestand mit Gefechtsbrücke, die nur das Benutzen eines Gegenstands vermerkt.
class _BestandMitGegenstand extends TestBestand
    implements KartoGefechtsAdapter {
  /// Namen der Gegenstände, für die der Dialog geöffnet wurde.
  final List<String> benutzt = <String>[];

  @override
  Future<bool> gefechtsVitalwirkung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroInventoryEntry eintrag,
  }) async {
    benutzt.add(eintrag.gegenstand);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
