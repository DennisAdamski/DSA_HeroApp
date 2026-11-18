import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_marker.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zustandsmarker_rules.dart';

HeroState _zustand([List<ZustandsMarker> marker = const []]) => HeroState(
  currentLep: 20,
  currentAsp: 10,
  currentKap: 0,
  currentAu: 15,
  erschoepfung: 2,
  standort: 'Gareth',
  zustandsmarker: marker,
);

const _furcht = ZustandsMarker(id: 'a', name: 'Furcht', rest: 3);
const _schmerz = ZustandsMarker(id: 'b', name: 'Schmerz');
const _betaeubt = ZustandsMarker(id: 'c', name: 'Betäubung', rest: 0);

// Nur die Markerliste darf sich ändern.
void _nurMarkerGeaendert(HeroState vorher, HeroState nachher) {
  expect(
    nachher.copyWith(zustandsmarker: vorher.zustandsmarker).toJson(),
    vorher.toJson(),
  );
}

void main() {
  group('mitMarkerHinzu', () {
    test('hängt einen Marker mit Dauer und Notiz an', () {
      final neu = mitMarkerHinzu(
        _zustand([_schmerz]),
        id: 'x',
        name: '  Lähmung ',
        dauer: 4,
        notiz: ' Spinnengift ',
      );
      expect(neu.zustandsmarker.map((m) => m.id), ['b', 'x']);
      final marker = neu.zustandsmarker.last;
      expect(marker.name, 'Lähmung');
      expect(marker.rest, 4);
      expect(marker.notiz, 'Spinnengift');
      _nurMarkerGeaendert(_zustand([_schmerz]), neu);
    });

    test('ein leerer Name oder eine leere ID ändert nichts', () {
      final z = _zustand();
      expect(identical(mitMarkerHinzu(z, id: 'x', name: '   '), z), isTrue);
      expect(identical(mitMarkerHinzu(z, id: '', name: 'Furcht'), z), isTrue);
    });

    test('eine vorhandene ID wird nicht doppelt angelegt', () {
      final z = _zustand([_furcht]);
      expect(identical(mitMarkerHinzu(z, id: 'a', name: 'Neu'), z), isTrue);
    });

    test('Dauer und Name werden begrenzt', () {
      final neu = mitMarkerHinzu(
        _zustand(),
        id: 'x',
        name: 'N' * (kZustandsmarkerNameMax + 10),
        dauer: 100000,
      );
      expect(neu.zustandsmarker.single.name.length, kZustandsmarkerNameMax);
      expect(neu.zustandsmarker.single.rest, kZustandsmarkerDauerMax);
      expect(
        mitMarkerHinzu(
          _zustand(),
          id: 'x',
          name: 'Furcht',
          dauer: -3,
        ).zustandsmarker.single.rest,
        0,
      );
    });

    test(
      'eine volle Liste endet mit einem Fehler statt still zu verwerfen',
      () {
        final voll = _zustand([
          for (var i = 0; i < kZustandsmarkerMax; i++)
            ZustandsMarker(id: 'm$i', name: 'Marker $i'),
        ]);
        expect(
          () => mitMarkerHinzu(voll, id: 'neu', name: 'Noch einer'),
          throwsStateError,
        );
      },
    );
  });

  group('mitMarkerGeaendert', () {
    test('ändert Name, Dauer und Notiz nur dieses Markers', () {
      final z = _zustand([_furcht, _schmerz]);
      final neu = mitMarkerGeaendert(
        z,
        id: 'a',
        name: 'Angst',
        dauer: 7,
        notiz: 'Geist',
      );
      expect(neu.zustandsmarker.first.name, 'Angst');
      expect(neu.zustandsmarker.first.rest, 7);
      expect(neu.zustandsmarker.first.notiz, 'Geist');
      expect(neu.zustandsmarker.last, _schmerz);
      _nurMarkerGeaendert(z, neu);
    });

    test('ohne Dauer entfernt die Dauer', () {
      final neu = mitMarkerGeaendert(
        _zustand([_furcht]),
        id: 'a',
        name: 'Furcht',
      );
      expect(neu.zustandsmarker.single.rest, isNull);
    });

    test(
      'ohne Änderung, ohne Marker oder mit leerem Namen bleibt der Zustand',
      () {
        final z = _zustand([_furcht]);
        expect(
          identical(
            mitMarkerGeaendert(z, id: 'a', name: 'Furcht', dauer: 3),
            z,
          ),
          isTrue,
        );
        expect(
          identical(mitMarkerGeaendert(z, id: 'weg', name: 'Neu'), z),
          isTrue,
        );
        expect(identical(mitMarkerGeaendert(z, id: 'a', name: ' '), z), isTrue);
      },
    );
  });

  group('ohneMarker', () {
    test('entfernt nur den Marker mit der ID', () {
      final z = _zustand([_furcht, _schmerz]);
      final neu = ohneMarker(z, 'a');
      expect(neu.zustandsmarker, [_schmerz]);
      _nurMarkerGeaendert(z, neu);
    });

    test('ein fehlender Marker ändert nichts', () {
      final z = _zustand([_furcht]);
      expect(identical(ohneMarker(z, 'weg'), z), isTrue);
    });

    test('der letzte Marker lässt den Schlüssel aus dem JSON verschwinden', () {
      final neu = ohneMarker(_zustand([_furcht]), 'a');
      expect(neu.toJson().containsKey('zustandsmarker'), isFalse);
    });
  });

  group('mitMarkerSchritt', () {
    test('zählt vom gespeicherten Wert, nicht von einer Anzeige', () {
      final z = _zustand([_furcht]);
      final eins = mitMarkerSchritt(z, 'a', -1);
      final zwei = mitMarkerSchritt(eins, 'a', -1);
      expect(zwei.zustandsmarker.single.rest, 1);
      expect(mitMarkerSchritt(zwei, 'a', 1).zustandsmarker.single.rest, 2);
      _nurMarkerGeaendert(z, zwei);
    });

    test('bleibt zwischen 0 und der Höchstdauer', () {
      final unten = _zustand([_betaeubt]);
      expect(identical(mitMarkerSchritt(unten, 'c', -1), unten), isTrue);
      final oben = _zustand([
        const ZustandsMarker(
          id: 'o',
          name: 'Lang',
          rest: kZustandsmarkerDauerMax,
        ),
      ]);
      expect(identical(mitMarkerSchritt(oben, 'o', 1), oben), isTrue);
    });

    test('Marker ohne Dauer und fehlende Marker bleiben unverändert', () {
      final z = _zustand([_schmerz]);
      expect(identical(mitMarkerSchritt(z, 'b', -1), z), isTrue);
      expect(identical(mitMarkerSchritt(z, 'b', 1), z), isTrue);
      expect(identical(mitMarkerSchritt(z, 'weg', 1), z), isTrue);
    });

    test('Plus holt einen abgelaufenen Marker zurück', () {
      final neu = mitMarkerSchritt(_zustand([_betaeubt]), 'c', 1);
      expect(neu.zustandsmarker.single.rest, 1);
      expect(neu.zustandsmarker.single.istAbgelaufen, isFalse);
    });
  });

  group('mitNaechsterMarkerRunde', () {
    test('zählt alle laufenden Marker um eins herunter', () {
      final z = _zustand([
        _furcht,
        _schmerz,
        const ZustandsMarker(id: 'd', name: 'Kurz', rest: 1),
      ]);
      final neu = mitNaechsterMarkerRunde(z);
      expect(neu.zustandsmarker.map((m) => m.rest), [2, null, 0]);
      _nurMarkerGeaendert(z, neu);
    });

    test('ein abgelaufener Marker bleibt stehen und wird nicht negativ', () {
      final z = _zustand([_betaeubt, _furcht]);
      final neu = mitNaechsterMarkerRunde(z);
      expect(neu.zustandsmarker.map((m) => m.rest), [0, 2]);
      expect(neu.zustandsmarker, hasLength(2));
    });

    test('ohne laufenden Marker bleibt dieselbe Instanz', () {
      final z = _zustand([_schmerz, _betaeubt]);
      expect(identical(mitNaechsterMarkerRunde(z), z), isTrue);
      final leer = _zustand();
      expect(identical(mitNaechsterMarkerRunde(leer), leer), isTrue);
    });

    test('zählt jeden Aufruf einzeln (zwei Klicks zählen zweimal)', () {
      final z = _zustand([_furcht]);
      expect(
        mitNaechsterMarkerRunde(mitNaechsterMarkerRunde(z))
            .zustandsmarker
            .single
            .rest,
        1,
      );
    });
  });

  group('Anzeige', () {
    test('Dauertext', () {
      expect(zustandsmarkerDauerText(_furcht), '3 Runden');
      expect(
        zustandsmarkerDauerText(
          const ZustandsMarker(id: 'x', name: 'x', rest: 1),
        ),
        '1 Runde',
      );
      expect(zustandsmarkerDauerText(_betaeubt), 'abgelaufen');
      expect(zustandsmarkerDauerText(_schmerz), isNull);
    });

    test('laufende Marker werden gezählt', () {
      expect(zaehleLaufendeMarker(_zustand([_furcht, _schmerz, _betaeubt])), 1);
    });
  });
}
