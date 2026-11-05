import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

import '../test_support/hero_fixtures.dart';

HeroProbenFavorit _talent(String id) =>
    HeroProbenFavorit.von(ProbenFavoritArt.talent, id);

void main() {
  final held = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;

  group('Modell', () {
    test('die ID setzt sich aus Art und Verweis zusammen', () {
      final favorit = HeroProbenFavorit.von(ProbenFavoritArt.zauber, 'z_blitz');
      expect(favorit.id, 'zauber:z_blitz');
      expect(favorit.art, ProbenFavoritArt.zauber);
      expect(favorit.ref, 'z_blitz');
      expect(favorit.istBekannt, isTrue);
    });

    test('ein Verweis mit Doppelpunkt bleibt vollständig', () {
      final favorit = HeroProbenFavorit.von(ProbenFavoritArt.talent, 'a:b');
      expect(favorit.art, ProbenFavoritArt.talent);
      expect(favorit.ref, 'a:b');
    });

    test(
      'eine unbekannte Art bleibt erhalten, gilt aber nicht als bekannt',
      () {
        const favorit = HeroProbenFavorit(id: 'ritual:r_1');
        expect(favorit.art, isNull);
        expect(favorit.ref, 'r_1');
        expect(favorit.istBekannt, isFalse);
        expect(HeroProbenFavorit.fromJson(favorit.toJson())!.id, 'ritual:r_1');
      },
    );

    test('ohne Verweis ist der Favorit nicht bekannt', () {
      expect(const HeroProbenFavorit(id: 'talent').istBekannt, isFalse);
      expect(const HeroProbenFavorit(id: 'talent:').istBekannt, isFalse);
    });

    test('ohne ID entsteht kein Favorit', () {
      expect(HeroProbenFavorit.fromJson(<String, dynamic>{}), isNull);
      expect(HeroProbenFavorit.fromJson(<String, dynamic>{'id': ' '}), isNull);
      expect(HeroProbenFavorit.fromJson(<String, dynamic>{'id': 3}), isNull);
    });

    test(
      'doppelte und unlesbare Einträge entfallen, die Reihenfolge bleibt',
      () {
        final liste = leseProbenFavoriten(<Object?>[
          _talent('b').toJson(),
          'müll',
          _talent('a').toJson(),
          _talent('b').toJson(),
          <String, Object?>{'x': 1},
        ]);
        expect(liste.map((f) => f.id), ['talent:b', 'talent:a']);
        expect(leseProbenFavoriten('kaputt'), isEmpty);
        expect(leseProbenFavoriten(null), isEmpty);
      },
    );
  });

  group('am Helden', () {
    test('ohne Favoriten wird nichts geschrieben, der Hash bleibt', () {
      expect(held.probenFavoriten, isEmpty);
      expect(held.toJson().containsKey('probenFavoriten'), isFalse);
      expect(
        heroContentHash(HeroSheet.fromJson(held.toJson())),
        heroContentHash(held),
      );
    });

    test('Favoriten werden geschrieben, gelesen und sind bekannt', () {
      final mit = held.copyWith(
        probenFavoriten: <HeroProbenFavorit>[_talent('b'), _talent('a')],
      );
      final zurueck = HeroSheet.fromJson(mit.toJson());
      expect(zurueck.probenFavoriten.map((f) => f.id), [
        'talent:b',
        'talent:a',
      ]);
      expect(zurueck.unbekannteFelder.containsKey('probenFavoriten'), isFalse);
      expect(heroContentHash(mit), isNot(heroContentHash(held)));
      expect(heroContentHash(zurueck), heroContentHash(mit));
    });

    test('copyWith behält die Favoriten und kann sie leeren', () {
      final mit = held.copyWith(
        probenFavoriten: <HeroProbenFavorit>[_talent('a')],
      );
      expect(mit.copyWith(name: 'Neu').probenFavoriten, hasLength(1));
      final leer = mit.copyWith(probenFavoriten: const <HeroProbenFavorit>[]);
      expect(leer.toJson().containsKey('probenFavoriten'), isFalse);
      expect(heroContentHash(leer), heroContentHash(held));
    });

    test(
      'unbekannte Felder eines Favoriten bleiben beim Speichern erhalten',
      () {
        final json = held
            .copyWith(probenFavoriten: <HeroProbenFavorit>[_talent('a')])
            .toJson();
        (json['probenFavoriten'] as List).first['zukunft'] = <String, Object?>{
          'a': 1,
        };
        final roh = HeroSheet.fromJson(json).toJson();
        expect((roh['probenFavoriten'] as List).first['zukunft'], {'a': 1});
      },
    );
  });

  group('Sync', () {
    Map<String, dynamic> mit(List<HeroProbenFavorit> favoriten) {
      final basis = held.toJson();
      if (favoriten.isNotEmpty) {
        basis['probenFavoriten'] = favoriten
            .map((f) => f.toJson())
            .toList(growable: false);
      }
      return basis;
    }

    List<String> ids(Map<String, dynamic> json) =>
        leseProbenFavoriten(json['probenFavoriten']).map((f) => f.id).toList();

    test('verschiedene neue Favoriten zweier Geräte führen still zusammen', () {
      final basis = mit([_talent('a')]);
      final ergebnis = fuehreSyncZusammen(
        basis: basis,
        lokal: mit([_talent('a'), _talent('b')]),
        online: mit([_talent('a'), _talent('c')]),
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isTrue);
      expect(ids(ergebnis.ergebnis), ['talent:a', 'talent:b', 'talent:c']);
    });

    test('derselbe neue Favorit auf beiden Geräten ist kein Konflikt', () {
      final ergebnis = fuehreSyncZusammen(
        basis: mit(const <HeroProbenFavorit>[]),
        lokal: mit([_talent('a')]),
        online: mit([_talent('a')]),
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isTrue);
      expect(ids(ergebnis.ergebnis), ['talent:a']);
    });

    test('ein einseitig entfernter Favorit bleibt entfernt', () {
      final basis = mit([_talent('a'), _talent('b')]);
      final ergebnis = fuehreSyncZusammen(
        basis: basis,
        lokal: mit([_talent('a')]),
        online: basis,
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isTrue);
      expect(ids(ergebnis.ergebnis), ['talent:a']);
    });
  });
}
