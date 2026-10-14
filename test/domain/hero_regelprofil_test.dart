import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

import '../test_support/hero_fixtures.dart';

HeroRegelProfilPaket _paket(String id, {int prioritaet = 0, String s = 'a'}) =>
    HeroRegelProfilPaket(
      paketId: id,
      pruefsumme: 'sum-$id-$s',
      manifest: <String, Object?>{
        'id': id,
        'title': 'Paket $id',
        'description': '',
        'priority': prioritaet,
        'patches': <Object?>[
          <String, Object?>{'section': 'talente'},
        ],
      },
    );

HeroRegelProfil _profil({List<HeroRegelProfilPaket>? pakete}) =>
    HeroRegelProfil(
      catalogVersion: 'house_rules_v1',
      pakete: pakete ?? <HeroRegelProfilPaket>[_paket('p1'), _paket('p2')],
    );

void main() {
  final held = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;

  group('Modell', () {
    test('Round-trip bewahrt Pakete, Kopien und Prüfsummen', () {
      final profil = _profil();
      final zurueck = HeroRegelProfil.fromJson(profil.toJson());
      expect(zurueck, profil);
      expect(zurueck.pakete.map((p) => p.paketId), ['p1', 'p2']);
      expect(zurueck.pakete.first.manifest['title'], 'Paket p1');
      expect(zurueck.toJson(), profil.toJson());
    });

    test('unbekannte Felder von Profil und Paket bleiben erhalten', () {
      final json = _profil().toJson()..['zukunft'] = <String, Object?>{'a': 1};
      (json['pakete'] as List).first['paketZukunft'] = 'x';
      final roh = HeroRegelProfil.fromJson(json).toJson();
      expect(roh['zukunft'], {'a': 1});
      expect((roh['pakete'] as List).first['paketZukunft'], 'x');
    });

    test('Manifestkopie ist unveränderlich und von der Quelle entkoppelt', () {
      final quelle = <String, Object?>{
        'id': 'p',
        'x': <Object?>[1],
      };
      final paket = HeroRegelProfilPaket(
        paketId: 'p',
        pruefsumme: 's',
        manifest: quelle,
      );
      (quelle['x']! as List).add(2);
      expect(paket.manifest['x'], [1]);
      expect(() => paket.manifest['neu'] = 1, throwsUnsupportedError);
    });

    test('Gleichheit folgt Format, Katalogversion und Paketstempeln', () {
      expect(_profil(), _profil());
      expect(_profil().hashCode, _profil().hashCode);
      expect(
        _profil(),
        isNot(
          _profil(
            pakete: [
              _paket('p1'),
              _paket('p2', s: 'b'),
            ],
          ),
        ),
      );
      expect(_profil(), isNot(_profil(pakete: [_paket('p2'), _paket('p1')])));
      expect(
        _profil(),
        isNot(_profil().copyWith(catalogVersion: 'house_rules_v2')),
      );
    });

    test(
      'eine neuere Formatversion gilt als nicht verstanden, bleibt aber',
      () {
        final json = _profil().toJson()..['formatVersion'] = 7;
        final profil = HeroRegelProfil.fromJson(json);
        expect(profil.istVerstanden, isFalse);
        expect(profil.toJson()['formatVersion'], 7);
      },
    );

    test('unlesbare Paketeinträge entfallen, der Rest bleibt', () {
      final json = _profil().toJson();
      json['pakete'] = <Object?>[
        ...(json['pakete'] as List),
        'Müll',
        <String, Object?>{'paketId': 'x'},
      ];
      expect(HeroRegelProfil.fromJson(json).pakete, hasLength(2));
    });
  });

  group('am Helden', () {
    test('ohne Profil wird nichts geschrieben, der Hash bleibt', () {
      expect(held.regelProfil, isNull);
      expect(held.toJson().containsKey('regelProfil'), isFalse);
      expect(
        heroContentHash(HeroSheet.fromJson(held.toJson())),
        heroContentHash(held),
      );
    });

    test('ein Profil wird geschrieben, gelesen und gilt als bekannt', () {
      final mit = held.copyWith(regelProfil: _profil());
      final json = mit.toJson();
      expect(json['regelProfil'], isA<Map<String, dynamic>>());
      final zurueck = HeroSheet.fromJson(json);
      expect(zurueck.regelProfil, _profil());
      expect(zurueck.unbekannteFelder.containsKey('regelProfil'), isFalse);
      expect(heroContentHash(mit), isNot(heroContentHash(held)));
      expect(heroContentHash(zurueck), heroContentHash(mit));
    });

    test('copyWith kann das Profil setzen, behalten und entfernen', () {
      final mit = held.copyWith(regelProfil: _profil());
      expect(mit.copyWith(name: 'Neu').regelProfil, _profil());
      expect(mit.copyWith(regelProfil: null).regelProfil, isNull);
    });

    test('ein Profil, das kein Objekt ist, wird ignoriert', () {
      final json = held.toJson()..['regelProfil'] = 'kaputt';
      expect(HeroSheet.fromJson(json).regelProfil, isNull);
    });
  });

  group('Sync', () {
    Map<String, dynamic> mitProfil(HeroRegelProfil? profil) {
      final basis = held.toJson();
      if (profil != null) basis['regelProfil'] = profil.toJson();
      return basis;
    }

    test(
      'die Paketliste ist atomar: verschiedene Änderungen sind ein Konflikt',
      () {
        final basis = mitProfil(_profil());
        final lokal = mitProfil(_profil(pakete: [_paket('p1'), _paket('p3')]));
        final online = mitProfil(_profil(pakete: [_paket('p2')]));
        final ergebnis = fuehreSyncZusammen(
          basis: basis,
          lokal: lokal,
          online: online,
          regeln: heldZusammenfuehrungsRegeln,
        );
        expect(ergebnis.vollstaendig, isFalse);
        expect(
          ergebnis.konflikte.map((k) => k.schluessel).join(),
          contains('regelProfil'),
        );
      },
    );

    test('eine einseitige Profiländerung wird still übernommen', () {
      final basis = mitProfil(_profil());
      final lokal = mitProfil(_profil(pakete: [_paket('p1')]));
      final ergebnis = fuehreSyncZusammen(
        basis: basis,
        lokal: lokal,
        online: basis,
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isTrue);
      final profil = HeroRegelProfil.fromJson(
        Map<String, dynamic>.from(ergebnis.ergebnis['regelProfil'] as Map),
      );
      expect(profil.paketIds, {'p1'});
    });
  });
}
