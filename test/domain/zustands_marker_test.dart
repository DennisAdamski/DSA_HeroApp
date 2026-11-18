import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_marker.dart';

const _leer = HeroState(
  currentLep: 12,
  currentAsp: 7,
  currentKap: 0,
  currentAu: 16,
);

void main() {
  group('ZustandsMarker', () {
    test('nur belegte Felder stehen im JSON', () {
      const schlicht = ZustandsMarker(id: 'm1', name: 'Furcht');
      expect(schlicht.toJson(), <String, dynamic>{
        'id': 'm1',
        'name': 'Furcht',
      });

      const voll = ZustandsMarker(
        id: 'm2',
        name: 'Betäubung',
        rest: 0,
        notiz: 'Giftpfeil',
      );
      expect(voll.toJson(), <String, dynamic>{
        'id': 'm2',
        'name': 'Betäubung',
        'rest': 0,
        'notiz': 'Giftpfeil',
      });
    });

    test('Roundtrip erhält alle Felder', () {
      const marker = ZustandsMarker(
        id: 'm2',
        name: 'Betäubung',
        rest: 3,
        notiz: 'Giftpfeil',
      );
      expect(ZustandsMarker.fromJson(marker.toJson()), marker);
    });

    test('copyWith kann die Dauer entfernen und lässt die ID unberührt', () {
      const marker = ZustandsMarker(id: 'm1', name: 'Furcht', rest: 2);
      expect(marker.copyWith(name: 'Angst').rest, 2);
      expect(marker.copyWith(rest: null).rest, isNull);
      expect(marker.copyWith(rest: null).hatDauer, isFalse);
      expect(marker.copyWith(name: 'Angst').id, 'm1');
    });

    test('abgelaufen heißt Dauer 0, ohne Dauer nie', () {
      expect(
        const ZustandsMarker(id: 'a', name: 'x', rest: 0).istAbgelaufen,
        isTrue,
      );
      expect(
        const ZustandsMarker(id: 'a', name: 'x', rest: 1).istAbgelaufen,
        isFalse,
      );
      expect(const ZustandsMarker(id: 'a', name: 'x').istAbgelaufen, isFalse);
    });

    test('eine negative Dauer wird als abgelaufen gelesen', () {
      final marker = ZustandsMarker.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'x',
        'rest': -4,
      });
      expect(marker.rest, 0);
    });

    test('unbekannte Felder bleiben erhalten', () {
      final marker = ZustandsMarker.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'x',
        'zukunft': <String, dynamic>{'stufe': 2},
      });
      expect(marker.unbekannteFelder.keys, ['zukunft']);
      expect(marker.copyWith(rest: 1).toJson()['zukunft'], {'stufe': 2});
    });

    test('Einträge ohne oder mit doppelter ID bekommen feste Ersatz-IDs', () {
      final liste = ZustandsMarker.listeAusJson(<dynamic>[
        <String, dynamic>{'id': 'a', 'name': 'eins'},
        <String, dynamic>{'id': 'a', 'name': 'zwei'},
        <String, dynamic>{'name': 'drei'},
        'kein Objekt',
      ]);
      expect(liste.map((m) => m.name), ['eins', 'zwei', 'drei']);
      expect(liste.map((m) => m.id).toSet(), hasLength(3));
      expect(liste.every((m) => m.id.isNotEmpty), isTrue);
      expect(liste.first.id, 'a');
      // Dieselbe Eingabe ergibt dieselben IDs (stabil über Neuladen).
      final nochmal = ZustandsMarker.listeAusJson(<dynamic>[
        <String, dynamic>{'id': 'a', 'name': 'eins'},
        <String, dynamic>{'id': 'a', 'name': 'zwei'},
        <String, dynamic>{'name': 'drei'},
      ]);
      expect(nochmal.map((m) => m.id), liste.map((m) => m.id));
    });
  });

  group('HeroState.zustandsmarker', () {
    test('ohne Marker fehlt der Schlüssel und der Hash bleibt', () {
      expect(_leer.zustandsmarker, isEmpty);
      expect(_leer.toJson().containsKey('zustandsmarker'), isFalse);
      expect(
        heroStateContentHash(_leer.copyWith(zustandsmarker: const [])),
        heroStateContentHash(_leer),
      );
    });

    test(
      'Roundtrip mit Markern ändert den Hash und erhält die Reihenfolge',
      () {
        final mit = _leer.copyWith(
          zustandsmarker: const <ZustandsMarker>[
            ZustandsMarker(id: 'b', name: 'Zweiter', rest: 2),
            ZustandsMarker(id: 'a', name: 'Erster'),
          ],
        );
        final geladen = HeroState.fromJson(mit.toJson());
        expect(geladen.zustandsmarker.map((m) => m.id), ['b', 'a']);
        expect(geladen.zustandsmarker, mit.zustandsmarker);
        expect(heroStateContentHash(mit), isNot(heroStateContentHash(_leer)));
      },
    );

    test('ein leere Liste entfernt den Schlüssel wieder', () {
      final entfernt = _leer
          .copyWith(
            zustandsmarker: const [ZustandsMarker(id: 'a', name: 'x')],
          )
          .copyWith(zustandsmarker: const []);
      expect(entfernt.toJson().containsKey('zustandsmarker'), isFalse);
    });

    test('der Schlüssel ist bekannt und landet nicht in unbekannteFelder', () {
      expect(HeroState.jsonSchluessel, contains('zustandsmarker'));
      final geladen = HeroState.fromJson(<String, dynamic>{
        ..._leer.toJson(),
        'zustandsmarker': <Object?>[
          <String, dynamic>{'id': 'a', 'name': 'x'},
        ],
        'zukunft': 1,
      });
      expect(geladen.unbekannteFelder.keys, ['zukunft']);
      expect(geladen.zustandsmarker, hasLength(1));
    });

    test('andere Zustandsänderungen lassen die Marker unberührt', () {
      final mit = _leer.copyWith(
        zustandsmarker: const [ZustandsMarker(id: 'a', name: 'x', rest: 1)],
      );
      expect(mit.copyWith(currentLep: 3).zustandsmarker, mit.zustandsmarker);
    });
  });

  group('Sync-Zusammenführung der Marker', () {
    Map<String, dynamic> stand(List<Map<String, dynamic>> marker) => {
      'currentLep': 30,
      if (marker.isNotEmpty) 'zustandsmarker': marker,
    };

    SyncZusammenfuehrung fuehre(
      List<Map<String, dynamic>> basis,
      List<Map<String, dynamic>> lokal,
      List<Map<String, dynamic>> online,
    ) => fuehreSyncZusammen(
      basis: stand(basis),
      lokal: stand(lokal),
      online: stand(online),
      regeln: zustandZusammenfuehrungsRegeln,
      entscheidungen: const <String, SyncSeite>{},
    );

    Map<String, dynamic> m(String id, String name, {int? rest}) => {
      'id': id,
      'name': name,
      'rest': ?rest,
    };

    test('neue Marker beider Geräte fließen ohne Konflikt zusammen', () {
      final ergebnis = fuehre(
        [],
        [m('a', 'Furcht', rest: 3)],
        [m('b', 'Schmerz')],
      );
      expect(ergebnis.vollstaendig, isTrue);
      final marker = ergebnis.ergebnis['zustandsmarker'] as List;
      expect(marker.map((e) => (e as Map)['id']).toSet(), {'a', 'b'});
    });

    test('Herunterzählen auf beiden Geräten zählt beide Schritte', () {
      final ergebnis = fuehre(
        [m('a', 'Furcht', rest: 5)],
        [m('a', 'Furcht', rest: 4)],
        [m('a', 'Furcht', rest: 3)],
      );
      expect(ergebnis.vollstaendig, isTrue);
      final marker =
          (ergebnis.ergebnis['zustandsmarker'] as List).single as Map;
      expect(marker['rest'], 2);
    });

    test('Zählen auf einem und Umbenennen auf dem anderen Gerät', () {
      final ergebnis = fuehre(
        [m('a', 'Furcht', rest: 5)],
        [m('a', 'Furcht', rest: 4)],
        [m('a', 'Angst', rest: 5)],
      );
      expect(ergebnis.vollstaendig, isTrue);
      final marker =
          (ergebnis.ergebnis['zustandsmarker'] as List).single as Map;
      expect(marker['name'], 'Angst');
      expect(marker['rest'], 4);
    });

    test('Entfernen gegen Ändern desselben Markers ist ein Konflikt', () {
      final ergebnis = fuehre(
        [m('a', 'Furcht', rest: 5)],
        [],
        [m('a', 'Furcht', rest: 4)],
      );
      expect(ergebnis.vollstaendig, isFalse);
    });
  });
}
