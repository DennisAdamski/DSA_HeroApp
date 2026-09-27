import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_weapon_profile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/weapon_combat_type.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
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

/// Felder, die `HeroActions.saveHero` beim Import eines Altstands neu
/// berechnet oder abgleicht; `lastModified` stempelt Hive, weil der
/// Altstand keinen Zeitstempel trägt.
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
            held.istAktuellesFormat ? const <String>{} : _importNormalisierung,
            grund: 'Import veränderte mehr als die Normalisierung',
          );
          expectNurGeaendert(
            bundle.state.toJson(),
            zustand1,
            held.istAktuellesFormat ? const <String>{} : const {'lastModified'},
            grund: 'Import veränderte den Zustand',
          );

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
        jsonUnterschiede(fixture.hero.toJson(), nachImport),
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
      }, grund: 'Ausrüsten veränderte fremde Felder');
      final verknuepft = (nachAusruesten['inventoryEntries'] as List)
          .map((entry) => (entry as Map)['sourceRef'])
          .whereType<String>()
          .toList();
      expect(
        verknuepft,
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
      }, grund: 'Rast veränderte fremde Felder');
      expect(nachRast['currentLep'], werte.maxLep);
      expect(nachRast['wpiZustand'], <String, dynamic>{
        'wundenProZone': <String, dynamic>{},
        'kopfIniMalus': 0,
      });

      // Befund ARCH-07-B4: Hive setzt `lastModified` nur, wenn es fehlt.
      // Geladene Objekte bringen ihren Stempel mit, er bleibt also nach
      // allen Schreibvorgängen der des Imports.
      expect(
        nachAusruesten['lastModified'],
        fixture.hero.toJson()['lastModified'],
      );
      expect(nachRast['lastModified'], fixture.state.toJson()['lastModified']);

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
      final exportJson = await speicher.actions.buildExportJson(id);
      final export = await speicher.actions.parseImportJson(exportJson);
      expect(jsonUnterschiede(heldVorher, export.hero.toJson()), isEmpty);
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
