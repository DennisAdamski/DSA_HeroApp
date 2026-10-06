import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_stapel_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/veroeffentlichte_app.dart';

// Abnahme ARCH-03 „Menge und Stapel“: Import und Export erhalten Instanz-IDs,
// Mengen und Slot-Verweise ausdrücklich (überschreibend und als Kopie), zwei
// gleichnamige Stapel bleiben unabhängig bearbeitbar, und eine Version vom
// 29.09. bis 05.10.2026, die nur `anzahl` ändert, wird erkannt.

const String _id = 'bestand-f06';

ProviderContainer _container(FakeRepository repo) {
  final container = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      catalogRuntimeDataProvider.overrideWith((ref) async => _leererKatalog()),
      customCatalogRepositoryProvider.overrideWithValue(
        const CustomCatalogRepository(heroStoragePath: ''),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

CatalogRuntimeData _leererKatalog() => CatalogRuntimeData.resolve(
  baseData: CatalogSourceData(
    version: 'house_rules_v1',
    source: 'tests',
    metadata: const <String, dynamic>{},
    sections: <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final section in editableCatalogSections)
        section: const <Map<String, dynamic>>[],
    },
    reisebericht: const <Map<String, dynamic>>[],
  ),
  customSnapshot: const CustomCatalogSnapshot(),
);

// Ausrüstung samt Identitäten, wie sie Import und Export erhalten müssen.
Object? _ausruestung(HeroSheet held) => jsonDecode(
  jsonEncode(<String, Object?>{
    'inventoryEntries': [for (final e in held.inventoryEntries) e.toJson()],
    'combatConfig': held.combatConfig.toJson(),
  }),
);

// f06 importiert, einmal gespeichert und der rechte Köcher geteilt.
Future<HeroSheet> _vorbereitet(ProviderContainer container) async {
  final aktionen = container.read(heroActionsProvider);
  await aktionen.importHeroBundle(
    ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung),
    resolution: ImportConflictResolution.overwriteExisting,
  );
  return aktionen.updateHero(_id, (held) {
    final rechts = held.inventoryEntries.singleWhere(
      (e) =>
          e.source == InventoryItemSource.geschoss &&
          e.beschreibung == 'Köcher rechts',
    );
    return mitGeteiltemStapel(
      held,
      rechts,
      abspalten: 5,
      woGetragen: 'Rucksack',
      neueId: 'rucksack-pfeile',
    );
  });
}

void main() {
  test('Export und Import erhalten IDs, Mengen und Verweise', () async {
    final quelle = _container(FakeRepository.empty());
    final vorher = await _vorbereitet(quelle);
    final export = await quelle.read(heroActionsProvider).buildExportJson(_id);
    expect(vorher.inventoryEntries.every((e) => e.instanzId != null), isTrue);
    expect(
      vorher.inventoryEntries.where((e) => e.slotRef != null),
      hasLength(8),
    );

    for (final art in ImportConflictResolution.values) {
      final repo = FakeRepository(heroes: [vorher]);
      final aktionen = _container(repo).read(heroActionsProvider);
      final bundle = await aktionen.parseImportJson(export);
      final id = await aktionen.importHeroBundle(bundle, resolution: art);

      final nachher = (await repo.loadHeroById(id))!;
      expect(
        id == _id,
        art == ImportConflictResolution.overwriteExisting,
        reason: art.name,
      );
      expect(_ausruestung(nachher), _ausruestung(vorher), reason: art.name);
    }
  });

  test('zwei gleichnamige Stapel bleiben unabhängig bearbeitbar', () async {
    final container = _container(FakeRepository.empty());
    final held = await _vorbereitet(container);
    // Rucksack und rechter Köcher heißen beide „Jagdpfeil“.
    final rucksack = held.inventoryEntries.singleWhere(
      (e) => e.instanzId == 'rucksack-pfeile',
    );

    final nachher = await container
        .read(heroActionsProvider)
        .updateHero(
          _id,
          (aktuell) => mitGeaendertemInventarEintrag(
            aktuell,
            rucksack,
            mitInventarMenge(rucksack, 3).copyWith(gegenstand: 'Jagdpfeile'),
          ),
        );

    final geaendert = nachher.inventoryEntries.singleWhere(
      (e) => e.instanzId == 'rucksack-pfeile',
    );
    expect((geaendert.gegenstand, geaendert.menge), ('Jagdpfeile', 3));
    final unberuehrt = [
      for (final e in nachher.inventoryEntries)
        if (e.instanzId != 'rucksack-pfeile') e.toJson(),
    ];
    expect(unberuehrt, [
      for (final e in held.inventoryEntries)
        if (e.instanzId != 'rucksack-pfeile') e.toJson(),
    ]);
  });

  test('eine Version ohne Menge ändert nur die Anzahl: Abweichung', () async {
    final repo = FakeRepository.empty();
    final container = _container(repo);
    final held = await _vorbereitet(container);
    final index = held.inventoryEntries.indexWhere(
      (e) => e.instanzId == 'rucksack-pfeile',
    );

    // Die Version bewahrt `menge` als unbekanntes Feld, schreibt aber `4`.
    final fremd = HeroSheet.fromJson(
      anzahlWieVersionOhneMenge(held.toJson(), index, '4'),
    );
    final eintrag = fremd.inventoryEntries[index];
    final stand = inventarMengenstand(eintrag);
    expect((stand.wirksam, stand.ueberholteMenge), (4, 5));

    // Ein anderes Speichern löst die Abweichung nicht still auf.
    await repo.saveHero(fremd);
    final nachher = await container
        .read(heroActionsProvider)
        .updateHero(_id, (aktuell) => aktuell.copyWith(dukaten: '3'));
    final danach = nachher.inventoryEntries[index];
    expect((danach.anzahl, danach.menge), ('4', 5));
    expect(stapelTeilbar(danach), isTrue, reason: 'rechnet mit 4');
  });
}
