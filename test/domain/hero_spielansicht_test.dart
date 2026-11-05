import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

import '../test_support/hero_fixtures.dart';

const _ansicht = HeroSpielansicht(
  kacheln: <HeroSpielkachel>[
    HeroSpielkachel(id: 'kampf', breite: SpielkachelBreite.mittel),
    HeroSpielkachel(id: 'dabei', eingeklappt: true),
    HeroSpielkachel(id: 'protokoll', ausgeblendet: true),
  ],
);

void main() {
  final held = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;

  group('Modell', () {
    test('Kacheln schreiben nur belegte Felder', () {
      expect(const HeroSpielkachel(id: 'kampf').toJson(), {'id': 'kampf'});
      expect(_ansicht.kacheln[0].toJson(), {'id': 'kampf', 'breite': 'mittel'});
      expect(_ansicht.kacheln[1].toJson(), {
        'id': 'dabei',
        'eingeklappt': true,
      });
      expect(_ansicht.kacheln[2].toJson(), {
        'id': 'protokoll',
        'ausgeblendet': true,
      });
    });

    test('Rundreise erhält Reihenfolge und Werte', () {
      final zurueck = HeroSpielansicht.fromJson(_ansicht.toJson());
      expect(zurueck, _ansicht);
      expect(zurueck.kacheln.map((k) => k.id), ['kampf', 'dabei', 'protokoll']);
    });

    test('Dubletten und unlesbare Kacheln entfallen, die erste zählt', () {
      final ansicht = HeroSpielansicht.fromJson(<String, dynamic>{
        'kacheln': <Object?>[
          <String, Object?>{'id': 'kampf', 'breite': 'voll'},
          <String, Object?>{'id': 'kampf', 'breite': 'schmal'},
          <String, Object?>{'breite': 'voll'},
          'kaputt',
        ],
      });
      expect(ansicht.kacheln, hasLength(1));
      expect(ansicht.kacheln.single.breite, SpielkachelBreite.voll);
      expect(HeroSpielansicht.fromJson(const {}).kacheln, isEmpty);
    });

    test('eine unbekannte Breite bleibt erhalten, gilt aber als Standard', () {
      final kachel = HeroSpielkachel.fromJson(<String, dynamic>{
        'id': 'kampf',
        'breite': 'riesig',
      })!;
      expect(kachel.breite, isNull);
      expect(kachel.toJson()['breite'], 'riesig');
      expect(kachel.copyWith(eingeklappt: true).toJson()['breite'], 'riesig');
      expect(
        kachel.copyWith(breite: SpielkachelBreite.schmal).toJson()['breite'],
        'schmal',
      );
    });

    test('unbekannte Felder bleiben auf beiden Ebenen erhalten', () {
      final json = _ansicht.toJson();
      json['zukunft'] = 1;
      (json['kacheln'] as List).first['farbe'] = 'rot';
      final roh = HeroSpielansicht.fromJson(json).toJson();
      expect(roh['zukunft'], 1);
      expect((roh['kacheln'] as List).first['farbe'], 'rot');
    });
  });

  group('am Helden', () {
    test('ohne Anordnung wird nichts geschrieben, der Hash bleibt', () {
      expect(held.spielansicht, isNull);
      expect(held.toJson().containsKey('spielansicht'), isFalse);
      expect(
        heroContentHash(HeroSheet.fromJson(held.toJson())),
        heroContentHash(held),
      );
    });

    test('eine Anordnung wird geschrieben, gelesen und ist bekannt', () {
      final mit = held.copyWith(spielansicht: _ansicht);
      final zurueck = HeroSheet.fromJson(mit.toJson());
      expect(zurueck.spielansicht, _ansicht);
      expect(zurueck.unbekannteFelder.containsKey('spielansicht'), isFalse);
      expect(heroContentHash(mit), isNot(heroContentHash(held)));
      expect(heroContentHash(zurueck), heroContentHash(mit));
    });

    test('copyWith behält die Anordnung und kann sie entfernen', () {
      final mit = held.copyWith(spielansicht: _ansicht);
      expect(mit.copyWith(name: 'Neu').spielansicht, _ansicht);
      final ohne = mit.copyWith(spielansicht: null);
      expect(ohne.toJson().containsKey('spielansicht'), isFalse);
      expect(heroContentHash(ohne), heroContentHash(held));
    });
  });

  group('Sync', () {
    Map<String, dynamic> mit(List<HeroSpielkachel> kacheln) => held
        .copyWith(spielansicht: HeroSpielansicht(kacheln: kacheln))
        .toJson();

    HeroSpielansicht ansicht(Map<String, dynamic> json) =>
        HeroSheet.fromJson(json).spielansicht!;

    test('verschiedene Kacheln zweier Geräte führen still zusammen', () {
      final basis = mit(const [
        HeroSpielkachel(id: 'kampf'),
        HeroSpielkachel(id: 'dabei'),
      ]);
      final ergebnis = fuehreSyncZusammen(
        basis: basis,
        lokal: mit(const [
          HeroSpielkachel(id: 'kampf', eingeklappt: true),
          HeroSpielkachel(id: 'dabei'),
        ]),
        online: mit(const [
          HeroSpielkachel(id: 'kampf'),
          HeroSpielkachel(id: 'dabei', breite: SpielkachelBreite.mittel),
        ]),
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isTrue);
      final zusammen = ansicht(ergebnis.ergebnis);
      expect(zusammen.kachel('kampf')!.eingeklappt, isTrue);
      expect(zusammen.kachel('dabei')!.breite, SpielkachelBreite.mittel);
    });

    test('dieselbe Kachel verschieden geändert ist ein Konflikt', () {
      final basis = mit(const [HeroSpielkachel(id: 'kampf')]);
      final ergebnis = fuehreSyncZusammen(
        basis: basis,
        lokal: mit(const [
          HeroSpielkachel(id: 'kampf', breite: SpielkachelBreite.mittel),
        ]),
        online: mit(const [
          HeroSpielkachel(id: 'kampf', breite: SpielkachelBreite.schmal),
        ]),
        regeln: heldZusammenfuehrungsRegeln,
      );
      expect(ergebnis.vollstaendig, isFalse);
    });
  });
}
