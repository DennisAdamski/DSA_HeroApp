import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_ordnung.dart';

final _alle = KartoSpielkachelArt.values.toSet();

List<String> _ids(List<KartoSpielkachel> kacheln) => [
  for (final kachel in kacheln) kachel.art.id,
];

void main() {
  group('loeseSpielansichtAuf', () {
    test('ohne Anordnung gilt die Standardanordnung', () {
      final kacheln = loeseSpielansichtAuf(null, verfuegbar: _alle);
      expect(_ids(kacheln), [
        for (final art in KartoSpielkachelArt.values) art.id,
      ]);
      expect(kacheln.every((k) => k.breite == k.art.standard), isTrue);
    });

    test('Standardbreiten: Ressourcen als Band, Nachschlagekacheln schmal', () {
      for (final art in KartoSpielkachelArt.values) {
        expect(art.breiten, contains(art.standard), reason: art.id);
      }
      expect(KartoSpielkachelArt.ressourcen.standard, SpielkachelBreite.voll);
      expect(KartoSpielkachelArt.merkmale.standard, SpielkachelBreite.schmal);
      expect(KartoSpielkachelArt.protokoll.standard, SpielkachelBreite.schmal);
    });

    test('gespeicherte Reihenfolge, fehlende Kacheln an ihrer Stelle', () {
      final kacheln = loeseSpielansichtAuf(
        const HeroSpielansicht(
          kacheln: [
            HeroSpielkachel(id: 'protokoll'),
            HeroSpielkachel(id: 'ressourcen'),
          ],
        ),
        verfuegbar: _alle,
      );
      final ids = _ids(kacheln);
      expect(ids.first, 'protokoll');
      expect(ids[1], 'ressourcen');
      expect(ids[2], 'proben');
      expect(ids, hasLength(KartoSpielkachelArt.values.length));
    });

    test('der frühere Eintrag der Schnellaktionen wird übergangen', () {
      // Die Schnellaktionen stehen fest im Seitenkopf und sind keine Kachel.
      final kacheln = loeseSpielansichtAuf(
        const HeroSpielansicht(
          kacheln: [HeroSpielkachel(id: 'schnellaktionen')],
        ),
        verfuegbar: _alle,
      );
      expect(_ids(kacheln), isNot(contains('schnellaktionen')));
      expect(
        _ids(kacheln),
        _ids(loeseSpielansichtAuf(null, verfuegbar: _alle)),
      );
    });

    test('unbekannte und nicht verfügbare IDs werden übergangen', () {
      final kacheln = loeseSpielansichtAuf(
        const HeroSpielansicht(
          kacheln: [
            HeroSpielkachel(id: 'zukunft'),
            HeroSpielkachel(id: 'begleiter'),
          ],
        ),
        verfuegbar: _alle.difference({KartoSpielkachelArt.begleiter}),
      );
      expect(_ids(kacheln), isNot(contains('zukunft')));
      expect(_ids(kacheln), isNot(contains('begleiter')));
    });

    test('nicht Erlaubtes fällt auf den Standard zurück', () {
      final kacheln = loeseSpielansichtAuf(
        const HeroSpielansicht(
          kacheln: [
            // Kampf erlaubt keine volle Breite, Ressourcen weder Ausblenden
            // noch Einklappen.
            HeroSpielkachel(id: 'kampf', breite: SpielkachelBreite.voll),
            HeroSpielkachel(
              id: 'ressourcen',
              ausgeblendet: true,
              eingeklappt: true,
            ),
          ],
        ),
        verfuegbar: _alle,
      );
      KartoSpielkachel kachel(KartoSpielkachelArt art) =>
          kacheln.firstWhere((k) => k.art == art);
      expect(
        kachel(KartoSpielkachelArt.kampf).breite,
        SpielkachelBreite.schmal,
      );
      expect(kachel(KartoSpielkachelArt.ressourcen).ausgeblendet, isFalse);
      expect(kachel(KartoSpielkachelArt.ressourcen).eingeklappt, isFalse);
    });
  });

  group('schreibeSpielansicht', () {
    test('Standardbreite wird nicht geschrieben, Wünsche schon', () {
      final kacheln = aendereSpielkachel(
        loeseSpielansichtAuf(null, verfuegbar: _alle),
        KartoSpielkachelArt.dabei,
        (k) => k.copyWith(breite: SpielkachelBreite.mittel, ausgeblendet: true),
      );
      final ansicht = schreibeSpielansicht(kacheln, basis: null);
      expect(ansicht.kachel('kampf')!.breite, isNull);
      expect(ansicht.kachel('dabei')!.breite, SpielkachelBreite.mittel);
      expect(ansicht.kachel('dabei')!.ausgeblendet, isTrue);
    });

    test('unbekannte Einträge und Felder bleiben an ihrer Stelle', () {
      final basis = HeroSpielansicht.fromJson(<String, dynamic>{
        'kacheln': <Object?>[
          <String, Object?>{'id': 'schnellaktionen', 'farbe': 'rot'},
          <String, Object?>{'id': 'zukunft'},
          <String, Object?>{'id': 'begleiter', 'eingeklappt': true},
          <String, Object?>{'id': 'ressourcen'},
        ],
      });
      final verfuegbar = _alle.difference({KartoSpielkachelArt.begleiter});
      final kacheln = loeseSpielansichtAuf(basis, verfuegbar: verfuegbar);
      final ansicht = schreibeSpielansicht(kacheln, basis: basis);
      final ids = ansicht.kacheln.map((k) => k.id).toList();
      expect(ids.take(4), [
        'schnellaktionen', // früherer Eintrag, bleibt erhalten
        'zukunft',
        'begleiter',
        'ressourcen',
      ]);
      expect(ansicht.kachel('begleiter')!.eingeklappt, isTrue);
      expect(ansicht.kacheln.first.toJson()['farbe'], 'rot');
    });

    test('Rundreise über Auflösen und Schreiben ist stabil', () {
      final kacheln = verschiebeSpielkachel(
        loeseSpielansichtAuf(null, verfuegbar: _alle),
        3,
        0,
      );
      final ansicht = schreibeSpielansicht(kacheln, basis: null);
      expect(loeseSpielansichtAuf(ansicht, verfuegbar: _alle), kacheln);
    });
  });

  group('mitEingeklappt', () {
    test('ohne Anordnung entsteht nur der eine Eintrag', () {
      final ansicht = mitEingeklappt(
        null,
        KartoSpielkachelArt.kampf,
        eingeklappt: true,
      );
      expect(ansicht.kacheln.map((k) => k.id), ['kampf']);
      expect(ansicht.kacheln.single.eingeklappt, isTrue);
      // Die Reihenfolge der übrigen bleibt beim Auflösen der Standard.
      expect(
        _ids(loeseSpielansichtAuf(ansicht, verfuegbar: _alle)),
        _ids(loeseSpielansichtAuf(null, verfuegbar: _alle)),
      );
    });

    test('ändert nur den einen Eintrag', () {
      const basis = HeroSpielansicht(
        kacheln: [
          HeroSpielkachel(id: 'dabei', breite: SpielkachelBreite.mittel),
          HeroSpielkachel(id: 'kampf', eingeklappt: true),
        ],
      );
      final ansicht = mitEingeklappt(
        basis,
        KartoSpielkachelArt.kampf,
        eingeklappt: false,
      );
      expect(ansicht.kachel('kampf')!.eingeklappt, isFalse);
      expect(ansicht.kachel('dabei'), basis.kachel('dabei'));
    });
  });

  test('verschiebeSpielkachel setzt die Kachel an die Zielstelle', () {
    final start = loeseSpielansichtAuf(null, verfuegbar: _alle);
    final kampf = start.indexWhere((x) => x.art == KartoSpielkachelArt.kampf);
    final vor = verschiebeSpielkachel(start, kampf, 1);
    expect(vor[1].art, KartoSpielkachelArt.kampf);
    final zurueck = verschiebeSpielkachel(vor, 1, kampf);
    expect(zurueck, start);
  });

  group('fuegeSpielkachelEin', () {
    final start = loeseSpielansichtAuf(null, verfuegbar: _alle);
    const k = KartoSpielkachelArt.kampf;
    const z = KartoSpielkachelArt.zustand;
    const s0 = KartoSpielkachelArt.ressourcen;

    test('davor und danach richten sich nach der Zielkachel', () {
      final davor = fuegeSpielkachelEin(start, z, s0, davor: true);
      expect(_ids(davor).first, 'zustand');
      expect(_ids(davor)[1], 'ressourcen');
      final danach = fuegeSpielkachelEin(start, z, s0, davor: false);
      expect(_ids(danach).indexOf('zustand'), 1);
      expect(_ids(danach).first, 'ressourcen');
    });

    test('nach hinten gezogen steht die Kachel direkt vor oder hinter dem '
        'Ziel', () {
      final davor = fuegeSpielkachelEin(
        start,
        k,
        KartoSpielkachelArt.protokoll,
        davor: true,
      );
      final ids = _ids(davor);
      expect(ids.indexOf('kampf'), ids.indexOf('protokoll') - 1);
      final danach = fuegeSpielkachelEin(
        start,
        k,
        KartoSpielkachelArt.protokoll,
        davor: false,
      );
      expect(_ids(danach).last, 'kampf');
    });

    test('Kacheln bleiben vollständig, gleiche und fremde ändern nichts', () {
      final ergebnis = fuegeSpielkachelEin(start, k, z, davor: false);
      expect(_ids(ergebnis).toSet(), _ids(start).toSet());
      expect(ergebnis, hasLength(start.length));
      expect(fuegeSpielkachelEin(start, k, k, davor: true), start);
      final ohneZiel = start.where((x) => x.art != z).toList();
      expect(fuegeSpielkachelEin(ohneZiel, k, z, davor: true), ohneZiel);
    });

    test('behält Breite, Ausblenden und Einklappen der Kachel', () {
      final geaendert = aendereSpielkachel(
        start,
        k,
        (x) => x.copyWith(breite: SpielkachelBreite.mittel, eingeklappt: true),
      );
      final neu = fuegeSpielkachelEin(geaendert, k, s0, davor: true);
      final kampf = neu.firstWhere((x) => x.art == k);
      expect(kampf.breite, SpielkachelBreite.mittel);
      expect(kampf.eingeklappt, isTrue);
    });
  });
}
