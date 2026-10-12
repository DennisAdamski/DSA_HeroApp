import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_bearbeitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';
import '../test_support/veroeffentlichte_app.dart';

/// Herkunftsmodifikatoren (ARCH-02) auf zwei Geräten: Struktur und
/// Textprojektion bilden gemeinsam den fachlichen Zustand. Geschrieben wird
/// über `HeroActions.updateHero` wie in der App; f09 trägt drei Rasse-Einträge
/// (`LEP+10`, `AU+10`, `MR-4`), Kultur und Profession sind leer.
const String _id = 'bestand-f09';

// Führt [aenderung] auf [geraet] über den Schreibweg der App aus.
Future<void> _aendere(
  SyncTestGeraet geraet,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final container = ProviderContainer(
    overrides: [heroRepositoryProvider.overrideWithValue(geraet.repo)],
  );
  addTearDown(container.dispose);
  await container.read(heroActionsProvider).updateHero(_id, aenderung);
}

// Ersetzt die Einträge einer Herkunftsgruppe wie der Editor.
Future<void> _bearbeite(
  SyncTestGeraet geraet,
  HeroHerkunft herkunft,
  List<HeroHerkunftsModifikator> Function(List<HeroHerkunftsModifikator>)
  aenderung,
) {
  return _aendere(geraet, (held) {
    final aktuell = held.background;
    final liste = wirksameHerkunftsModifikatoren(aktuell)
        .eintraegeFuer(herkunft);
    return held.copyWith(
      background: ersetzeHerkunftsEintraege(
        basis: aktuell,
        aktuell: aktuell,
        herkunft: herkunft,
        eintraege: aenderung(liste),
      ),
    );
  });
}

Future<HeroSheet> _held(SyncTestGeraet geraet) async =>
    (await geraet.lokal.loadHeroById(_id))!;

HeroHerkunftsModifikator _neu(String id, String text) =>
    HeroHerkunftsModifikator(id: id, text: text);

// Eintrag `MR-4` der Rasse mit anderem Betrag.
List<HeroHerkunftsModifikator> _mitMr(
  List<HeroHerkunftsModifikator> liste,
  int betrag,
) => [
  for (final e in liste)
    if (e.ziel == 'MR') e.copyWith(betrag: betrag, text: 'MR$betrag') else e,
];

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  // Gemeinsamer Stand nach dem ersten Speichern mit dieser Version.
  Future<void> gemeinsamerStart() async {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
    final bundle = ladeBestandsheld(Bestandsheld.strukturierteMerkmale);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(_id, bundle.state);
    await _aendere(a, (held) => held.copyWith(dukaten: '12'));
    await a.repo.syncNow();
    await b.repo.syncNow();
  }

  void expectHerkunftOhneAbweichung(HeroSheet held) {
    expect(gleicheHerkunftAb(held.background).abweichungen, isEmpty);
    expect(held.background.herkunftsModifikatoren!.brauchtPruefung, isFalse);
  }

  test(
    'der migrierte Container kommt mit denselben IDs auf Gerät B an',
    () async {
      await gemeinsamerStart();
      final beiA = await _held(a);
      final beiB = await _held(b);
      expect(beiA.background.herkunftsModifikatoren!.rasse, hasLength(3));
      expect(
        beiB.background.herkunftsModifikatoren!.toJson(),
        beiA.background.herkunftsModifikatoren!.toJson(),
      );
      expectHerkunftOhneAbweichung(beiB);

      final vorher = cloud.schreibvorgaenge;
      await a.repo.syncNow();
      await b.repo.syncNow();
      expect(cloud.schreibvorgaenge, vorher, reason: 'danach Ruhe');
    },
  );

  group('gleichzeitig geändert', () {
    Future<void> offlineAendern(
      Future<void> Function() a1,
      Future<void> Function() b1,
    ) async {
      a.remote.offline = true;
      b.remote.offline = true;
      await a1();
      await b1();
      a.remote.offline = false;
      b.remote.offline = false;
      await a.repo.syncNow();
      await b.repo.syncNow();
      await a.repo.syncNow();
    }

    test('verschiedene Herkunftsgruppen werden ohne Konflikt '
        'zusammengeführt', () async {
      await gemeinsamerStart();
      await offlineAendern(
        () => _bearbeite(
          a,
          HeroHerkunft.rasse,
          (liste) => [...liste, _neu('a-neu', 'KK+1')],
        ),
        () => _bearbeite(
          b,
          HeroHerkunft.profession,
          (liste) => [...liste, _neu('b-neu', 'Flink')],
        ),
      );

      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      expect(await a.heldHash(_id), await b.heldHash(_id));
      final held = await _held(a);
      final container = held.background.herkunftsModifikatoren!;
      expect(container.rasse.map((e) => e.id), contains('a-neu'));
      expect(container.profession.map((e) => e.id), ['b-neu']);
      expect(held.background.rasseModText, contains('KK+1'));
      expect(held.background.professionModText, 'Flink');
      expectHerkunftOhneAbweichung(held);
    });

    test('verschiedene Einträge derselben Gruppe bleiben konsistent', () async {
      await gemeinsamerStart();
      await offlineAendern(
        () => _bearbeite(
          a,
          HeroHerkunft.rasse,
          (liste) => [...liste, _neu('a-neu', 'KK+1')],
        ),
        () => _bearbeite(
          b,
          HeroHerkunft.rasse,
          (liste) => [...liste, _neu('b-neu', 'KL+1')],
        ),
      );

      // Struktur und Textprojektion ändern sich auf beiden Seiten: Das ist
      // ein sichtbarer Konflikt, nie eine stille Fassung, deren Liste und
      // Text auseinanderlaufen.
      expect(a.konflikte, isEmpty);
      expect(b.konflikte.map((k) => k.id), ['hero-$_id']);
      final beiB = await _held(b);
      expect(
        beiB.background.herkunftsModifikatoren!.rasse.map((e) => e.id),
        contains('b-neu'),
        reason: 'bis zur Entscheidung behält B seine Fassung',
      );
      expectHerkunftOhneAbweichung(beiB);
    });

    test('derselbe Eintrag auf beiden Seiten anders ergibt einen Konflikt, '
        'keine stille Wahl', () async {
      await gemeinsamerStart();
      await offlineAendern(
        () => _bearbeite(a, HeroHerkunft.rasse, (l) => _mitMr(l, -3)),
        () => _bearbeite(b, HeroHerkunft.rasse, (l) => _mitMr(l, -5)),
      );

      final konflikte = [...a.konflikte, ...b.konflikte];
      expect(konflikte.map((k) => k.id).toSet(), {'hero-$_id'});
      final beiB = await _held(b);
      expect(
        beiB.background.herkunftsModifikatoren!.rasse
            .singleWhere((e) => e.ziel == 'MR')
            .betrag,
        -5,
        reason: 'bis zur Entscheidung behält B seine Fassung',
      );
    });

    test('Entfernen gegen Bearbeiten desselben Eintrags bleibt sichtbar '
        'entscheidbar', () async {
      await gemeinsamerStart();
      await offlineAendern(
        () => _bearbeite(
          a,
          HeroHerkunft.rasse,
          (l) => [
            for (final e in l)
              if (e.ziel != 'MR') e,
          ],
        ),
        () => _bearbeite(b, HeroHerkunft.rasse, (l) => _mitMr(l, -5)),
      );

      final konflikte = [...a.konflikte, ...b.konflikte];
      expect(konflikte.map((k) => k.id).toSet(), {'hero-$_id'});
    });

    for (final wahl in <String>['lokal', 'online']) {
      test('Konfliktwahl $wahl hinterlässt eine gültige Herkunft', () async {
        await gemeinsamerStart();
        await offlineAendern(
          () => _bearbeite(a, HeroHerkunft.rasse, (l) => _mitMr(l, -3)),
          () => _bearbeite(b, HeroHerkunft.rasse, (l) => _mitMr(l, -5)),
        );
        final konflikt = b.konflikte.single;
        await b.repo.resolveConflict(
          konflikt.id,
          wahl == 'lokal'
              ? SyncResolutionChoice.keepLocal
              : SyncResolutionChoice.keepRemote,
        );
        await a.repo.syncNow();
        await b.repo.syncNow();

        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);
        final held = await _held(b);
        expectHerkunftOhneAbweichung(held);
        final erwartet = wahl == 'lokal' ? -5 : -3;
        expect(
          held.background.herkunftsModifikatoren!.rasse
              .singleWhere((e) => e.ziel == 'MR')
              .betrag,
          erwartet,
        );
        expect(await a.heldHash(_id), await b.heldHash(_id));
      });
    }
  });

  group('Mischbetrieb', () {
    Future<void> fremdSchreiben(
      void Function(Map<String, dynamic>) aendere,
    ) async {
      final aktuell = (await cloud.loadHero(_id))!;
      final json = aktuell.hero!.toJson();
      aendere(json);
      await cloud.speichereFremdenStand(
        json,
        previousRevision: aktuell.revision,
      );
    }

    test('eine Altversion entfernt den Container: Der Text gilt, erneute '
        'Migration ohne Upload und Konflikt', () async {
      await gemeinsamerStart();
      await fremdSchreiben((json) {
        final alt = wieVeroeffentlichteApp(json);
        json
          ..clear()
          ..addAll(alt)
          ..['rasseModText'] = 'LEP+12, AU+10, MR-4';
      });
      final schreibvorgaenge = cloud.schreibvorgaenge;

      for (var runde = 0; runde < 2; runde++) {
        await a.repo.syncNow();
        await b.repo.syncNow();
      }

      expect(cloud.schreibvorgaenge, schreibvorgaenge);
      expect(a.konflikte, isEmpty);
      expect(b.konflikte, isEmpty);
      final held = await _held(b);
      expect(held.background.herkunftsModifikatoren, isNull);
      final mods = parseModifierTextsForHero(held, catalog: null);
      expect(
        mods.statMods.lep,
        12 + 3 + 2,
        reason: 'Text gilt; Hohe Lebenskraft 3 und LEP+2 aus Vorteilen',
      );

      // Das nächste Speichern migriert den geltenden Text erneut.
      await _aendere(b, (h) => h.copyWith(dukaten: '13'));
      final danach = await _held(b);
      expect(danach.background.herkunftsModifikatoren!.rasse.first.betrag, 12);
      expectHerkunftOhneAbweichung(danach);
    });

    test('eine Version, die den Container bewahrt und nur den Text ändert, '
        'erzeugt eine sichtbare Abweichung ohne Rückschrieb', () async {
      await gemeinsamerStart();
      await fremdSchreiben((json) => json['rasseModText'] = 'LEP+12');
      final schreibvorgaenge = cloud.schreibvorgaenge;

      for (var runde = 0; runde < 2; runde++) {
        await a.repo.syncNow();
        await b.repo.syncNow();
      }

      expect(cloud.schreibvorgaenge, schreibvorgaenge);
      expect(b.konflikte, isEmpty);
      var held = await _held(b);
      expect(gleicheHerkunftAb(held.background).abweichungen.keys, [
        HeroHerkunft.rasse,
      ]);
      expect(held.background.herkunftsModifikatoren!.rasse, hasLength(3));

      // Ein fremdes Speichern auf B löst die Abweichung nicht auf.
      await _aendere(b, (h) => h.copyWith(dukaten: '13'));
      await b.repo.syncNow();
      await a.repo.syncNow();
      held = await _held(a);
      expect(held.dukaten, '13');
      expect(held.background.rasseModText, 'LEP+12');
      expect(gleicheHerkunftAb(held.background).abweichungen.keys, [
        HeroHerkunft.rasse,
      ]);
    });

    for (final wahl in SyncResolutionChoice.values) {
      test('eine neuere Version mit unbekannten Teilfeldern: '
          '${wahl.name} erhält sie', () async {
        await gemeinsamerStart();
        await fremdSchreiben((json) {
          final container =
              json['herkunftsModifikatoren'] as Map<String, dynamic>;
          container['zusatz'] = <String, dynamic>{'k': 1};
          final rasse = container['rasse'] as List;
          (rasse.first as Map<String, dynamic>)['neu'] = 'x';
        });
        await a.repo.syncNow();
        await b.repo.syncNow();
        expect(a.konflikte, isEmpty);
        expect(b.konflikte, isEmpty);

        a.remote.offline = true;
        b.remote.offline = true;
        await _bearbeite(a, HeroHerkunft.rasse, (l) => _mitMr(l, -3));
        await _bearbeite(b, HeroHerkunft.rasse, (l) => _mitMr(l, -5));
        a.remote.offline = false;
        b.remote.offline = false;
        await a.repo.syncNow();
        await b.repo.syncNow();
        await b.repo.resolveConflict(b.konflikte.single.id, wahl);
        await a.repo.syncNow();
        await b.repo.syncNow();

        final helden = await b.lokal.listHeroes();
        expect(helden, isNotEmpty);
        for (final held in helden) {
          final container = held.toJson()['herkunftsModifikatoren'] as Map;
          expect(container['zusatz'], {'k': 1}, reason: held.id);
          expect(((container['rasse'] as List).first as Map)['neu'], 'x');
        }
      });
    }

    test('die Herkunft an einem Merkmal reist über den Sync', () async {
      await gemeinsamerStart();
      await _aendere(
        a,
        (held) => held.copyWith(
          vorteilEintraege: [
            held.vorteilEintraege.first.copyWith(herkunft: HeroHerkunft.kultur),
            ...held.vorteilEintraege.skip(1),
          ],
        ),
      );
      await a.repo.syncNow();
      await b.repo.syncNow();

      expect(b.konflikte, isEmpty);
      final held = await _held(b);
      expect(held.vorteilEintraege.first.herkunft, HeroHerkunft.kultur);
      expect(
        held.vorteilEintraege.skip(1).every((e) => e.herkunft == null),
        isTrue,
      );
    });
  });
}
