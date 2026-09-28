import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/offhand_equipment_entry.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_weapon_profile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/weapon_combat_type.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';
import '../test_support/zukunftsfelder.dart';

/// Felder, die `HeroActions.saveHero` beim Import eines Altstands neu
/// berechnet oder abgleicht. `lastModified` stempelt jeder Schreibvorgang.
const Set<String> _importNormalisierung = <String>{
  'lastModified',
  'apAvailable',
  'level',
  'startAttributes',
  'ritualCategories',
  'unknownModifierFragments',
  'inventoryEntries',
};

/// Ein geoeffneter Heldenspeicher: echtes Hive plus Provider wie in der App.
class _Speicher {
  _Speicher(this.repo, this.container);

  final HiveHeroRepository repo;
  final ProviderContainer container;
  bool _geschlossen = false;

  HeroActions get actions => container.read(heroActionsProvider);

  /// Schliesst wie beim App-Ende: erst Provider, dann Boxen.
  Future<void> schliessen() async {
    if (_geschlossen) {
      return;
    }
    _geschlossen = true;
    container.dispose();
    await repo.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  Future<_Speicher> oeffnen(String pfad) async {
    final repo = await HiveHeroRepository.create(storagePath: pfad);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        ...katalog.overrides,
        avatarFileStorageProvider.overrideWithValue(
          InMemoryAvatarFileStorage(),
        ),
        heroStorageLocationProvider.overrideWith(
          (ref) async => HeroStorageLocation(
            defaultPath: pfad,
            effectivePath: pfad,
            customPathSupported: false,
            usesCustomPath: false,
          ),
        ),
      ],
    );
    final speicher = _Speicher(repo, container);
    // Hive-Boxnamen gelten pro Isolat: ohne Schliessen saehe der naechste
    // Test die Boxen dieses Tests.
    addTearDown(speicher.schliessen);
    return speicher;
  }

  Future<Map<String, dynamic>> gespeicherterHeld(_Speicher s, String id) async {
    return (await s.repo.loadHeroById(id))!.toJson();
  }

  Future<Map<String, dynamic>> gespeicherterZustand(
    _Speicher s,
    String id,
  ) async {
    return (await s.repo.loadHeroState(id))!.toJson();
  }

  group('Speichergrenze je Bestandsheld', () {
    for (final held in Bestandsheld.values) {
      test(
        '${held.datei}: Import, Neustart und Export erhalten den Inhalt',
        () async {
          final pfad = await hiveTempVerzeichnis('arch07_grenze_');
          var speicher = await oeffnen(pfad);
          final bundle = await speicher.actions.parseImportJson(
            ladeBestandsheldRoh(held.datei),
          );
          final id = await speicher.actions.importHeroBundle(
            bundle,
            resolution: ImportConflictResolution.overwriteExisting,
          );
          final held1 = await gespeicherterHeld(speicher, id);
          final zustand1 = await gespeicherterZustand(speicher, id);

          expectNurGeaendert(
            bundle.hero.toJson(),
            held1,
            held.istAktuellesFormat
                ? const {'lastModified'}
                : _importNormalisierung,
            grund: 'Import veränderte mehr als die Normalisierung',
          );
          expectNurGeaendert(bundle.state.toJson(), zustand1, const {
            'lastModified',
          }, grund: 'Import veränderte den Zustand');

          await speicher.schliessen();
          speicher = await oeffnen(pfad);

          expect(
            jsonUnterschiede(held1, await gespeicherterHeld(speicher, id)),
            isEmpty,
          );
          expect(
            jsonUnterschiede(
              zustand1,
              await gespeicherterZustand(speicher, id),
            ),
            isEmpty,
          );

          final export = await speicher.actions.parseImportJson(
            await speicher.actions.buildExportJson(id),
          );
          expect(jsonUnterschiede(held1, export.hero.toJson()), isEmpty);
          expect(jsonUnterschiede(zustand1, export.state.toJson()), isEmpty);
        },
      );
    }
  });

  test('B2/B3: gleichnamige Waffe behält Daten nach Entfernen, Umbenennen '
      'und Neustart', () async {
    final pfad = await hiveTempVerzeichnis('arch03_waffen_');
    var speicher = await oeffnen(pfad);
    final bundle = ladeBestandsheld(Bestandsheld.gleichnamigeAusruestung);
    final id = await speicher.actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.overwriteExisting,
    );
    final vorAenderung = (await speicher.repo.loadHeroById(id))!;
    final zweiterDolchId = vorAenderung.combatConfig.weaponSlots[1].id;
    expect(zweiterDolchId, isNotEmpty);

    await speicher.actions.updateHero(id, (aktuell) {
      final waffen = List<MainWeaponSlot>.of(aktuell.combatConfig.weaponSlots);
      waffen.removeAt(0);
      waffen[0] = waffen[0].copyWith(name: 'Parierdolch');
      return aktuell.copyWith(
        combatConfig: aktuell.combatConfig.copyWith(
          weapons: waffen,
          selectedWeaponIndex: 0,
        ),
      );
    });
    await speicher.schliessen();
    speicher = await oeffnen(pfad);

    final nachNeustart = (await speicher.repo.loadHeroById(id))!;
    final eintrag = nachNeustart.inventoryEntries.singleWhere(
      (entry) => entry.gegenstand == 'Parierdolch',
    );
    expect(nachNeustart.combatConfig.weaponSlots.first.id, zweiterDolchId);
    expect(eintrag.slotRef, 'w#$zweiterDolchId');
    expect(eintrag.sourceRef, 'w:Parierdolch');
    expect(eintrag.beschreibung, 'Beutestück');
    expect(eintrag.wert, '8');
    expect(eintrag.gewichtGramm, 350);
    expect(
      nachNeustart.inventoryEntries.any(
        (entry) => entry.beschreibung == 'Erbstück mit Runen',
      ),
      isFalse,
    );
    final export = await speicher.actions.parseImportJson(
      await speicher.actions.buildExportJson(id),
    );
    expect(
      jsonUnterschiede(nachNeustart.toJson(), export.hero.toJson()),
      isEmpty,
    );
  });

  test('Felder einer neueren App-Version in der Ausrüstung überstehen '
      'Import, Bearbeiten, Neustart und Export', () async {
    final pfad = await hiveTempVerzeichnis('arch03_zukunft_');
    var speicher = await oeffnen(pfad);
    final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
    final zukunft = mitZukunftsfeldern(
      (roh['hero'] as Map).cast<String, dynamic>(),
    );
    roh['hero'] = zukunft.json;
    final bundle = await speicher.actions.parseImportJson(jsonEncode(roh));
    final id = await speicher.actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.overwriteExisting,
    );
    final kopieId = await speicher.actions.importHeroBundle(
      bundle,
      resolution: ImportConflictResolution.createNewHero,
    );
    final vorher = (await speicher.repo.loadHeroById(id))!;
    final idsVorher = vorher.combatConfig.weaponSlots.map((slot) => slot.id);

    await speicher.actions.updateHero(id, (aktuell) {
      final kampf = aktuell.combatConfig;
      final waffen = List<MainWeaponSlot>.of(kampf.weaponSlots);
      final armbrust = waffen[1];
      final profil = armbrust.rangedProfile;
      waffen[1] = armbrust.copyWith(
        name: 'Schwere Armbrust',
        rangedProfile: profil.copyWith(
          projectiles: <RangedProjectile>[
            profil.projectiles.single.copyWith(count: 7),
          ],
        ),
      );
      final stuecke = List<ArmorPiece>.of(kampf.armor.pieces);
      stuecke[0] = stuecke[0].copyWith(rs: stuecke[0].rs + 1);
      final nebenhand = <OffhandEquipmentEntry>[
        kampf.offhandEquipment.single.copyWith(name: 'Großschild'),
      ];
      return aktuell.copyWith(
        combatConfig: kampf.copyWith(
          weapons: waffen,
          armor: kampf.armor.copyWith(pieces: stuecke),
          offhandEquipment: nebenhand,
        ),
      );
    });
    await speicher.schliessen();
    speicher = await oeffnen(pfad);

    for (final heldId in <String>[id, kopieId]) {
      final export = jsonDecode(await speicher.actions.buildExportJson(heldId));
      final heldJson = (export as Map)['hero'];
      for (final feldPfad in zukunft.pfade) {
        expect(
          wertAn(heldJson, feldPfad),
          wertAn(zukunft.json, feldPfad),
          reason: '$heldId: $feldPfad',
        );
      }
    }
    final nachher = (await speicher.repo.loadHeroById(id))!;
    final armbrust = nachher.combatConfig.weaponSlots[1];
    expect(nachher.combatConfig.weaponSlots.map((slot) => slot.id), idsVorher);
    final eintrag = nachher.inventoryEntries.singleWhere(
      (entry) => entry.gegenstand == 'Schwere Armbrust',
    );
    expect(eintrag.slotRef, 'w#${armbrust.id}');
    expect(eintrag.sourceRef, 'w:Schwere Armbrust');
    final bolzen = nachher.inventoryEntries.singleWhere(
      (entry) => entry.gegenstand == 'Bolzen',
    );
    expect(bolzen.anzahl, '7');
    expect(
      nachher.inventoryEntries.map((entry) => entry.gegenstand),
      contains('Großschild'),
    );
  });

  test('Befund ARCH-07-B9: Typ und Träger verknüpfter Einträge überstehen '
      'Speichern, Kampfänderung und Neustart', () async {
    final pfad = await hiveTempVerzeichnis('arch07_b9_');
    var speicher = await oeffnen(pfad);
    final id = await speicher.actions.importHeroBundle(
      ladeBestandsheld(Bestandsheld.kriegerNormal),
      resolution: ImportConflictResolution.overwriteExisting,
    );

    // Wie im Inventareditor: jeder verknüpfte Eintrag bekommt Typ und
    // Träger, der manuelle bleibt unberührt.
    await speicher.actions.updateHero(id, (aktuell) {
      return aktuell.copyWith(
        inventoryEntries: aktuell.inventoryEntries
            .map(
              (entry) => entry.sourceRef == null
                  ? entry
                  : entry.copyWith(
                      typ: 'Typ ${entry.gegenstand}',
                      traegerTyp: InventoryTraeger.begleiter,
                      traegerId: 'maultier',
                    ),
            )
            .toList(growable: false),
      );
    });
    // Jede Kampfänderung speichert erneut über den Abgleich.
    await speicher.actions.updateHero(id, (aktuell) {
      final waffen = List<MainWeaponSlot>.of(aktuell.combatConfig.weaponSlots);
      final armbrust = waffen[1];
      final profil = armbrust.rangedProfile;
      waffen[0] = waffen[0].copyWith(name: 'Anderthalbhänder');
      waffen[1] = armbrust.copyWith(
        rangedProfile: profil.copyWith(
          projectiles: <RangedProjectile>[
            profil.projectiles.single.copyWith(count: 3),
          ],
        ),
      );
      return aktuell.copyWith(
        combatConfig: aktuell.combatConfig.copyWith(weapons: waffen),
      );
    });
    await speicher.schliessen();
    speicher = await oeffnen(pfad);

    final nachher = (await speicher.repo.loadHeroById(id))!;
    final verknuepft = nachher.inventoryEntries
        .where((entry) => entry.sourceRef != null)
        .toList(growable: false);
    expect(verknuepft.map((entry) => entry.gegenstand), <String>[
      'Anderthalbhänder',
      'Leichte Armbrust',
      'Bolzen',
      'Kettenhemd',
      'Lederhelm',
      'Holzschild',
    ]);
    for (final entry in verknuepft) {
      final typ = entry.gegenstand == 'Anderthalbhänder'
          ? 'Typ Langschwert'
          : 'Typ ${entry.gegenstand}';
      expect(entry.typ, typ, reason: entry.gegenstand);
      expect(
        entry.traegerTyp,
        InventoryTraeger.begleiter,
        reason: entry.gegenstand,
      );
      expect(entry.traegerId, 'maultier', reason: entry.gegenstand);
    }
    final bolzen = verknuepft.singleWhere((e) => e.gegenstand == 'Bolzen');
    expect(bolzen.anzahl, '3');
    final manuell = nachher.inventoryEntries.singleWhere(
      (entry) => entry.sourceRef == null,
    );
    expect(manuell.traegerTyp, InventoryTraeger.held);
    expect(manuell.traegerId, isNull);
  });

  group('Ablauf mit f01', () {
    test('importieren, steigern, ausrüsten, spielen, neu öffnen, '
        'exportieren', () async {
      final pfad = await hiveTempVerzeichnis('arch07_ablauf_');
      var speicher = await oeffnen(pfad);
      final fixture = ladeBestandsheld(Bestandsheld.kriegerNormal);

      // 1. Importieren.
      final id = await speicher.actions.importHeroBundle(
        await speicher.actions.parseImportJson(
          ladeBestandsheldRoh(Bestandsheld.kriegerNormal.datei),
        ),
        resolution: ImportConflictResolution.overwriteExisting,
      );
      final nachImport = await gespeicherterHeld(speicher, id);
      expect(
        jsonUnterschiede(
          ohneZeitstempel(fixture.hero.toJson()),
          ohneZeitstempel(nachImport),
        ),
        isEmpty,
        reason: 'aktuelles Format ist beim Import eine Identität',
      );

      // 2. Steigern: MU 14 → 15 und Klettern 5 → 6 in einer Runde.
      final runde = speicher.container.read(
        advancementSessionProvider(id).notifier,
      );
      runde.start(
        hero: (await speicher.repo.loadHeroById(id))!,
        catalog: katalog.catalog,
      );
      final sessionId = speicher.container
          .read(advancementSessionProvider(id))!
          .sessionId;
      runde
        ..add(
          HeroAdvancementEntry(
            id: 'ablauf-mu',
            sessionId: sessionId,
            createdAt: DateTime.utc(2026, 9, 21, 19),
            kind: AdvancementKind.attribute,
            targetId: 'mu',
            label: 'Mut',
            fromValue: 14,
            toValue: 15,
            apCost: 150,
          ),
        )
        ..add(
          HeroAdvancementEntry(
            id: 'ablauf-klettern',
            sessionId: sessionId,
            createdAt: DateTime.utc(2026, 9, 21, 19),
            kind: AdvancementKind.talent,
            targetId: 'tal_klettern',
            label: 'Klettern',
            fromValue: 5,
            toValue: 6,
            apCost: 12,
          ),
        );
      await runde.commit();
      final nachSteigern = await gespeicherterHeld(speicher, id);
      expectNurGeaendert(nachImport, nachSteigern, const <String>{
        'attributes/mu',
        'talents/tal_klettern/talentValue',
        'apSpent',
        'apAvailable',
        'level',
        'advancementHistory',
        'lastModified',
      }, grund: 'Steigern veränderte fremde Felder');
      expect(nachSteigern['apSpent'], 2650 + 150 + 12);
      expect(nachSteigern['level'], 8, reason: 'Stufe folgt den AP');
      expect(
        (nachSteigern['advancementHistory'] as List).map(
          (entry) => (entry as Map)['sessionId'],
        ),
        <String>[sessionId, sessionId],
      );

      // 3. Ausrüsten: dritter Waffenslot mit Geschossen.
      await speicher.actions.updateHero(id, (aktuell) {
        const kurzbogen = MainWeaponSlot(
          name: 'Kurzbogen',
          talentId: 'tal_bogen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Kurzbogen',
          tpFlat: 4,
          isOneHanded: false,
          rangedProfile: RangedWeaponProfile(
            projectiles: <RangedProjectile>[
              RangedProjectile(name: 'Jagdpfeil', count: 15),
            ],
            selectedProjectileIndex: 0,
          ),
        );
        final waffen = <MainWeaponSlot>[
          ...aktuell.combatConfig.weaponSlots,
          kurzbogen,
        ];
        return aktuell.copyWith(
          combatConfig: aktuell.combatConfig.copyWith(
            weapons: waffen,
            selectedWeaponIndex: 2,
          ),
        );
      });
      final nachAusruesten = await gespeicherterHeld(speicher, id);
      expectNurGeaendert(nachSteigern, nachAusruesten, const <String>{
        'combatConfig/weapons/2',
        'combatConfig/selectedWeaponIndex',
        // Altfeld, das den gewählten Slot spiegelt.
        'combatConfig/mainWeapon',
        'inventoryEntries',
        'lastModified',
      }, grund: 'Ausrüsten veränderte fremde Felder');
      final eintraege = (nachAusruesten['inventoryEntries'] as List)
          .cast<Map>();
      final verknuepft = eintraege
          .map((entry) => entry['slotRef'])
          .whereType<String>()
          .toList();
      final namen = eintraege
          .map((entry) => entry['sourceRef'])
          .whereType<String>()
          .toList();
      final kampf = (nachAusruesten['combatConfig'] as Map)
          .cast<String, dynamic>();
      final neuerBogen = ((kampf['weapons'] as List)[2] as Map)
          .cast<String, dynamic>();
      final waffenId = neuerBogen['id'] as String;
      final profil = (neuerBogen['rangedProfile'] as Map)
          .cast<String, dynamic>();
      final geschoss = ((profil['projectiles'] as List).single as Map)
          .cast<String, dynamic>();
      final geschossId = geschoss['id'] as String;
      expect(waffenId, isNotEmpty);
      expect(geschossId, isNotEmpty);
      expect(
        verknuepft,
        containsAll(<String>['w#$waffenId', 'w#$waffenId|p#$geschossId']),
      );
      // Den Namensverweis braucht die veroeffentlichte App-Version.
      expect(
        namen,
        containsAll(<String>['w:Kurzbogen', 'w:Kurzbogen|p:Jagdpfeil']),
      );

      // 4. Spielaktion: Treffer mit Wunde, Probe, danach lange Rast.
      await speicher.actions.updateHeroState(id, (aktuell) {
        return aktuell
            .copyWith(
              currentLep: aktuell.currentLep - 7,
              wpiZustand: aktuell.wpiZustand.copyWith(
                wundenProZone: <WundZone, int>{
                  ...aktuell.wpiZustand.wundenProZone,
                  WundZone.brust: 1,
                },
              ),
            )
            .withAppendedDiceLogEntries(<DiceLogEntry>[
              DiceLogEntry(
                timestamp: DateTime.utc(2026, 9, 21, 19, 30),
                type: ProbeType.combatAttack,
                title: 'Langschwert',
                subtitle: 'Attacke',
                success: false,
                diceValues: const <int>[17],
                targetValue: 13,
              ),
            ]);
      });
      final nachTreffer = await gespeicherterZustand(speicher, id);
      expect(nachTreffer['currentLep'], 28 - 7);
      expect(nachTreffer['wpiZustand'], <String, dynamic>{
        'wundenProZone': <String, dynamic>{'brust': 1, 'linkerArm': 1},
        'kopfIniMalus': 0,
      });
      expect(nachTreffer['diceLog'], hasLength(2));

      final heldFuerRast = (await speicher.repo.loadHeroById(id))!;
      final zustandFuerRast = (await speicher.repo.loadHeroState(id))!;
      final werte = buildHeroComputedSnapshot(
        hero: heldFuerRast,
        state: zustandFuerRast,
        catalog: katalog.catalog,
        epicAdvantagesActive: katalog.epicAdvantagesActive,
      ).derivedStats;
      await speicher.actions.saveHeroState(
        id,
        buildFullRestoreState(
          currentState: zustandFuerRast,
          derivedStats: werte,
        ),
      );
      final nachRast = await gespeicherterZustand(speicher, id);
      expectNurGeaendert(nachTreffer, nachRast, const <String>{
        'currentLep',
        'currentAsp',
        'currentKap',
        'currentAu',
        'erschoepfung',
        'wpiZustand',
        'lastModified',
      }, grund: 'Rast veränderte fremde Felder');
      expect(nachRast['currentLep'], werte.maxLep);
      expect(nachRast['wpiZustand'], <String, dynamic>{
        'wundenProZone': <String, dynamic>{},
        'kopfIniMalus': 0,
      });

      // Jeder Schreibvorgang stempelt neu, auch ohne Konto. Vor der
      // Behebung von Befund ARCH-07-B4 blieb der Stempel des Imports stehen.
      DateTime stempel(Map<String, dynamic> json) {
        return DateTime.parse(json['lastModified'] as String);
      }

      final importiert = stempel(fixture.hero.toJson());
      expect(stempel(nachImport).isAfter(importiert), isTrue);
      expect(stempel(nachSteigern).isBefore(stempel(nachImport)), isFalse);
      expect(stempel(nachAusruesten).isBefore(stempel(nachSteigern)), isFalse);
      expect(
        stempel(nachRast).isAfter(stempel(fixture.state.toJson())),
        isTrue,
      );

      // 5./6. Schliessen und neu öffnen.
      final heldVorher = await gespeicherterHeld(speicher, id);
      final zustandVorher = await gespeicherterZustand(speicher, id);
      await speicher.schliessen();
      speicher = await oeffnen(pfad);

      expect(
        jsonUnterschiede(heldVorher, await gespeicherterHeld(speicher, id)),
        isEmpty,
      );
      expect(
        jsonUnterschiede(
          zustandVorher,
          await gespeicherterZustand(speicher, id),
        ),
        isEmpty,
      );
      final geladen = (await speicher.repo.loadHeroById(id))!;
      await speicher.actions.saveHero(geladen);
      expect(
        heroContentHash((await speicher.repo.loadHeroById(id))!),
        heroContentHash(geladen),
        reason: 'erneutes Speichern ohne Änderung ist verlustfrei',
      );

      // 7. Exportieren und in einen leeren Speicher als neuen Helden laden.
      // Verglichen wird mit dem Stand nach dem erneuten Speichern, das den
      // Zeitstempel frisch gesetzt hat.
      final heldGespeichert = await gespeicherterHeld(speicher, id);
      final exportJson = await speicher.actions.buildExportJson(id);
      final export = await speicher.actions.parseImportJson(exportJson);
      expect(jsonUnterschiede(heldGespeichert, export.hero.toJson()), isEmpty);
      expect(jsonUnterschiede(zustandVorher, export.state.toJson()), isEmpty);

      final zweitgeraet = FakeRepository.empty();
      final zweitContainer = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(zweitgeraet),
          ...katalog.overrides,
        ],
      );
      addTearDown(zweitContainer.dispose);
      final neueId = await zweitContainer
          .read(heroActionsProvider)
          .importHeroBundle(
            export,
            resolution: ImportConflictResolution.createNewHero,
          );
      expect(neueId, isNot(id));
      final kopie = (await zweitgeraet.loadHeroById(neueId))!;
      expect(
        heroContentHash(kopie.copyWith(id: id)),
        heroContentHash(HeroSheet.fromJson(heldVorher)),
      );
    });
  });
}
