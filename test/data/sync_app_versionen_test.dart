import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';
import '../test_support/sync_geraete.dart';
import '../test_support/veroeffentlichte_app.dart';
import '../test_support/zukunftsfelder.dart';

/// Konto-Sync mit Geraeten, auf denen eine **andere App-Version** laeuft.
///
/// Die andere Version schreibt ueber `GeteilteCloud.speichereFremdenStand`:
/// Ihr Inhalts-Hash ist ueber das rohe JSON gerechnet, gelesen wird mit dem
/// `fromJson` dieser App. So faellt auf, wo diese App einen Stand nicht
/// verlustfrei darstellt und ihn womoeglich still verkuerzt zurueckschreibt.
const String _krieger = 'bestand-f01';
const String _gleichnamig = 'bestand-f06';

// Legt einen Bestandshelden samt Zustand ueber das Sync-Repository an.
Future<void> _importiere(SyncTestGeraet geraet, Bestandsheld held) async {
  final bundle = ladeBestandsheld(held);
  await geraet.repo.saveHero(bundle.hero);
  await geraet.repo.saveHeroState(bundle.hero.id, bundle.state);
}

// Speichert eine Aenderung am lokal gespeicherten Helden.
Future<void> _aendere(
  SyncTestGeraet geraet,
  String heroId,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final held = (await geraet.lokal.loadHeroById(heroId))!;
  await geraet.repo.saveHero(aenderung(held));
}

// Schluessel der Sync-Metadaten eines Helden bzw. seines Zustands.
SyncObjectKey _heldSchluessel(String id) {
  return SyncObjectKey(type: SyncObjectType.hero, id: id);
}

SyncObjectKey _zustandSchluessel(String id) {
  return SyncObjectKey(type: SyncObjectType.heroState, id: id);
}

// Merkt eine Basis, wie sie vor Befund ARCH-07-B10 entstand: der Hash des
// Schreibers als lokaler Hash.
Future<void> _basisVorB10(
  SyncTestGeraet geraet,
  SyncObjectKey schluessel, {
  required String schreiberHash,
  required String revision,
}) {
  return geraet.metadaten.save(
    SyncMetadata(
      key: schluessel,
      localHash: schreiberHash,
      remoteHash: schreiberHash,
      remoteRevision: revision,
      updatedAt: DateTime.utc(2026, 9, 27),
    ),
  );
}

void main() {
  // Der echte Katalog liest Assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  setUp(() async {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
    await _importiere(a, Bestandsheld.kriegerNormal);
    await a.repo.syncNow();
    await b.repo.syncNow();
  });

  // Die andere Version aendert den aktuellen Online-Stand per [aendere].
  Future<void> fremdSchreiben(
    void Function(Map<String, dynamic>) aendere,
  ) async {
    final aktuell = (await cloud.loadHero(_krieger))!;
    final json = aktuell.hero!.toJson();
    aendere(json);
    await cloud.speichereFremdenStand(json, previousRevision: aktuell.revision);
  }

  // Eine Aenderung, die diese App nicht verlustfrei darstellt: doppelte
  // ausgeblendete Talente fasst sie beim Laden zusammen. Unbekannte Felder
  // bewahrt sie inzwischen in allen verschachtelten Modellen.
  void verlustbehaftet(Map<String, dynamic> json) {
    json['hiddenTalentIds'] = <String>['tal_zechen', 'tal_zechen'];
    json['dukaten'] = '99';
  }

  group('Befund ARCH-07-B10: die Sync-Basis ist der lokale Stand', () {
    test(
      'ein fremder Stand wird übernommen, ohne ihn zurückzuschreiben',
      () async {
        await fremdSchreiben(verlustbehaftet);
        final online = (await cloud.loadHero(_krieger))!;
        final schreibvorgaenge = cloud.schreibvorgaenge;

        for (var runde = 0; runde < 2; runde++) {
          await b.repo.syncNow();
          await a.repo.syncNow();
        }

        expect(await b.heldHash(_krieger), isNot(online.contentHash));
        expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '99');
        expect((await a.lokal.loadHeroById(_krieger))!.dukaten, '99');
        expect(cloud.schreibvorgaenge, schreibvorgaenge);
        expect((await cloud.loadHero(_krieger))!.revision, online.revision);
        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);
      },
    );

    test('erst eine echte Änderung lädt die hiesige Fassung hoch', () async {
      await fremdSchreiben(verlustbehaftet);
      await b.repo.syncNow();
      final vorher = cloud.heldSchreibvorgaenge[_krieger]!;

      await _aendere(b, _krieger, (held) => held.copyWith(dukaten: '100'));
      await b.repo.syncNow();

      expect(cloud.heldSchreibvorgaenge[_krieger], vorher + 1);
      // Hochgeladen wird die hiesige, zusammengefasste Fassung.
      final online = (await cloud.loadHero(_krieger))!;
      expect(online.contentHash, await b.heldHash(_krieger));
      expect(online.hero!.toJson()['hiddenTalentIds'], <String>['tal_zechen']);
    });

    test('eine gleichzeitige fremde Änderung wird zum Konflikt statt '
        'überschrieben', () async {
      b.remote.offline = true;
      await _aendere(b, _krieger, (held) => held.copyWith(dukaten: '30'));
      await fremdSchreiben(verlustbehaftet);
      final online = (await cloud.loadHero(_krieger))!;
      b.remote.offline = false;

      await b.repo.syncNow();

      expect(b.konflikte.map((konflikt) => konflikt.id), <String>[
        'hero-$_krieger',
      ]);
      expect((await cloud.loadHero(_krieger))!.revision, online.revision);
      expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '30');
    });

    test('ein fremder Zustand mit neuerer Schemaversion wird nicht '
        'zurückgeschrieben', () async {
      final aktuell = (await cloud.loadHeroState(_krieger))!;
      final json = aktuell.state!.toJson()
        ..['schemaVersion'] = 7
        ..['currentLep'] = 5;
      await cloud.speichereFremdenZustand(
        _krieger,
        json,
        previousRevision: aktuell.revision,
      );
      final vorher = cloud.zustandSchreibvorgaenge[_krieger];

      await b.repo.syncNow();
      await b.repo.syncNow();

      expect((await b.lokal.loadHeroState(_krieger))!.currentLep, 5);
      expect(cloud.zustandSchreibvorgaenge[_krieger], vorher);
    });

    test('eine vor B10 gemerkte Basis führt bei unverändertem Inhalt nicht '
        'zum Upload, sondern wird nachgeführt', () async {
      await fremdSchreiben(verlustbehaftet);
      final zustand = (await cloud.loadHeroState(_krieger))!;
      await cloud.speichereFremdenZustand(
        _krieger,
        zustand.state!.toJson()..['schemaVersion'] = 7,
        previousRevision: zustand.revision,
      );
      // B hat beides schon vor B10 uebernommen: lokal liegt die hiesige
      // Darstellung, gemerkt ist aber der Hash des Schreibers. Genauso sieht
      // es nach einem Update aus, dessen Laden Altdaten umstellt.
      final held = (await cloud.loadHero(_krieger))!;
      final fremderZustand = (await cloud.loadHeroState(_krieger))!;
      await b.lokal.saveHero(held.hero!);
      await b.lokal.saveHeroState(_krieger, fremderZustand.state!);
      await _basisVorB10(
        b,
        _heldSchluessel(_krieger),
        schreiberHash: held.contentHash,
        revision: held.revision,
      );
      await _basisVorB10(
        b,
        _zustandSchluessel(_krieger),
        schreiberHash: fremderZustand.contentHash,
        revision: fremderZustand.revision,
      );
      final vorher = cloud.schreibvorgaenge;

      await b.repo.syncNow();

      expect(cloud.schreibvorgaenge, vorher);
      final basis = (await b.metadaten.load(_heldSchluessel(_krieger)))!;
      expect(basis.localHash, await b.heldHash(_krieger));
      final lokalerZustand = (await b.lokal.loadHeroState(_krieger))!;
      final zustandsBasis = await b.metadaten.load(
        _zustandSchluessel(_krieger),
      );
      expect(zustandsBasis!.localHash, heroStateContentHash(lokalerZustand));

      // Mit nachgefuehrter Basis laeuft der naechste Abgleich normal.
      await a.repo.syncNow();
      await _aendere(a, _krieger, (held) => held.copyWith(dukaten: '42'));
      await a.repo.syncNow();
      await b.repo.syncNow();
      expect(b.konflikte, isEmpty);
      expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '42');
    });
  });

  group('neuere Version mit Feldern in verschachtelten Modellen', () {
    late EchterKatalog katalog;
    late Zukunftsheld zukunft;
    late Zukunftsheld zukunftsZustand;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    setUp(() async {
      final roh = ladeBestandsheldJson(Bestandsheld.kriegerNormal);
      final basis = mitZukunftsfeldern(
        (roh['hero'] as Map).cast<String, dynamic>(),
      );
      // So schreibt die neuere Version: heutiges Format samt Slot-IDs,
      // dazu ihre eigenen Felder an denselben Stellen. Gesetzt werden sie ins
      // JSON, nicht ueber das hiesige Modell, das sie sonst schon verloere.
      final heutig = HeroSheet.fromJson(basis.basis).toJson();
      for (final pfad in basis.pfade) {
        final eltern = pfad.substring(0, pfad.lastIndexOf('/'));
        (wertAn(heutig, eltern) as Map)[zukunftsfeld] = wertAn(
          basis.json,
          pfad,
        );
      }
      zukunft = (basis: basis.basis, json: heutig, pfade: basis.pfade);
      final aktuell = (await cloud.loadHero(_krieger))!;
      await cloud.speichereFremdenStand(
        zukunft.json,
        previousRevision: aktuell.revision,
      );
      zukunftsZustand = zustandMitZukunftsfeldern(
        (roh['state'] as Map).cast<String, dynamic>(),
      );
      final zustand = (await cloud.loadHeroState(_krieger))!;
      await cloud.speichereFremdenZustand(
        _krieger,
        zukunftsZustand.json,
        previousRevision: zustand.revision,
      );
      await a.repo.syncNow();
      await b.repo.syncNow();
    });

    // Prueft jedes Zukunftsfeld in [json] gegen den Stand der neueren Version.
    void expectZukunftsfelder(Map<String, dynamic> json, String wo) {
      for (final pfad in zukunft.pfade) {
        expect(
          wertAn(json, pfad),
          wertAn(zukunft.json, pfad),
          reason: '$wo: $pfad',
        );
      }
    }

    test('der Stand ist hier verlustfrei darstellbar', () async {
      final online = (await cloud.loadHero(_krieger))!;
      final zustand = (await cloud.loadHeroState(_krieger))!;

      expect(await b.heldHash(_krieger), online.contentHash);
      expect(await a.heldHash(_krieger), online.contentHash);
      for (final geraet in <SyncTestGeraet>[a, b]) {
        final lokal = (await geraet.lokal.loadHeroState(_krieger))!;
        expect(heroStateContentHash(lokal), zustand.contentHash);
      }
    });

    test('Mischbetrieb: das Echo der veröffentlichten App wird ohne Upload '
        'und ohne Konflikt übernommen', () async {
      final aktuell = (await cloud.loadHero(_krieger))!;
      final echo = wieVeroeffentlichteApp(aktuell.hero!.toJson());
      // Die veroeffentlichte App verwirft die Felder (Restrisiko 3); diese
      // Version bewahrt, was sie vorfindet, und stellt nichts wieder her.
      for (final pfad in zukunft.pfade) {
        expect(wertAn(echo, pfad), isNull, reason: pfad);
      }
      await cloud.speichereFremdenStand(
        echo,
        previousRevision: aktuell.revision,
      );
      final zustand = (await cloud.loadHeroState(_krieger))!;
      final zustandsEcho = zustandWieVeroeffentlichteApp(
        zustand.state!.toJson(),
      );
      for (final pfad in zukunftsZustand.pfade) {
        expect(wertAn(zustandsEcho, pfad), isNull, reason: pfad);
      }
      await cloud.speichereFremdenZustand(
        _krieger,
        zustandsEcho,
        previousRevision: zustand.revision,
      );
      final schreibvorgaenge = cloud.schreibvorgaenge;

      for (var runde = 0; runde < 2; runde++) {
        await a.repo.syncNow();
        await b.repo.syncNow();
      }

      expect(cloud.schreibvorgaenge, schreibvorgaenge);
      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      expect(await a.heldHash(_krieger), await b.heldHash(_krieger));
      final lokal = (await b.lokal.loadHeroById(_krieger))!.toJson();
      for (final pfad in zukunft.pfade) {
        expect(wertAn(lokal, pfad), isNull, reason: pfad);
      }
      final lokalerZustand = (await b.lokal.loadHeroState(_krieger))!;
      expect(heroStateContentHash(lokalerZustand), isNotEmpty);
      for (final pfad in zukunftsZustand.pfade) {
        expect(wertAn(lokalerZustand.toJson(), pfad), isNull, reason: pfad);
      }
    });

    test('Bearbeiten über HeroActions und Abgleich erhalten die Felder auf '
        'beiden Geräten', () async {
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(b.repo),
          ...katalog.overrides,
        ],
      );
      addTearDown(container.dispose);

      await container.read(heroActionsProvider).updateHero(_krieger, (held) {
        final waffen = List<MainWeaponSlot>.of(held.combatConfig.weaponSlots);
        final profil = waffen[1].rangedProfile;
        waffen[1] = waffen[1].copyWith(
          name: 'Schwere Armbrust',
          rangedProfile: profil.copyWith(
            projectiles: <RangedProjectile>[
              profil.projectiles.single.copyWith(count: 7),
            ],
          ),
        );
        return bearbeiteVerschachtelteModelle(
          held.copyWith(
            combatConfig: held.combatConfig.copyWith(weapons: waffen),
          ),
        );
      });
      await container
          .read(heroActionsProvider)
          .updateHeroState(_krieger, bearbeiteZustand);
      await b.repo.syncNow();
      await a.repo.syncNow();

      final online = (await cloud.loadHero(_krieger))!.hero!;
      final aufA = (await a.lokal.loadHeroById(_krieger))!;
      final aufB = (await b.lokal.loadHeroById(_krieger))!;
      expect(aufA.combatConfig.weaponSlots[1].name, 'Schwere Armbrust');
      expectZukunftsfelder(online.toJson(), 'Cloud');
      expectZukunftsfelder(aufA.toJson(), 'Gerät A');
      expectZukunftsfelder(aufB.toJson(), 'Gerät B');
      final zustaende = <String, HeroState>{
        'Cloud': (await cloud.loadHeroState(_krieger))!.state!,
        'Gerät A': (await a.lokal.loadHeroState(_krieger))!,
        'Gerät B': (await b.lokal.loadHeroState(_krieger))!,
      };
      for (final eintrag in zustaende.entries) {
        expect(eintrag.value.tempMods.at, 1, reason: eintrag.key);
        for (final pfad in zukunftsZustand.pfade) {
          expect(
            wertAn(eintrag.value.toJson(), pfad),
            wertAn(zukunftsZustand.json, pfad),
            reason: '${eintrag.key}: $pfad',
          );
        }
      }
      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
    });

    group('gleichzeitig geänderte Cloud-Version', () {
      const neuerWert = <String, dynamic>{'ebene': 'neu'};

      // B aendert offline, die neuere Version aendert nur ihr eigenes Feld.
      Future<void> konkurrierendeAenderung() async {
        b.remote.offline = true;
        await _aendere(b, _krieger, (held) => held.copyWith(dukaten: '30'));
        await fremdSchreiben((json) {
          final armbrust = wertAn(json, 'combatConfig/weapons/1') as Map;
          armbrust[zukunftsfeld] = neuerWert;
        });
        b.remote.offline = false;
        await b.repo.syncNow();
      }

      test('ergibt einen Konflikt, der das Feld sichtbar macht', () async {
        await konkurrierendeAenderung();

        final konflikt = b.konflikte.single;
        final diff = b.repo.conflictDiff(konflikt.id)!;
        final pfade = diff.entries.map((eintrag) => eintrag.path.join('/'));
        expect(pfade, contains('dukaten'));
        expect(
          pfade.any(
            (pfad) => pfad.startsWith(
              'combatConfig/weapons/Leichte Armbrust/$zukunftsfeld',
            ),
          ),
          isTrue,
          reason: pfade.join(', '),
        );
      });

      final erwartet = <SyncResolutionChoice, Object?>{
        SyncResolutionChoice.keepRemote: neuerWert,
        SyncResolutionChoice.keepLocal: null,
        SyncResolutionChoice.keepBoth: neuerWert,
      };
      for (final eintrag in erwartet.entries) {
        test('${eintrag.key.name}: nichts geht unbemerkt verloren', () async {
          await konkurrierendeAenderung();
          final altesFeld = wertAn(
            zukunft.json,
            'combatConfig/weapons/1/$zukunftsfeld',
          );

          await b.repo.resolveConflict(b.konflikte.single.id, eintrag.key);
          await a.repo.syncNow();
          await b.repo.syncNow();

          expect(a.konflikte, isEmpty);
          expect(b.konflikte, isEmpty);
          final online = (await cloud.loadHero(_krieger))!.hero!.toJson();
          final feld = wertAn(online, 'combatConfig/weapons/1/$zukunftsfeld');
          // keepLocal verwirft die neuere Aenderung bewusst per Entscheidung
          // und schreibt Bs Stand samt dessen altem Feldwert.
          expect(feld, eintrag.value ?? altesFeld);
          expect(online['dukaten'], eintrag.value == null ? '30' : isNot('30'));
          expect(await a.heldHash(_krieger), await b.heldHash(_krieger));

          if (eintrag.key == SyncResolutionChoice.keepBoth) {
            final kopie = (await b.lokal.listHeroes()).singleWhere(
              (held) => held.name.endsWith('(lokale Kopie)'),
            );
            expect(kopie.dukaten, '30');
            expect(
              wertAn(kopie.toJson(), 'combatConfig/weapons/1/$zukunftsfeld'),
              altesFeld,
            );
          }
        });
      }
    });
  });

  group('veröffentlichte App im Mischbetrieb (f06)', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    setUp(() async {
      await _importiere(a, Bestandsheld.gleichnamigeAusruestung);
      await a.repo.syncNow();
      await b.repo.syncNow();
    });

    // Die veroeffentlichte App laedt den Online-Stand, aendert ihn per
    // [aendere] und speichert ihn in ihrer Fassung zurueck.
    Future<void> altversionSchreibt([
      void Function(Map<String, dynamic> json)? aendere,
    ]) async {
      final aktuell = (await cloud.loadHero(_gleichnamig))!;
      final json = wieVeroeffentlichteApp(aktuell.hero!.toJson());
      aendere?.call(json);
      await cloud.speichereFremdenStand(
        json,
        previousRevision: aktuell.revision,
      );
    }

    // Name und Beschreibung je verknuepftem Eintrag, in Listenreihenfolge.
    Future<List<String>> datenJeSlot(SyncTestGeraet geraet) async {
      final held = (await geraet.lokal.loadHeroById(_gleichnamig))!;
      return <String>[
        for (final entry in held.inventoryEntries)
          if (entry.slotRef != null)
            '${entry.slotRef} ${entry.gegenstand}: ${entry.beschreibung}',
      ];
    }

    test('eine Änderung der Altversion kommt beim richtigen Dolch an, '
        'ohne Rückschrieb und ohne Konflikt', () async {
      await altversionSchreibt((json) {
        final zweiterDolch = zuordnungWieVeroeffentlichteApp(json)[1]!;
        ((json['inventoryEntries'] as List)[zweiterDolch] as Map)['wert'] =
            '99';
      });
      final schreibvorgaenge = cloud.schreibvorgaenge;

      for (var runde = 0; runde < 2; runde++) {
        await a.repo.syncNow();
        await b.repo.syncNow();
      }

      expect(cloud.schreibvorgaenge, schreibvorgaenge);
      for (final geraet in <SyncTestGeraet>[a, b]) {
        final held = (await geraet.lokal.loadHeroById(_gleichnamig))!;
        final zweiterDolch = held.inventoryEntries.singleWhere(
          (entry) => entry.slotRef == 'w#w2',
        );
        expect(zweiterDolch.wert, '99');
        expect(zweiterDolch.beschreibung, 'Beutestück');
        expect(geraet.konflikte, isEmpty);
      }
    });

    test('nach einer Änderung hier ordnet die Altversion weiter alles zu, '
        'und ihr Echo wird ohne Upload übernommen', () async {
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(a.repo),
          ...katalog.overrides,
        ],
      );
      addTearDown(container.dispose);
      await container.read(heroActionsProvider).updateHero(_gleichnamig, (
        held,
      ) {
        final waffen = List<MainWeaponSlot>.of(held.combatConfig.weaponSlots)
          ..removeAt(0)
          ..add(const MainWeaponSlot(name: 'Speer'));
        waffen[0] = waffen[0].copyWith(name: 'Parierdolch');
        return held.copyWith(
          combatConfig: held.combatConfig.copyWith(
            weapons: waffen,
            selectedWeaponIndex: 0,
          ),
        );
      });
      await a.repo.syncNow();
      await b.repo.syncNow();
      final vorEcho = await datenJeSlot(a);

      final online = (await cloud.loadHero(_gleichnamig))!.hero!.toJson();
      final zuordnung = zuordnungWieVeroeffentlichteApp(
        wieVeroeffentlichteApp(online),
      );
      expect(zuordnung, isNot(contains(null)));

      // Die Altversion speichert einmal in ihrer Fassung (ohne IDs).
      await altversionSchreibt();
      final schreibvorgaenge = cloud.schreibvorgaenge;
      for (var runde = 0; runde < 2; runde++) {
        await a.repo.syncNow();
        await b.repo.syncNow();
      }

      expect(cloud.schreibvorgaenge, schreibvorgaenge);
      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      // IDs werden aus den Namen neu abgeleitet; die Daten bleiben beim
      // jeweiligen Slot.
      String ohneId(String zeile) => zeile.substring(zeile.indexOf(' '));
      expect((await datenJeSlot(a)).map(ohneId), vorEcho.map(ohneId));
      expect(await datenJeSlot(b), await datenJeSlot(a));
    });
  });
}
