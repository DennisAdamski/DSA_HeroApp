import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _heldMitContainer(Object? container) {
  final json = HeroSheet(
    id: 'h',
    name: 'Held',
    level: 1,
    attributes: const Attributes.zero(),
  ).toJson();
  json['herkunftsModifikatoren'] = container;
  return json;
}

void main() {
  group('Herkunftscontainer', () {
    test('leerer Container bleibt vom Bestandsformat unterscheidbar', () {
      final bestand = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 1,
        attributes: const Attributes.zero(),
      );
      expect(bestand.toJson().containsKey('herkunftsModifikatoren'), isFalse);
      final leer = bestand.copyWith(
        background: bestand.background.copyWith(
          herkunftsModifikatoren: const HeroHerkunftsModifikatoren(),
        ),
      );
      final neu = HeroSheet.fromJson(leer.toJson());
      expect(neu.background.herkunftsModifikatoren, isNotNull);
      expect(neu.background.herkunftsModifikatoren!.rasse, isEmpty);
      expect(neu.background.herkunftsModifikatoren!.kultur, isEmpty);
      expect(neu.background.herkunftsModifikatoren!.profession, isEmpty);
      expect(neu.toJson()['herkunftsModifikatoren'], <String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[],
        'kultur': <Object?>[],
        'profession': <Object?>[],
      });
    });

    test('copyWith erhaelt den Container, null entfernt ihn', () {
      const container = HeroHerkunftsModifikatoren();
      final mit = const HeroBackground().copyWith(
        herkunftsModifikatoren: container,
      );
      expect(mit.copyWith(rasse: 'Elf').herkunftsModifikatoren, isNotNull);
      expect(
        mit.copyWith(herkunftsModifikatoren: null).herkunftsModifikatoren,
        isNull,
      );
    });

    test('unbekannte Version und Herkunft bleiben roh erhalten', () {
      final json = _heldMitContainer(<String, Object?>{
        'formatVersion': 900,
        'zukunft': <String, Object?>{'wert': 42},
      });
      final neu = HeroSheet.fromJson(json);
      expect(
        neu.toJson()['herkunftsModifikatoren'],
        json['herkunftsModifikatoren'],
      );
      expect(neu.background.herkunftsModifikatoren!.istBearbeitbar, isFalse);
      final merkmal = HeroMerkmal.fromJson(<String, dynamic>{
        'text': 'Flink',
        'katalogId': 'adv_flink',
        'herkunft': 'zukunft',
      });
      expect(merkmal.herkunft, isNull);
      expect(merkmal.copyWith(text: 'Neu').toJson()['herkunft'], 'zukunft');
      expect(
        merkmal.copyWith(herkunft: HeroHerkunft.rasse).toJson()['herkunft'],
        'rasse',
      );
      expect(
        merkmal.copyWith(herkunft: null).toJson().containsKey('herkunft'),
        isFalse,
      );
    });

    test('kein Objekt als Container bleibt roh erhalten', () {
      for (final roh in <Object?>[
        'text',
        7,
        <Object?>[1, 2],
      ]) {
        final neu = HeroSheet.fromJson(_heldMitContainer(roh));
        expect(neu.toJson()['herkunftsModifikatoren'], roh);
        expect(neu.background.herkunftsModifikatoren!.istBearbeitbar, isFalse);
      }
    });

    test('Eintraege eines Containers werden gelesen und geschrieben', () {
      final roh = <String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[
          <String, Object?>{
            'id': 'a',
            'art': 'eigenschaft',
            'ziel': 'MU',
            'betrag': 1,
            'text': 'MU+1',
          },
          <String, Object?>{'id': 'b', 'art': 'frei', 'text': 'Hausnotiz'},
        ],
        'kultur': <Object?>[],
        'profession': <Object?>[],
        'spaeter': 5,
      };
      final neu = HeroSheet.fromJson(_heldMitContainer(roh));
      final container = neu.background.herkunftsModifikatoren!;
      expect(container.istBearbeitbar, isTrue);
      expect(container.brauchtPruefung, isFalse);
      expect(container.rasse, hasLength(2));
      expect(
        container.rasse.first.art,
        HeroHerkunftsModifikatorArt.eigenschaft,
      );
      expect(container.rasse.first.ziel, 'MU');
      expect(container.rasse.first.betrag, 1);
      expect(container.rasse.last.betrag, isNull);
      expect(container.eintraegeFuer(HeroHerkunft.rasse), container.rasse);
      expect(neu.toJson()['herkunftsModifikatoren'], roh);
    });

    test(
      'unverstandene Teilstuecke bleiben erhalten und sperren ihre Gruppe',
      () {
        final roh = <String, Object?>{
          'formatVersion': 1,
          'rasse': <Object?>[
            'kein Objekt',
            <String, Object?>{'id': 'a', 'art': 'basiswert', 'betrag': 1.5},
            <String, Object?>{'art': 'frei', 'text': 'ohne ID'},
            <String, Object?>{'id': 'ok', 'art': 'frei', 'text': 'x'},
          ],
          'kultur': 'nicht einmal eine Liste',
          'profession': <Object?>[
            <String, Object?>{'id': 'p', 'art': 'zukunft', 'ziel': 'ZZ'},
          ],
        };
        final neu = HeroSheet.fromJson(_heldMitContainer(roh));
        final container = neu.background.herkunftsModifikatoren!;
        expect(neu.toJson()['herkunftsModifikatoren'], roh);
        expect(container.istBearbeitbar, isTrue);
        expect(container.brauchtPruefung, isTrue);
        expect(container.istGruppeBearbeitbar(HeroHerkunft.rasse), isFalse);
        expect(container.istGruppeBearbeitbar(HeroHerkunft.kultur), isFalse);
        // Eine unbekannte Art ist verstanden (Ersatz frei), die Gruppe bleibt
        // bearbeitbar und der Rohwert der Art wird zurueckgeschrieben.
        expect(container.istGruppeBearbeitbar(HeroHerkunft.profession), isTrue);
        expect(
          container.profession.single.art,
          HeroHerkunftsModifikatorArt.frei,
        );
      },
    );

    test('doppelte IDs bleiben erhalten und sperren die Gruppe', () {
      final roh = <String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[
          <String, Object?>{'id': 'a', 'art': 'frei', 'text': 'x'},
          <String, Object?>{'id': 'a', 'art': 'frei', 'text': 'x'},
        ],
        'kultur': <Object?>[],
        'profession': <Object?>[],
      };
      final container = HeroSheet.fromJson(_heldMitContainer(roh))
          .background
          .herkunftsModifikatoren!;
      expect(container.rasse, hasLength(2));
      expect(container.istGruppeBearbeitbar(HeroHerkunft.rasse), isFalse);
      expect(container.istGruppeBearbeitbar(HeroHerkunft.kultur), isTrue);
      expect(container.toJson(), roh);
    });

    test('unbekannte Felder von Container und Eintrag bleiben erhalten', () {
      final roh = <String, Object?>{
        'formatVersion': 1,
        'rasse': <Object?>[
          <String, Object?>{
            'id': 'a',
            'art': 'frei',
            'text': 'x',
            'neu': <String, Object?>{'k': 1},
          },
        ],
        'kultur': <Object?>[],
        'profession': <Object?>[],
        'zusatz': <Object?>[1],
      };
      final container = HeroSheet.fromJson(_heldMitContainer(roh))
          .background
          .herkunftsModifikatoren!;
      expect(container.unbekannteFelder, <String, Object?>{
        'zusatz': <Object?>[1],
      });
      final geaendert = container.copyWith(
        rasse: <HeroHerkunftsModifikator>[
          container.rasse.single.copyWith(text: 'y'),
        ],
      );
      final json = geaendert.toJson()! as Map<String, Object?>;
      expect(json['zusatz'], <Object?>[1]);
      final eintrag = (json['rasse']! as List).single as Map;
      expect(eintrag['neu'], <String, Object?>{'k': 1});
      expect(eintrag['text'], 'y');
    });
  });

  group('Merkmalsherkunft', () {
    test('Herkunft wird nur bei Belegung geschrieben', () {
      const ohne = HeroMerkmal(katalogId: 'adv_flink', text: 'Flink');
      expect(ohne.toJson().containsKey('herkunft'), isFalse);
      final mit = ohne.copyWith(herkunft: HeroHerkunft.kultur);
      expect(mit.toJson()['herkunft'], 'kultur');
      expect(HeroMerkmal.fromJson(mit.toJson()).herkunft, HeroHerkunft.kultur);
      expect(mit, isNot(ohne));
      expect(mit.hashCode, isNot(ohne.hashCode));
    });

    test('Herkunft ist als Schluessel bekannt', () {
      expect(HeroMerkmal.jsonSchluessel, contains('herkunft'));
      expect(HeroBackground.jsonSchluessel, contains('herkunftsModifikatoren'));
      final json = HeroMerkmal.fromJson(<String, dynamic>{
        'text': 'x',
        'herkunft': 'rasse',
      });
      expect(json.unbekannteFelder, isEmpty);
    });
  });
}
